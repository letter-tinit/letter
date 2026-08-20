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
    @State private var habitViewModel: HabitViewModel
    @Environment(\.scenePhase) private var scenePhase
    private let notificationDelegate = LetterNotificationDelegate()
    
    init() {
        _habitViewModel = State(initialValue: container.makeHabitViewModel())
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabScreen(factory: container)
                // Keep SwiftUI's default body style, but make its design rounded.
                // Explicit customFont declarations on descendants still override this.
                .customFont(.body)
                .modelContainer(container.modelContainer)
                .environment(habitViewModel)
                .preferredColorScheme(preferredColorScheme)
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    habitViewModel.rescheduleHabitNotifications()
                }
        }
    }
    
    private var preferredColorScheme: ColorScheme? {
        switch habitViewModel.colorScheme {
        case .system: nil
        case .light: .light
        case .dark: .dark
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
