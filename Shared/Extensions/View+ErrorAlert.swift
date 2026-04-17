import SwiftUI

extension View {
    func errorAlert(message: Binding<String?>) -> some View {
        alert("Something went wrong", isPresented: Binding(
            get: { message.wrappedValue != nil },
            set: { if !$0 { message.wrappedValue = nil } }
        )) {
            Button("OK") { message.wrappedValue = nil }
        } message: {
            if let msg = message.wrappedValue {
                Text(msg)
            }
        }
    }
}
