//
//  OraTextField.swift
//  OraBeta
//
//  Created by Nick Rogers on 11/19/25.
//

import SwiftUI

/// A reusable text field component with glass effect styling
struct OraTextField: View {
    let placeholder: String
    @Binding var text: String
    
    var height: CGFloat = 45
    var autocapitalization: TextInputAutocapitalization = .never
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var isSecure: Bool = false
    
    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .padding(.horizontal)
        .frame(height: height)
        .textInputAutocapitalization(autocapitalization)
        .keyboardType(keyboardType)
        .textContentType(textContentType)
        .glassEffect(.regular.interactive())
    }
}

#Preview {
    VStack(spacing: 20) {
        OraTextField(
            placeholder: "Email",
            text: .constant(""),
            keyboardType: .emailAddress,
            textContentType: .emailAddress
        )
        
        OraTextField(
            placeholder: "Display Name",
            text: .constant(""),
            autocapitalization: .words,
            textContentType: .name
        )
        
        OraTextField(
            placeholder: "Password",
            text: .constant(""),
            textContentType: .password,
            isSecure: true
        )
    }
    .padding()
}
