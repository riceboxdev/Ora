//
//  LoadingIndicator.swift
//  OraBeta
//
//  Shared loading indicator component
//

import SwiftUI

/// Reusable loading indicator with optional padding
struct LoadingIndicator: View {
    let padding: EdgeInsets
    
    init(padding: EdgeInsets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)) {
        self.padding = padding
    }
    
    var body: some View {
        ProgressView()
            .padding(padding)
    }
}

/// Centered loading indicator in HStack
struct CenteredLoadingIndicator: View {
    var body: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding()
            Spacer()
        }
    }
}
