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
    private let container = AppContainer()
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
