import AdMobUI
import GoogleMobileAds
import SwiftUI

struct TestAdView: View {
    var body: some View {
        NativeAdvertisement(
            adUnitId: "ca-app-pub-1799604508581708/1254844405"
        ) { loadedAd, error in
            VStack(spacing: 0) {
                // Ad Media
                Rectangle()
                    .fill(.quaternary)
                    .overlay(
                        Text("AD")
                            .font(.custom("CreatoDisplay-Bold", size: 16))
                            .padding(8)
                            .background(.quaternary, in: .rect(cornerRadius: 14))
                    )
                    .nativeAdElement(.media)
                
                // Ad Content
                VStack(alignment: .leading, spacing: 8) {
                    if let advertiser = loadedAd?.advertiser {
                        Text(advertiser.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                .padding(.vertical, 8)
            }
            .background(Color(UIColor.quaternarySystemFill))
            .aspectRatio(9/16, contentMode: .fill)
            .clipped()
            .cornerRadius(20)
        }
        .frame(maxHeight: 300)
    }
}

#Preview {
    TestAdView()
}
