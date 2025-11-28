//
//  UploadQueueCard.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/1/25.
//

import SwiftUI

struct UploadQueueCard: View {
    @ObservedObject var queueService: UploadQueueService
    @State private var isExpanded = false
    @State private var showCancelConfirmation = false
    
    // Performance: Cache thumbnail images to avoid repeated decoding
    @State private var thumbnailCache: [UUID: UIImage] = [:]
    
    // Performance: Limit items shown in expanded view
    private let maxItemsToShow = 50
    
    var body: some View {
        if !queueService.items.isEmpty {
            VStack(spacing: 0) {
                // Header - always visible
                HStack(spacing: 0) {
                    Button(action: {
                        if queueService.items.count > 1 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isExpanded.toggle()
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Upload Queue")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(queueStatusText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if queueService.items.count > 1 {
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            
                            // Status indicator
                            statusIndicator
                        }
                        .padding()
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Cancel All button
                    Button(action: {
                        showCancelConfirmation = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                            .padding(.trailing, 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .background(Color(.systemBackground))
                
                // Expanded list - VIRTUALIZED with ScrollView + LazyVStack
                if isExpanded && queueService.items.count > 1 {
                    Divider()
                    
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Performance: Only show first N items
                            let itemsToShow = Array(queueService.items.prefix(maxItemsToShow))
                            
                            ForEach(itemsToShow) { item in
                                UploadQueueItemRow(
                                    item: item,
                                    queueService: queueService,
                                    thumbnailCache: $thumbnailCache
                                )
                                
                                if item.id != itemsToShow.last?.id {
                                    Divider()
                                        .padding(.leading, 60)
                                }
                            }
                            
                            // Show warning if there are more items
                            if queueService.items.count > maxItemsToShow {
                                Text("+ \(queueService.items.count - maxItemsToShow) more items...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                        }
                    }
                    .frame(maxHeight: 400) // Limit height
                    .background(Color(.systemBackground))
                }
            }
//            .background(Color(.systemBackground))
            .cornerRadius(16)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
            .padding(.top)
            .alert("Cancel All Uploads?", isPresented: $showCancelConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Yes, Cancel All", role: .destructive) {
                    queueService.cancelAll()
                    isExpanded = false
                }
            } message: {
                Text("This will stop all pending uploads. Uploads in progress will finish.")
            }
        }
    }
    
    private var queueStatusText: String {
        let activeCount = queueService.items.filter { item in
            if case .uploading = item.status {
                return true
            }
            if case .pending = item.status {
                return true
            }
            return false
        }.count
        
        let failedCount = queueService.items.filter { item in
            if case .failed = item.status {
                return true
            }
            return false
        }.count
        
        if activeCount > 0 {
            return "\(activeCount) uploading"
        } else if failedCount > 0 {
            return "\(failedCount) failed"
        } else {
            return "\(queueService.items.count) in queue"
        }
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        let hasActive = queueService.items.contains { item in
            if case .uploading = item.status { return true }
            if case .pending = item.status { return true }
            return false
        }
        
        let hasFailed = queueService.items.contains { item in
            if case .failed = item.status { return true }
            return false
        }
        
        if hasActive {
            ProgressView()
                .scaleEffect(0.8)
        } else if hasFailed {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.caption)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        }
    }
}

struct UploadQueueItemRow: View {
    let item: UploadQueueItem
    @ObservedObject var queueService: UploadQueueService
    @Binding var thumbnailCache: [UUID: UIImage]
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail - CACHED to avoid repeated decoding
            Group {
                if let cachedThumbnail = thumbnailCache[item.id] {
                    Image(uiImage: cachedThumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .cornerRadius(8)
                        .clipped()
                } else {
                    // Placeholder while loading or if no thumbnail
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .cornerRadius(8)
                        .onAppear {
                            // Decode thumbnail asynchronously and cache it
                            Task.detached(priority: .background) {
                                if let thumbnail = item.payload.thumbnail {
                                    await MainActor.run {
                                        thumbnailCache[item.id] = thumbnail
                                    }
                                }
                            }
                        }
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.payload.title ?? "Untitled")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                statusText
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status/Retry button
            statusView
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(itemBackgroundColor)
    }
    
    @ViewBuilder
    private var statusText: some View {
        switch item.status {
        case .pending:
            Text("Waiting...")
        case .uploading(let progress):
            Text("Uploading \(Int(progress * 100))%")
        case .completed:
            Text("Completed")
        case .failed(let error):
            Text(error)
                .lineLimit(2)
        }
    }
    
    @ViewBuilder
    private var statusView: some View {
        switch item.status {
        case .pending:
            ProgressView()
                .scaleEffect(0.8)
        case .uploading(let progress):
            ProgressView(value: progress)
                .frame(width: 60)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)
        case .failed:
            Button(action: {
                queueService.retry(item)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
    }
    
    private var itemBackgroundColor: Color {
        if case .failed = item.status {
            return Color.red.opacity(0.1)
        }
        return Color.clear
    }
}

#Preview {
    let service = UploadQueueService.shared
    let testImage = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { context in
        UIColor.blue.setFill()
        context.fill(CGRect(origin: .zero, size: CGSize(width: 100, height: 100)))
    }
    // Note: Preview is for UI testing only - actual usage compresses images before enqueueing
    // This preview may not work correctly with the new compressed data structure
    return ScrollView {
        UploadQueueCard(queueService: service)
    }
}

