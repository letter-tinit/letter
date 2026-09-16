//
//  AudioBookIndexingSheet.swift
//  Presentation
//
//  Created by Tín Nguyễn on 16/9/26.
//

import SwiftUI

struct AudioBookIndexingSheet: View {
    @Environment(AudioBookViewModel.self) private var viewModel
    
    var body: some View {
        List {
            ForEach(viewModel.importItems) { item in
                AudioBookImportRow(item: item)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("audioBook.import.indexing".localized)
            }
        }
    }
}
