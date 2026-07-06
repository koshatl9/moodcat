//
//  felix228App.swift
//  felix228
//
//  Created by Dasha Stepanova on 12.05.2026.
//

import Combine
import GoogleSignIn
import SwiftUI
import SwiftData
import UIKit
import UserNotifications

final class AppNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        CloudAccountManager.configureFirebaseIfPossible()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

@main
struct felix228App: App {
    @UIApplicationDelegateAdaptor(AppNotificationDelegate.self) private var notificationDelegate
    @StateObject private var cloudAccountManager = CloudAccountManager()
    @StateObject private var moodCustomizationManager = MoodCustomizationManager()
    @StateObject private var premiumAccessManager = PremiumAccessManager()
    @StateObject private var felixIslandManager = FelixIslandManager()
    @StateObject private var achievementManager = AchievementManager()
    @StateObject private var localizationManager = LocalizationManager()
    @StateObject private var themeManager = ThemeManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            EmotionEntry.self,
            DailyGoal.self,
            ActivityOption.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])

            let existingActivities = try container.mainContext.fetch(FetchDescriptor<ActivityOption>())
            if existingActivities.isEmpty {
                for template in ActivityTemplate.defaults {
                    container.mainContext.insert(
                        ActivityOption(
                            title: template.title,
                            symbolName: template.symbolName
                        )
                    )
                }

                try container.mainContext.save()
            }

            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(themeManager.preferredColorScheme)
                .environment(\.locale, localizationManager.locale)
                .environmentObject(cloudAccountManager)
                .environmentObject(moodCustomizationManager)
                .environmentObject(premiumAccessManager)
                .environmentObject(felixIslandManager)
                .environmentObject(achievementManager)
                .environmentObject(localizationManager)
                .environmentObject(themeManager)
                .onReceive(premiumAccessManager.$hasPremiumAccess.removeDuplicates()) { hasPremiumAccess in
                    themeManager.refreshCurrentTheme(hasPremiumAccess: hasPremiumAccess)
                }
                .onOpenURL { url in
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
