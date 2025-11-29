import AdMobUI
import GoogleMobileAds
import SwiftUI


// MARK: - Usage Example
struct TestAdView: View {
    let transitionDuration: Double = 0.5
    let displayDuration: Double = 3.0

    @State private var currentIndex = 0
    @State private var opacity: Double = 1.0

    var body: some View {
        VStack {
            NativeAdvertisement(
                adUnitId: "ca-app-pub-1799604508581708/1254844405"
            ) { loadedAd, error in
                VStack {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay(
                            Text("AD")
                                .font(.custom("CreatoDisplay-Bold", size: 16))
                                .padding(8)
                                .background(.quaternary, in: .rect(cornerRadius: 14))
                        )
                        .nativeAdElement(.media)
                   

                    VStack(alignment: .leading) {
                        if let advertiser = loadedAd?.advertiser {
                            Text(advertiser.capitalized)
                                .hLeading()
                                .nativeAdElement(.advertiser)
                        }
                        if let headline = loadedAd?.headline {
                            Text(headline)
                                .font(.headline)
                                .bold()
                                .hLeading()
                                .nativeAdElement(.headline)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical)

                }
                .background(Color(UIColor.quaternarySystemFill))
                .aspectRatio(9/16, contentMode: .fill)
                .clipped()
                .frame(maxWidth: UIScreen.main.bounds.width)
            }
//            .frame(maxHeight: 300)
        }
    }

    private func startSlideshow(images: [URL]) {
        guard images.count > 1 else { return }

        Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: true) { _ in
            withAnimation(.easeInOut(duration: transitionDuration)) {
                opacity = 0.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration) {
                currentIndex = (currentIndex + 1) % images.count

                withAnimation(.easeInOut(duration: transitionDuration)) {
                    opacity = 1.0
                }
            }
        }
    }
}

struct OraInlineAdView: View {
    var ad: (NativeAd?, (any Error)?)
    var body: some View {

    }
}

#Preview {
    TestAdView()
}

