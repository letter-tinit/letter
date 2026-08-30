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
    @State private var profileViewModel: ProfileViewModel
    @State private var financeLockManager: FinanceLockManager
    @State private var audioBookViewModel: AudioBookViewModel
    @Environment(\.scenePhase) private var scenePhase
    private let notificationDelegate = LetterNotificationDelegate()
    
    init() {
        let profileViewModel = container.makeProfileViewModel()
        _profileViewModel = State(initialValue: profileViewModel)
        _habitViewModel = State(initialValue: container.makeHabitViewModel())
        _financeLockManager = State(initialValue: container.makeFinanceLockManager())
        _audioBookViewModel = State(initialValue: container.makeAudioBookViewModel())
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
                .environment(profileViewModel)
                .environment(financeLockManager)
                .environment(audioBookViewModel)
                .preferredColorScheme(preferredColorScheme)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        habitViewModel.rescheduleHabitNotifications()
                    } else {
                        audioBookViewModel.persistPlaybackCheckpoint()
                        if phase == .background || !financeLockManager.isAuthenticating {
                            financeLockManager.lock()
                        }
                    }
                }
        }
    }
    
    private var preferredColorScheme: ColorScheme? {
        switch profileViewModel.colorScheme {
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
