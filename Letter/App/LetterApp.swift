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
    @State private var financeLockManager: FinanceLockManager
    @Environment(\.scenePhase) private var scenePhase
    private let notificationDelegate = LetterNotificationDelegate()
    
    init() {
        _habitViewModel = State(initialValue: container.makeHabitViewModel())
        _financeLockManager = State(initialValue: FinanceLockManager())
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
                .environment(financeLockManager)
                .preferredColorScheme(preferredColorScheme)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        habitViewModel.rescheduleHabitNotifications()
                    } else if phase == .background || !financeLockManager.isAuthenticating {
                        financeLockManager.lock()
                    }
                }
        }
    }
    
    private var preferredColorScheme: ColorScheme? {
        switch habitViewModel.colorScheme {
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
