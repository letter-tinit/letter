import SwiftUI
import Domain
import Core
import Utility
import Styleguide

public struct AudioExportChapterSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedChapterIDs: Set<UUID> = []
    public let book: Book
    public let onExport: (Set<UUID>) -> Void

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(selectionActionTitle) {
                        if allChaptersAreSelected {
                            selectedChapterIDs.removeAll()
                        } else {
                            selectedChapterIDs = Set(book.chapters.map(\.id))
                        }
                    }
                }

                ForEach(book.chapterGroups) { group in
                    if let title = group.title {
                        Section(title) {
                            chapterRows(group.chapters)
                        }
                    } else {
                        Section {
                            chapterRows(group.chapters)
                        }
                    }
                }
            }
            .navigationTitle("audioBook.export.selection.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(exportActionTitle) {
                        let selection = selectedChapterIDs
                        dismiss()
                        onExport(selection)
                    }
                    .disabled(selectedChapterIDs.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func chapterRows(_ chapters: [BookChapter]) -> some View {
        ForEach(chapters) { chapter in
            Button {
                toggleSelection(for: chapter.id)
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(chapter.displayTitle)
                            .foregroundStyle(.primary)
                        Text(
                            String(
                                format: "audioBook.chapter.characters".localized,
                                chapter.characterCount
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: selectedChapterIDs.contains(chapter.id)
                          ? "checkmark.circle.fill"
                          : "circle")
                        .font(.title3)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var allChaptersAreSelected: Bool {
        !book.chapters.isEmpty && selectedChapterIDs.count == book.chapters.count
    }

    private var selectionActionTitle: String {
        allChaptersAreSelected
            ? "audioBook.export.selection.clear".localized
            : "audioBook.export.selection.all".localized
    }

    private var exportActionTitle: String {
        String(
            format: "audioBook.export.selection.action".localized,
            selectedChapterIDs.count
        )
    }

    private func toggleSelection(for chapterID: UUID) {
        if selectedChapterIDs.contains(chapterID) {
            selectedChapterIDs.remove(chapterID)
        } else {
            selectedChapterIDs.insert(chapterID)
        }
    }
}
