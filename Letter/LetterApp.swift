//
//  LetterApp.swift
//  Letter
//
//  Created by Tín Nguyễn on 18/8/26.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct LetterApp: App {
    private let container = AppContainer()
    @State private var habitStore: HabitStore
    @Environment(\.scenePhase) private var scenePhase
    private let notificationDelegate = LetterNotificationDelegate()

    init() {
        _habitStore = State(initialValue: HabitStore(modelContext: container.modelContainer.mainContext))
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView(factory: container)
                .modelContainer(container.modelContainer)
                .environment(habitStore)
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    habitStore.rescheduleHabitNotifications()
                }
        }
    }
}

private final class LetterNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
