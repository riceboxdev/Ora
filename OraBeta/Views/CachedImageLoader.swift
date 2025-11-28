//
//  CachedImageLoader.swift
//  OraBeta
//
//  A SwiftUI view that uses Kingfisher for image caching and provides
//  the loaded image through a closure for use in parent views
//

import SwiftUI
import Kingfisher

struct CachedImageLoader<Content: View>: View {
    let url: URL?
    let aspectRatio: CGFloat?
    let downsamplingSize: CGSize?
    let contentMode: SwiftUI.ContentMode
    let onImageLoaded: ((UIImage?) -> Void)?
    let content: (UIImage?, Bool, Bool) -> Content
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var hasError = false
    
    init(
        url: URL?,
        aspectRatio: CGFloat? = nil,
        downsamplingSize: CGSize? = nil,
        contentMode: SwiftUI.ContentMode = .fit,
        onImageLoaded: ((UIImage?) -> Void)? = nil,
        @ViewBuilder content: @escaping (UIImage?, Bool, Bool) -> Content
    ) {
        self.url = url
        self.aspectRatio = aspectRatio
        self.downsamplingSize = downsamplingSize
        self.contentMode = contentMode
        self.onImageLoaded = onImageLoaded
        self.content = content
    }
    
    var body: some View {
        content(loadedImage, isLoading, hasError)
            .task {
                await loadImage()
            }
            .onChange(of: url) { _, _ in
                Task {
                    await loadImage()
                }
            }
    }
    
    private func loadImage() async {
        guard let url = url else {
            await MainActor.run {
                hasError = true
                loadedImage = nil
                onImageLoaded?(nil)
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            hasError = false
        }
        
        // Configure caching options for optimal performance
        // By default, Kingfisher caches to both memory and disk
        var options: KingfisherOptionsInfo = [
            .diskCacheExpiration(.days(7)), // Keep on disk for 7 days
            .memoryCacheExpiration(.seconds(300)), // Keep in memory for 5 minutes
            .transition(.fade(0.2)) // Smooth fade transition
        ]
        
        // If downsampling is requested, use processor
        if let downsamplingSize = downsamplingSize {
            let processor = DownsamplingImageProcessor(size: downsamplingSize)
            options.append(.processor(processor))
        }
        
        // Use Kingfisher's retrieveImage which handles both cache and download
        let resource = KF.ImageResource(downloadURL: url)
        do {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<RetrieveImageResult, Error>) in
                KingfisherManager.shared.retrieveImage(with: resource, options: options) { result in
                    switch result {
                    case .success(let value):
                        continuation.resume(returning: value)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            await MainActor.run {
                self.loadedImage = result.image
                self.isLoading = false
                self.onImageLoaded?(result.image)
            }
        } catch {
            await MainActor.run {
                self.hasError = true
                self.isLoading = false
                self.loadedImage = nil
                self.onImageLoaded?(nil)
            }
        }
    }
}


