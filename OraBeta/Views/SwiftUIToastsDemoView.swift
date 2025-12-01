import SwiftUI
import Toasts

struct SwiftUIToastsDemoView: View {
    var body: some View {
        SwiftUIToastsContent()
            .installToast(position: .bottom)
    }
}

private struct SwiftUIToastsContent: View {
    @Environment(\.presentToast) var presentToast

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Basic Toasts")) {
                    Button("Show Simple Toast") {
                        let toast = ToastValue(
                            icon: Image(systemName: "bell.fill"),
                            message: "You have a new notification."
                        )
                        presentToast(toast)
                    }
                    
                    Button("Show Success Toast") {
                        let toast = ToastValue(
                            icon: Image(systemName: "checkmark.circle.fill"),
                            message: "Action completed successfully!"
                        )
                        presentToast(toast)
                    }
                    
                    Button("Show Error Toast") {
                        let toast = ToastValue(
                            icon: Image(systemName: "exclamationmark.triangle.fill"),
                            message: "Something went wrong."
                        )
                        presentToast(toast)
                    }
                }
                
                Section(header: Text("Advanced Toasts")) {
                    Button("Toast with Button") {
                        let toast = ToastValue(
                            message: "File deleted.",
                            button: ToastButton(
                                title: "Undo",
                                color: .blue,
                                action: {
                                    print("Undo tapped")
                                }
                            )
                        )
                        presentToast(toast)
                    }
                    
                    Button("Loading Toast") {
                        Task {
                            try? await presentToast(
                                message: "Uploading...",
                                task: { () -> String in
                                    // Simulate network request
                                    try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                                    return "Upload Complete"
                                },
                                onSuccess: { result in
                                    ToastValue(
                                        icon: Image(systemName: "checkmark.circle.fill"),
                                        message: result
                                    )
                                },
                                onFailure: { error in
                                    ToastValue(
                                        icon: Image(systemName: "xmark.circle.fill"),
                                        message: error.localizedDescription
                                    )
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Toast Demo")
        }
    }
}

#Preview {
    SwiftUIToastsDemoView()
}
