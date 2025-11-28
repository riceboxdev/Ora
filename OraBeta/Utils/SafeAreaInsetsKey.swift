//
//  SafeAreaInsetsKey 2.swift
//  Ora
//
//  Created by Nick Rogers on 11/21/25.
//


import Foundation
import SwiftUI
import UIKit

// MARK: Extensions for UI Designing
extension View{

    func hLeading()->some View{
        self
            .frame(maxWidth: .infinity,alignment: .leading)
    }

    func hTrailing()->some View{
        self
            .frame(maxWidth: .infinity,alignment: .trailing)
    }

    func hCenter()->some View{
        self
            .frame(maxWidth: .infinity,alignment: .center)
    }
}


private struct SafeAreaInsetsKey: EnvironmentKey {
    static var defaultValue: EdgeInsets {
        (UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets ?? .zero).insets
    }
}

extension EnvironmentValues {
    
    var safeAreaInsets: EdgeInsets {
        self[SafeAreaInsetsKey.self]
    }
}

private extension UIEdgeInsets {
    
    var insets: EdgeInsets {
        EdgeInsets(top: top, leading: left, bottom: bottom, trailing: right)
    }
}

extension UIColor {
    var inverted: UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        // Extract RGBA components
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return UIColor(red: 1 - red,
                       green: 1 - green,
                       blue: 1 - blue,
                       alpha: alpha)
    }
}

extension Color {
    var inverted: Color {
        // Convert SwiftUI Color → UIColor → inverted UIColor → SwiftUI Color
        let uiColor = UIColor(self)
        return Color(uiColor.inverted)
    }
}
