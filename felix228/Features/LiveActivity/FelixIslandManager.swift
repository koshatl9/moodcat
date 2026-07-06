//
//  FelixIslandManager.swift
//  felix228
//
//  Created by Codex on 14.05.2026.
//

import ActivityKit
import Combine
import Foundation

@MainActor
final class FelixIslandManager: ObservableObject {
    @Published private(set) var isFeatureEnabled = false
    @Published private(set) var isLiveActivityActive = false
    @Published private(set) var areActivitiesAuthorized = false
    @Published var errorMessage: String?

    private let defaults: UserDefaults

    private static let enabledKey = "felix228.felixIsland.enabled"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isFeatureEnabled = defaults.bool(forKey: Self.enabledKey)
        refreshSystemState()
    }

    var statusText: String {
        let language = AppLanguage.current(defaults: defaults)
        if isLiveActivityActive {
            return language.localized("Вкл.", "Увімк.", "On")
        }

        return isFeatureEnabled
            ? language.localized("Ожидает", "Очікує", "Waiting")
            : language.localized("Выкл.", "Вимк.", "Off")
    }

    func refreshSystemState() {
        areActivitiesAuthorized = ActivityAuthorizationInfo().areActivitiesEnabled
        isLiveActivityActive = !Activity<FelixIslandAttributes>.activities.isEmpty
    }

    func sync(snapshot: FelixIslandSnapshot, hasPremiumAccess: Bool) async {
        refreshSystemState()

        guard hasPremiumAccess else {
            if isLiveActivityActive {
                await stopPersistingPreference()
            }
            return
        }

        guard isFeatureEnabled else { return }
        guard areActivitiesAuthorized else { return }

        if let currentActivity = Activity<FelixIslandAttributes>.activities.first {
            await currentActivity.update(content(for: snapshot))
        } else {
            do {
                _ = try Activity<FelixIslandAttributes>.request(
                    attributes: FelixIslandAttributes(name: "Феликс"),
                    content: content(for: snapshot),
                    pushType: nil
                )
            } catch {
                errorMessage = "Не удалось запустить Felix в Dynamic Island. \(error.localizedDescription)"
            }
        }

        refreshSystemState()
    }

    func enable(snapshot: FelixIslandSnapshot, hasPremiumAccess: Bool) async {
        guard hasPremiumAccess else {
            errorMessage = "Эта функция открывается только по подписке Felix Premium."
            return
        }

        defaults.set(true, forKey: Self.enabledKey)
        isFeatureEnabled = true
        await sync(snapshot: snapshot, hasPremiumAccess: hasPremiumAccess)
    }

    func disable() async {
        await stopPersistingPreference()
    }

    private func stopPersistingPreference() async {
        defaults.set(false, forKey: Self.enabledKey)
        isFeatureEnabled = false

        let finalState = FelixIslandAttributes.ContentState(
            headline: "Феликс отдыхает",
            detail: "Dynamic Island можно включить снова в разделе Больше.",
            moodTitle: "Пауза",
            noteCount: 0
        )

        for activity in Activity<FelixIslandAttributes>.activities {
            await activity.end(content(for: finalState), dismissalPolicy: .immediate)
        }

        refreshSystemState()
    }

    private func content(for snapshot: FelixIslandSnapshot) -> ActivityContent<FelixIslandAttributes.ContentState> {
        content(
            for: FelixIslandAttributes.ContentState(
                headline: snapshot.headline,
                detail: snapshot.detail,
                moodTitle: snapshot.moodTitle,
                noteCount: snapshot.noteCount
            )
        )
    }

    private func content(for state: FelixIslandAttributes.ContentState) -> ActivityContent<FelixIslandAttributes.ContentState> {
        ActivityContent(
            state: state,
            staleDate: Calendar.current.date(byAdding: .hour, value: 8, to: .now)
        )
    }
}
