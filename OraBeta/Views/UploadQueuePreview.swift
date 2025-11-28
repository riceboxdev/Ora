//
//  UploadQueuePreview.swift
//  OraBeta
//
//  Preview file for designing and testing UploadQueueCard in different states
//

import SwiftUI
import Combine

struct UploadQueuePreview: View {
    @State private var selectedState: PreviewState = .empty
    
    enum PreviewState: String, CaseIterable {
        case empty = "Empty"
        case singlePending = "Single - Pending"
        case singleUploading = "Single - Uploading"
        case singleCompleted = "Single - Completed"
        case singleFailed = "Single - Failed"
        case multipleMixed = "Multiple - Mixed States"
        case multipleAllPending = "Multiple - All Pending"
        case multipleAllUploading = "Multiple - All Uploading"
        case multipleAllCompleted = "Multiple - All Completed"
        case multipleAllFailed = "Multiple - All Failed"
        case expanded = "Expanded View"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // State selector
                Picker("State", selection: $selectedState) {
                    ForEach(PreviewState.allCases, id: \.self) { state in
                        Text(state.rawValue).tag(state)
                    }
                }
                .pickerStyle(.menu)
                .padding()
                .background(Color(.systemGray6))
                
                // Preview content
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Upload Queue Preview")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.top)
                        
                        Text("State: \(selectedState.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.bottom)
                        
                        // Preview the card in selected state
                        previewCard
                            .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Upload Queue Design")
        }
    }
    
    @ViewBuilder
    private var previewCard: some View {
        switch selectedState {
        case .empty:
            EmptyStatePreview()
        case .singlePending:
            SingleItemPreview(state: .pending)
        case .singleUploading:
            SingleItemPreview(state: .uploading(progress: 0.45))
        case .singleCompleted:
            SingleItemPreview(state: .completed)
        case .singleFailed:
            SingleItemPreview(state: .failed(error: "Network error"))
        case .multipleMixed:
            MultipleItemsPreview(items: createMixedItems())
        case .multipleAllPending:
            MultipleItemsPreview(items: createItems(count: 3, status: .pending))
        case .multipleAllUploading:
            MultipleItemsPreview(items: createItems(count: 3, status: .uploading(progress: 0.6)))
        case .multipleAllCompleted:
            MultipleItemsPreview(items: createItems(count: 3, status: .completed))
        case .multipleAllFailed:
            MultipleItemsPreview(items: createItems(count: 3, status: .failed(error: "Upload failed")))
        case .expanded:
            ExpandedViewPreview(items: createMixedItems())
        }
    }
    
    // Helper functions to create test items
    private func createMixedItems() -> [UploadQueueItem] {
        [
            UploadQueueItem(
                payload: createTestPayload(title: "Sunset Beach", tags: ["nature", "beach"]),
                status: .completed
            ),
            UploadQueueItem(
                payload: createTestPayload(title: "Mountain View", tags: ["nature", "mountain"]),
                status: .uploading(progress: 0.75)
            ),
            UploadQueueItem(
                payload: createTestPayload(title: "City Lights", tags: ["urban", "night"]),
                status: .pending
            ),
            UploadQueueItem(
                payload: createTestPayload(title: "Failed Upload", tags: ["test"]),
                status: .failed(error: "Network connection lost")
            ),
            UploadQueueItem(
                payload: createTestPayload(title: "Forest Path", tags: ["nature", "forest"]),
                status: .uploading(progress: 0.25)
            )
        ]
    }
    
    private func createItems(count: Int, status: UploadStatus) -> [UploadQueueItem] {
        let titles = ["Image 1", "Image 2", "Image 3", "Image 4", "Image 5"]
        return (0..<count).map { index in
            UploadQueueItem(
                payload: createTestPayload(title: titles[index], tags: ["tag\(index)"]),
                status: status
            )
        }
    }
    
    private func createTestPayload(title: String, tags: [String]) -> UploadPayload {
        // Create a simple test image
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // Create a gradient background
            let colors = [UIColor.systemBlue, UIColor.systemPurple]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: colors.map { $0.cgColor } as CFArray,
                                    locations: nil)!
            context.cgContext.drawLinearGradient(gradient,
                                                start: CGPoint(x: 0, y: 0),
                                                end: CGPoint(x: size.width, y: size.height),
                                                options: [])
        }
        
        // Convert to data
        let imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
        let thumbnailData = image.jpegData(compressionQuality: 0.5) ?? Data()
        
        return UploadPayload(
            imageData: imageData,
            thumbnailData: thumbnailData,
            imageWidth: Int(size.width),
            imageHeight: Int(size.height),
            title: title,
            tags: tags,
            categories: []
        )
    }
}

// MARK: - Preview Components

struct EmptyStatePreview: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Empty State")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("When there are no items in the upload queue, the card is hidden.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SingleItemPreview: View {
    let state: UploadStatus
    @StateObject private var service = UploadQueueService.shared
    
    init(state: UploadStatus) {
        self.state = state
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Single Item State")
                .font(.headline)
                .foregroundColor(.secondary)
            
            // Create a single item with the specified state
            let payload = createTestPayload()
            let item = UploadQueueItem(payload: payload, status: state)
            
            UploadQueueCard(queueService: service)
                .onAppear {
                    service.setItemsForPreview([item])
                }
        }
    }
    
    private func createTestPayload() -> UploadPayload {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        
        let imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
        let thumbnailData = image.jpegData(compressionQuality: 0.5) ?? Data()
        
        return UploadPayload(
            imageData: imageData,
            thumbnailData: thumbnailData,
            imageWidth: Int(size.width),
            imageHeight: Int(size.height),
            title: "Test Image",
            tags: ["test"],
            categories: []
        )
    }
}

struct MultipleItemsPreview: View {
    let items: [UploadQueueItem]
    @StateObject private var service = UploadQueueService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Multiple Items (Collapsed)")
                .font(.headline)
                .foregroundColor(.secondary)
            
            UploadQueueCard(queueService: service)
                .onAppear {
                    service.setItemsForPreview(items)
                }
        }
    }
}

struct ExpandedViewPreview: View {
    let items: [UploadQueueItem]
    @StateObject private var service = UploadQueueService.shared
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Expanded View")
                .font(.headline)
                .foregroundColor(.secondary)
            
            UploadQueueCard(queueService: service)
                .onAppear {
                    service.setItemsForPreview(items)
                }
        }
    }
}

// MARK: - Preview Service Wrapper

// Since UploadQueueService has a private init, we'll use the shared instance
// and directly manipulate its items for preview purposes
extension UploadQueueService {
    // This extension allows us to set items directly for preview purposes
    // Note: This is only safe to use in previews, not in production code
    @MainActor
    func setItemsForPreview(_ newItems: [UploadQueueItem]) {
        self.items = newItems
    }
}

// MARK: - Preview Provider

#Preview("Upload Queue Preview") {
    UploadQueuePreview()
}

#Preview("Single Item - Pending") {
    SingleItemPreview(state: .pending)
        .padding()
}

#Preview("Single Item - Uploading") {
    SingleItemPreview(state: .uploading(progress: 0.65))
        .padding()
}

#Preview("Single Item - Completed") {
    SingleItemPreview(state: .completed)
        .padding()
}

#Preview("Single Item - Failed") {
    SingleItemPreview(state: .failed(error: "Network error occurred"))
        .padding()
}

#Preview("Multiple Items - Mixed") {
    ScrollView {
        MultipleItemsPreview(items: [
            UploadQueueItem(
                payload: createPreviewPayload(title: "Item 1"),
                status: .completed
            ),
            UploadQueueItem(
                payload: createPreviewPayload(title: "Item 2"),
                status: .uploading(progress: 0.5)
            ),
            UploadQueueItem(
                payload: createPreviewPayload(title: "Item 3"),
                status: .pending
            )
        ])
        .padding()
    }
}

// Helper function for previews
private func createPreviewPayload(title: String) -> UploadPayload {
    let size = CGSize(width: 200, height: 200)
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { context in
        UIColor.systemBlue.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
    
    let imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
    let thumbnailData = image.jpegData(compressionQuality: 0.5) ?? Data()
    
    return UploadPayload(
        imageData: imageData,
        thumbnailData: thumbnailData,
        imageWidth: Int(size.width),
        imageHeight: Int(size.height),
        title: title,
        tags: ["test"],
        categories: []
    )
}

