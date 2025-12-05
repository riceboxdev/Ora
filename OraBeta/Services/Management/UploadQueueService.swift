//
//  UploadQueueService.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import Foundation
import UIKit
import Combine
import FirebaseAuth

enum UploadStatus: Equatable {
    case pending
    case uploading(progress: Double)
    case completed
    case failed(error: String)
}

struct UploadPayload: Identifiable, Equatable {
    let id: UUID
    // Store compressed image data instead of UIImage to reduce memory usage
    let imageData: Data
    let thumbnailData: Data
    let imageWidth: Int
    let imageHeight: Int
    let title: String?
    let description: String?
    let tags: [String]
    let categories: [String]
    let createdAt: Date
    
    // Computed property for display purposes (lazy-loaded)
    var image: UIImage? {
        UIImage(data: imageData)
    }
    
    var thumbnail: UIImage? {
        UIImage(data: thumbnailData)
    }
    
    init(
        id: UUID = UUID(),
        imageData: Data,
        thumbnailData: Data,
        imageWidth: Int,
        imageHeight: Int,
        title: String? = nil,
        description: String? = nil,
        tags: [String] = [],
        categories: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.title = title
        self.description = description
        self.tags = tags
        self.categories = categories
        self.createdAt = createdAt
    }
    
    static func == (lhs: UploadPayload, rhs: UploadPayload) -> Bool {
        lhs.id == rhs.id
    }
}

struct UploadQueueItem: Identifiable, Equatable {
    let id: UUID
    let payload: UploadPayload
    var status: UploadStatus
    var errorMessage: String?
    
    init(payload: UploadPayload, status: UploadStatus = .pending) {
        self.id = payload.id
        self.payload = payload
        self.status = status
        self.errorMessage = nil
    }
    
    static func == (lhs: UploadQueueItem, rhs: UploadQueueItem) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status
    }
}

// Background processing actor for upload operations
actor UploadProcessor {
    private let maxConcurrentUploads = 3
    private var activeUploads: Set<UUID> = []
    
    func canStartUpload() -> Bool {
        return activeUploads.count < maxConcurrentUploads
    }
    
    func startUpload(for id: UUID) {
        activeUploads.insert(id)
    }
    
    func finishUpload(for id: UUID) {
        activeUploads.remove(id)
    }
    
    func hasCapacity() -> Bool {
        return activeUploads.count < maxConcurrentUploads
    }
}

class UploadQueueService: ObservableObject {
    static let shared = UploadQueueService()
    
    @MainActor @Published var items: [UploadQueueItem] = []
    
    // Background processing
    private let processor = UploadProcessor()
    private let imageUploadService = ImageUploadService()
    private var processingTask: Task<Void, Never>?
    
    // Reusable service instances (must be on MainActor since services are @MainActor)
    @MainActor private var profileService: ProfileService?
    @MainActor private var postService: PostService?
    
    // Processing state
    @MainActor private var isProcessing = false
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var cancellables = Set<AnyCancellable>()
    
    // Persistence
    private let persistenceDirectory: URL = {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDir.appendingPathComponent("UploadQueue", isDirectory: true)
    }()
    
    // Performance: Debounce persist operations
    private var persistWorkItem: DispatchWorkItem?
    
    private init() {
        // Create persistence directory if needed
        try? FileManager.default.createDirectory(at: persistenceDirectory, withIntermediateDirectories: true)
        
        // Load persisted queue
        Task { @MainActor in
            await loadPersistedQueue()
        }
        
        // Processing will be triggered when items are enqueued
        setupBackgroundTaskHandling()
    }
    
    /// Setup background task handling for when app goes to background
    private func setupBackgroundTaskHandling() {
        // Use Combine's NotificationCenter publisher for app state changes
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleAppDidEnterBackground()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleAppWillEnterForeground()
                }
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    private func handleAppDidEnterBackground() async {
        // Request background time if there are pending uploads
        let hasPending = items.contains { item in
            if case .pending = item.status { return true }
            if case .uploading = item.status { return true }
            return false
        }
        
        if hasPending {
            requestBackgroundTime()
        }
    }
    
    @MainActor
    private func handleAppWillEnterForeground() async {
        // End background task if it's running
        endBackgroundTask()
        // Retrigger processing if there are pending items
        if !items.isEmpty {
            triggerProcessing()
        }
    }
    
    /// Request background execution time for uploads
    private func requestBackgroundTime() {
        guard backgroundTaskID == .invalid else { return }
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            // Background time expired, end the task
            self?.endBackgroundTask()
        }
        
        Logger.info("Started background task (\(backgroundTaskID.rawValue))", service: "UploadQueueService")
    }
    
    /// End background task
    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        
        let taskID = backgroundTaskID
        backgroundTaskID = .invalid
        UIApplication.shared.endBackgroundTask(taskID)
        Logger.info("Ended background task (\(taskID.rawValue))", service: "UploadQueueService")
    }
    
    @MainActor
    func initializeServices() {
        // Create reusable service instances
        self.profileService = ProfileService()
        if let profileService = self.profileService {
            self.postService = PostService(profileService: profileService)
        }
    }
    
    @MainActor
    func enqueue(_ payloads: [UploadPayload]) {
        let newItems = payloads.map { UploadQueueItem(payload: $0) }
        items.append(contentsOf: newItems)
        
        Logger.info("Enqueued \(newItems.count) item(s)", service: "UploadQueueService")
        Logger.debug("Total items in queue: \(items.count)", service: "UploadQueueService")
        Logger.debug("Pending items: \(items.filter { if case .pending = $0.status { return true }; return false }.count)", service: "UploadQueueService")
        
        // Persist new items to disk (debounced to reduce I/O)
        debouncedPersist()
        
        // Trigger processing if not already running
        triggerProcessing()
    }
    
    /// Debounced persist to reduce disk I/O (waits 2 seconds after last change)
    @MainActor
    private func debouncedPersist() {
        persistWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                await self?.persistQueue()
            }
        }
        
        persistWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
    }
    
    @MainActor
    func remove(_ item: UploadQueueItem) {
        // Cancel active upload if in progress
        if case .uploading = item.status {
            Logger.info("Cancelling active upload for item \(item.id)", service: "UploadQueueService")
            imageUploadService.cancelUpload(uploadId: item.id)
        }
        
        items.removeAll { $0.id == item.id }
        
        // Remove from disk (immediate for removes)
        Task.detached(priority: .background) { [weak self, id = item.id] in
            self?.removePersistedItem(id)
        }
    }
    
    @MainActor
    func retry(_ item: UploadQueueItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].status = .pending
        items[index].errorMessage = nil
        triggerProcessing()
    }
    
    @MainActor
    private func triggerProcessing() {
        // Trigger processing if not already running
        guard !isProcessing else {
            Logger.debug("Processing already running, skipping trigger", service: "UploadQueueService")
            return
        }
        isProcessing = true
        Logger.info("Triggering processing (pending items: \(items.filter { if case .pending = $0.status { return true }; return false }.count))", service: "UploadQueueService")
        
        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.processQueueLoop()
        }
    }
    
    // Background processing loop - not on MainActor
    private func processQueueLoop() async {
        Logger.info("Processing loop started", service: "UploadQueueService")
        var consecutiveEmptyChecks = 0
        let maxEmptyChecks = 10 // Exit after 10 empty checks (2 seconds)
        
        while consecutiveEmptyChecks < maxEmptyChecks {
            var startedCount = 0
            let maxConcurrent = 3
            
            // Start up to maxConcurrentUploads items
            var canStart = await processor.canStartUpload()
            let pendingCount = await MainActor.run {
                items.filter { if case .pending = $0.status { return true }; return false }.count
            }
            
            if pendingCount > 0 {
                Logger.debug("Found \(pendingCount) pending items, canStart: \(canStart)", service: "UploadQueueService")
            }
            
            while canStart && startedCount < maxConcurrent {
                let item = await MainActor.run {
                    getNextPendingItemAndMarkProcessing()
                }
                
                guard let item = item else {
                    break
                }
                
                // Reset empty checks counter when we find an item
                consecutiveEmptyChecks = 0
                
                Logger.info("Starting upload for item \(item.id)", service: "UploadQueueService")
                
                // Process this item concurrently
                Task.detached(priority: .userInitiated) { [weak self] in
                    await self?.processItem(item)
                }
                
                startedCount += 1
                
                // Check if we can start another (update canStart for next iteration)
                canStart = await processor.canStartUpload()
            }
            
            // If we didn't start any items, increment empty checks counter
            if startedCount == 0 {
                consecutiveEmptyChecks += 1
            }
            
            // Wait a bit before checking again
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        }
        
        Logger.info("Processing loop ended (empty checks: \(consecutiveEmptyChecks))", service: "UploadQueueService")
        await MainActor.run {
            self.isProcessing = false
        }
    }
    
    private func hasPendingItems() async -> Bool {
        return await MainActor.run {
            items.contains { if case .pending = $0.status { return true }; return false }
        }
    }
    
    private func processItem(_ item: UploadQueueItem) async {
        let itemId = item.id
        Logger.info("Processing item \(itemId)", service: "UploadQueueService")
        await processor.startUpload(for: itemId)
        
        // Update status to uploading
        await updateItemStatus(itemId, status: .uploading(progress: 0.0))
        
        guard let userId = Auth.auth().currentUser?.uid else {
            Logger.error("User not authenticated for item \(itemId)", service: "UploadQueueService")
            await updateItemStatus(itemId, status: .failed(error: "User not authenticated"), errorMessage: "User not authenticated")
            await processor.finishUpload(for: itemId)
            // Retrigger processing if there are more items
            await triggerProcessingIfNeeded()
            return
        }
        
        Logger.debug("User authenticated (\(userId)) for item \(itemId)", service: "UploadQueueService")
        
        do {
            // Upload images in parallel (full image and thumbnail) with real-time progress tracking
            await updateItemStatus(itemId, status: .uploading(progress: 0.0))
            
            Logger.info("Starting image upload for item \(itemId)", service: "UploadQueueService")
            Logger.debug("Image data size: \(String(format: "%.2f", Double(item.payload.imageData.count) / (1024 * 1024))) MB", service: "UploadQueueService")
            Logger.debug("Thumbnail data size: \(String(format: "%.2f", Double(item.payload.thumbnailData.count) / (1024 * 1024))) MB", service: "UploadQueueService")
            
            let (imageUrl, thumbnailUrl) = try await imageUploadService.uploadImageData(
                uploadId: itemId,
                imageData: item.payload.imageData,
                thumbnailData: item.payload.thumbnailData,
                userId: userId,
                progressCallback: { [weak self] progress in
                    // Update progress in real-time (upload phase is 0-70% of total)
                    Task { @MainActor in
                        await self?.updateItemStatus(itemId, status: .uploading(progress: progress * 0.7))
                    }
                }
            )
            
            Logger.info("Image upload completed for item \(itemId)", service: "UploadQueueService")
            Logger.debug("Image URL: \(imageUrl)", service: "UploadQueueService")
            Logger.debug("Thumbnail URL: \(thumbnailUrl)", service: "UploadQueueService")
            
            // Create post (must be on MainActor for PostService)
            // Post creation is 70-100% of total progress
            await updateItemStatus(itemId, status: .uploading(progress: 0.7))
            
            Logger.info("Creating post for item \(itemId)", service: "UploadQueueService")
            
            let profileService = await MainActor.run {
                if let service = self.profileService {
                    return service
                } else {
                    return ProfileService()
                }
            }
            
            let postService = await MainActor.run {
                if let service = self.postService {
                    return service
                } else {
                    return PostService(profileService: profileService)
                }
            }
            
            // Convert tags to interests for the post creation
            // Note: UploadPayload still uses tags/categories internally for backward compatibility
            // but we send them as interests to PostService
            let allInterests = Set(item.payload.tags + item.payload.categories)
            
            _ = try await postService.createPost(
                userId: userId,
                imageUrl: imageUrl,
                thumbnailUrl: thumbnailUrl,
                imageWidth: item.payload.imageWidth,
                imageHeight: item.payload.imageHeight,
                caption: item.payload.description ?? item.payload.title,
                interestIds: Array(allInterests)
            )
            
            Logger.info("Post created successfully for item \(itemId)", service: "UploadQueueService")
            await updateItemStatus(itemId, status: .completed)
            
            // Remove completed item after a delay
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                await MainActor.run {
                    if let index = items.firstIndex(where: { $0.id == itemId }),
                       case .completed = items[index].status {
                        items.remove(at: index)
                    }
                }
                
                // Remove from disk (background thread)
                Task.detached(priority: .background) { [weak self] in
                    self?.removePersistedItem(itemId)
                }
            }
        } catch {
            let errorMessage = error.localizedDescription
            Logger.error("Upload failed for item \(itemId)", service: "UploadQueueService")
            Logger.error("Error: \(errorMessage)", service: "UploadQueueService")
            Logger.debug("Error type: \(type(of: error))", service: "UploadQueueService")
            if let nsError = error as NSError? {
                Logger.debug("Error domain: \(nsError.domain)", service: "UploadQueueService")
                Logger.debug("Error code: \(nsError.code)", service: "UploadQueueService")
                Logger.debug("Error userInfo: \(nsError.userInfo)", service: "UploadQueueService")
            }
            await updateItemStatus(itemId, status: .failed(error: errorMessage), errorMessage: errorMessage)
        }
        
        await processor.finishUpload(for: itemId)
        
        // Check if we should end background task (no more pending/uploading items)
        await checkAndEndBackgroundTask()
        
        // Retrigger processing if there are more items
        await triggerProcessingIfNeeded()
    }
    
    private func checkAndEndBackgroundTask() async {
        let hasActiveItems = await MainActor.run {
            items.contains { item in
                if case .pending = item.status { return true }
                if case .uploading = item.status { return true }
                return false
            }
        }
        
        if !hasActiveItems {
            await MainActor.run {
                endBackgroundTask()
            }
        }
    }
    
    private func triggerProcessingIfNeeded() async {
        let hasPending = await hasPendingItems()
        let canStart = await processor.canStartUpload()
        
        if hasPending && canStart {
            await MainActor.run {
                triggerProcessing()
            }
        }
    }
    
    @MainActor
    private func getNextPendingItemAndMarkProcessing() -> UploadQueueItem? {
        guard let index = items.firstIndex(where: {
            if case .pending = $0.status {
                return true
            }
            return false
        }) else {
            return nil
        }
        
        // Return the item (we'll mark it as uploading in processItem)
        return items[index]
    }
    
    @MainActor
    private func updateItemStatus(_ id: UUID, status: UploadStatus, errorMessage: String? = nil) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        
        // Performance: Only update if status actually changed (reduces UI updates)
        let oldStatus = items[index].status
        if !statusesAreEqual(oldStatus, status) {
            items[index].status = status
        }
        
        if let errorMessage = errorMessage {
            items[index].errorMessage = errorMessage
        }
    }
    
    /// Helper to compare upload statuses (for reducing UI updates)
    private func statusesAreEqual(_ lhs: UploadStatus, _ rhs: UploadStatus) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending), (.completed, .completed):
            return true
        case (.uploading(let p1), .uploading(let p2)):
            // Only update if progress changed by more than 5%
            return abs(p1 - p2) < 0.05
        case (.failed(let e1), .failed(let e2)):
            return e1 == e2
        default:
            return false
        }
    }
    
    @MainActor
    func cancelAll() {
        Logger.info("Cancelling all uploads", service: "UploadQueueService")
        
        // Cancel processing task
        processingTask?.cancel()
        
        // Cancel all active network uploads in Cloudinary
        imageUploadService.cancelAllUploads()
        
        // Clear queue items
        items.removeAll()
        isProcessing = false
        
        // Clear persisted queue
        Task {
            await clearPersistedQueue()
        }
    }
    
    // MARK: - Persistence
    
    /// Save queue to disk (only pending and failed items)
    private func persistQueue() async {
        await MainActor.run {
            // Only persist pending and failed items (not completed or currently uploading)
            let itemsToPersist = items.filter { item in
                if case .pending = item.status { return true }
                if case .failed = item.status { return true }
                return false
            }
            
            // Save each item to disk
            for item in itemsToPersist {
                saveItemToDisk(item)
            }
            
            Logger.debug("Persisted \(itemsToPersist.count) items to disk", service: "UploadQueueService")
        }
    }
    
    /// Load persisted queue from disk on app launch
    @MainActor
    private func loadPersistedQueue() async {
        do {
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: persistenceDirectory.path) else {
                Logger.debug("No persisted queue found", service: "UploadQueueService")
                return
            }
            
            let contents = try fileManager.contentsOfDirectory(at: persistenceDirectory, includingPropertiesForKeys: nil)
            var loadedItems: [UploadQueueItem] = []
            
            for itemURL in contents where itemURL.hasDirectoryPath {
                if let item = loadItemFromDisk(at: itemURL) {
                    loadedItems.append(item)
                }
            }
            
            // Sort by creation date
            loadedItems.sort { $0.payload.createdAt < $1.payload.createdAt }
            
            items = loadedItems
            Logger.info("Loaded \(loadedItems.count) persisted items from disk", service: "UploadQueueService")
            
            // Trigger processing if there are items
            if !items.isEmpty {
                triggerProcessing()
            }
        } catch {
            Logger.error("Failed to load persisted queue: \(error)", service: "UploadQueueService")
        }
    }
    
    /// Save a single item to disk
    private func saveItemToDisk(_ item: UploadQueueItem) {
        let itemDir = persistenceDirectory.appendingPathComponent(item.id.uuidString, isDirectory: true)
        
        do {
            // Create directory for this item
            try FileManager.default.createDirectory(at: itemDir, withIntermediateDirectories: true)
            
            // Save metadata
            let metadata: [String: Any] = [
                "id": item.payload.id.uuidString,
                "imageWidth": item.payload.imageWidth,
                "imageHeight": item.payload.imageHeight,
                "title": item.payload.title as Any,
                "description": item.payload.description as Any,
                "tags": item.payload.tags,
                "categories": item.payload.categories,
                "createdAt": item.payload.createdAt.timeIntervalSince1970,
                "status": statusToString(item.status),
                "errorMessage": item.errorMessage as Any
            ]
            
            let metadataJSON = try JSONSerialization.data(withJSONObject: metadata)
            try metadataJSON.write(to: itemDir.appendingPathComponent("metadata.json"))
            
            // Save image data
            try item.payload.imageData.write(to: itemDir.appendingPathComponent("image.dat"))
            try item.payload.thumbnailData.write(to: itemDir.appendingPathComponent("thumb.dat"))
        } catch {
            Logger.error("Failed to save item \(item.id): \(error)", service: "UploadQueueService")
        }
    }
    
    /// Load a single item from disk
    private func loadItemFromDisk(at itemDir: URL) -> UploadQueueItem? {
        do {
            // Load metadata
            let metadataJSON = try Data(contentsOf: itemDir.appendingPathComponent("metadata.json"))
            guard let metadata = try JSONSerialization.jsonObject(with: metadataJSON) as? [String: Any],
                  let idString = metadata["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let imageWidth = metadata["imageWidth"] as? Int,
                  let imageHeight = metadata["imageHeight"] as? Int,
                  let tags = metadata["tags"] as? [String],
                  let categories = metadata["categories"] as? [String],
                  let createdAtTimestamp = metadata["createdAt"] as? TimeInterval,
                  let statusString = metadata["status"] as? String else {
                Logger.error("Failed to parse metadata for item", service: "UploadQueueService")
                return nil
            }
            
            // Load image data
            let imageData = try Data(contentsOf: itemDir.appendingPathComponent("image.dat"))
            let thumbnailData = try Data(contentsOf: itemDir.appendingPathComponent("thumb.dat"))
            
            let payload = UploadPayload(
                id: id,
                imageData: imageData,
                thumbnailData: thumbnailData,
                imageWidth: imageWidth,
                imageHeight: imageHeight,
                title: metadata["title"] as? String,
                description: metadata["description"] as? String,
                tags: tags,
                categories: categories,
                createdAt: Date(timeIntervalSince1970: createdAtTimestamp)
            )
            
            // Convert status back (always set to pending on reload to retry)
            let status: UploadStatus = .pending
            
            return UploadQueueItem(payload: payload, status: status)
        } catch {
            Logger.error("Failed to load item: \(error)", service: "UploadQueueService")
            return nil
        }
    }
    
    /// Remove persisted item from disk
    private func removePersistedItem(_ id: UUID) {
        let itemDir = persistenceDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: itemDir)
    }
    
    /// Clear all persisted items
    private func clearPersistedQueue() async {
        try? FileManager.default.removeItem(at: persistenceDirectory)
        try? FileManager.default.createDirectory(at: persistenceDirectory, withIntermediateDirectories: true)
    }
    
    /// Helper to convert status to string
    private func statusToString(_ status: UploadStatus) -> String {
        switch status {
        case .pending: return "pending"
        case .uploading: return "uploading"
        case .completed: return "completed"
        case .failed: return "failed"
        }
    }
}

