//
//  LetterApp.swift
//  Letter
//
//  Created by Tín Nguyễn on 18/8/26.
//

import SwiftUI
import SwiftData
import UserNotifications
import Presentation
import Domain
import Styleguide

@main
struct LetterApp: App {
    private let container = makeContainer()
    private let notificationDelegate = LetterNotificationDelegate()
    
    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabScreen(factory: container)
                // Keep SwiftUI's default body style, but make its design rounded.
                // Explicit customFont declarations on descendants still override this.
                .customFont(.body)
                .modelContainer(container.modelContainer)
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

// UI tests retain real persistence and use cases in a separate temporary store.
// The launch environment is ignored in release builds.
@MainActor
private func makeContainer() -> AppContainer {
#if DEBUG
    if let session = ProcessInfo.processInfo.environment["LETTER_UI_TEST_SESSION"],
       let id = UUID(uuidString: session) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HabitUITests-\(id.uuidString).store")
        return AppContainer(inMemory: true, storeURL: url)
    }
#endif
    return AppContainer()
}
