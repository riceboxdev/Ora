//
//  CachedImageView.swift
//  OraBeta
//
//  A SwiftUI view that uses Kingfisher for image caching but displays
//  images as SwiftUI Image() for seamless transitions
//

import SwiftUI
import Kingfisher

struct CachedImageView: View {
    let url: URL?
    let aspectRatio: CGFloat?
    let downsamplingSize: CGSize?
    let contentMode: SwiftUI.ContentMode
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var hasError = false
    
    init(
        url: URL?,
        aspectRatio: CGFloat? = nil,
        downsamplingSize: CGSize? = nil,
        contentMode: SwiftUI.ContentMode = .fit
    ) {
        self.url = url
        self.aspectRatio = aspectRatio
        self.downsamplingSize = downsamplingSize
        self.contentMode = contentMode
    }
    
    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(aspectRatio ?? 9/16, contentMode: .fit)
                    .transition(.opacity)
            } else if hasError {
                placeholder()
                    .overlay {
                        VStack(spacing: 15) {
                            Image(systemName: "minus.circle.fill")
                                .imageScale(.large)
                                .symbolRenderingMode(.hierarchical)
                            Text("There was an error")
                                .font(.creatoDisplayCaption(.medium))
                        }
                    }
                    .transition(.opacity)
            } else {
                placeholder()
                    .overlay {
                        if isLoading {
                            ProgressView()
                        }
                    }
                    .transition(.opacity)
            }
        }
        
        .task {
            await loadImage()
        }
        .onChange(of: url) { _, _ in
            Task {
                await loadImage()
            }
        }
    }
    
    @ViewBuilder
    private func placeholder() -> some View {
        Rectangle()
            .fill(.quaternary)
            .aspectRatio(aspectRatio, contentMode: .fill)
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadImage() async {
        guard let url = url else {
            await MainActor.run {
                hasError = true
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            hasError = false
        }
        
        // Configure caching options for optimal performance
        var options: KingfisherOptionsInfo = [
            .diskCacheExpiration(.days(7)),
            .memoryCacheExpiration(.seconds(300)),
            .transition(.fade(0.2))
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
            }
        } catch {
            await MainActor.run {
                self.hasError = true
                self.isLoading = false
            }
        }
    }
}

