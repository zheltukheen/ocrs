import SwiftUI

struct OCRResultView: View {
    let text: String
    let onCopy: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "text.viewfinder")
                Text("Extracted Text")
                    .font(.headline)
                Spacer()
            }

            ScrollView {
                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(height: 240)

            HStack {
                Button("Close") {
                    onClose()
                }

                Spacer()

                Button("Copy to Clipboard") {
                    onCopy()
                }
            }
        }
        .padding(16)
        .frame(width: 420)
    }
}
