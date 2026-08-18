//
//  ContentView.swift
//  Letter
//
//  Created by Tín Nguyễn on 18/8/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    let factory: AppViewModelFactory

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    FinanceMainScreen(factory: factory)
                } label: {
                    Label("Personal Finance", systemImage: "wallet.bifold.fill")
                }

                NavigationLink {
                    HabitMainScreen()
                } label: {
                    Label("Habits", systemImage: "checkmark.circle.fill")
                }
            }
            .navigationTitle("Letter")
        }
    }
}

#Preview {
    let container = AppContainer(inMemory: true)
    ContentView(factory: container)
        .modelContainer(container.modelContainer)
        .environment(HabitStore(modelContext: container.modelContainer.mainContext))
}
