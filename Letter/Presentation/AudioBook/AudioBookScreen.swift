import SwiftUI
import UniformTypeIdentifiers

struct AudioBookScreen: View {
    @Environment(AudioBookViewModel.self) private var viewModel
    @State private var isImporting = false

    var body: some View {
        @Bindable var viewModel = viewModel

        BaseScreen(.constant("audioBook.tab.title".localized)) {
            VStack(spacing: 16) {
                if let documentName = viewModel.documentName {
                    Label(documentName, systemImage: "book.closed.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                TextEditor(text: $viewModel.text)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                HStack(spacing: 12) {
                    Button {
                        isImporting = true
                    } label: {
                        Label("audioBook.import".localized, systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        viewModel.speak()
                    } label: {
                        Label("audioBook.play".localized, systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if viewModel.isPlaying {
                    HStack(spacing: 12) {
                        Button(viewModel.isPaused ? "audioBook.resume".localized : "audioBook.pause".localized) {
                            viewModel.isPaused ? viewModel.resume() : viewModel.pause()
                        }
                        Button("audioBook.stop".localized) { viewModel.stop() }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.plainText, .rtf, .pdf],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            viewModel.importDocument(from: url)
        }
    }
}

#Preview {
    AudioBookScreen()
        .environment(AppContainer(inMemory: true).makeAudioBookViewModel())
}
