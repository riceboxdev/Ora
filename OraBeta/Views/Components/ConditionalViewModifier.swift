//
//  ConditionalViewModifier.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/30/25.
//

import SwiftUI
import Foundation


// MARK: - Helper Extensions
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content)
        -> some View
    {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
