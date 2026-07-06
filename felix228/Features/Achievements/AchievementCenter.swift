//
//  AchievementCenter.swift
//  felix228
//
//  Created by Codex on 18.05.2026.
//

import Combine
import Foundation
import SwiftUI

enum FelixAchievementID: String, CaseIterable, Identifiable {
    case firstEntry
    case sevenEntries
    case firstGoal
    case firstCompletedGoal
    case premiumHappyCat

    var id: String { rawValue }
}

struct FelixAchievementBadge: Identifiable {
    let id: FelixAchievementID
    let title: String
    let subtitle: String
    let reward: String
    let icon: String
    let artworkAssetName: String?
    let starCount: Int
    let tint: Color
    let unlockedAt: Date?

    var isUnlocked: Bool {
        unlockedAt != nil
    }
}

@MainActor
final class AchievementManager: ObservableObject {
    @Published private(set) var unlockedDates: [FelixAchievementID: Date] = [:]

    private let defaults: UserDefaults

    private static let storageKey = "felix228.achievements.unlockedDates"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.unlockedDates = Self.loadUnlockedDates(from: defaults)
    }

    private var currentLanguage: AppLanguage {
        AppLanguage.current(defaults: defaults)
    }

    var badges: [FelixAchievementBadge] {
        let language = currentLanguage
        return Self.catalog.map { definition in
            FelixAchievementBadge(
                id: definition.id,
                title: definition.title(for: language),
                subtitle: definition.subtitle(for: language),
                reward: definition.reward(for: language),
                icon: definition.icon,
                artworkAssetName: definition.artworkAssetName(for: language),
                starCount: definition.starCount,
                tint: definition.tint,
                unlockedAt: unlockedDates[definition.id]
            )
        }
    }

    var unlockedCount: Int {
        badges.filter(\.isUnlocked).count
    }

    var totalCount: Int {
        Self.catalog.count
    }

    var recentUnlockedBadges: [FelixAchievementBadge] {
        badges
            .filter(\.isUnlocked)
            .sorted {
                ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast)
            }
    }

    var exportedUnlockedDateTimestamps: [String: Double] {
        Dictionary(
            uniqueKeysWithValues: unlockedDates.map { key, value in
                (key.rawValue, value.timeIntervalSince1970)
            }
        )
    }

    @discardableResult
    func badge(for id: FelixAchievementID) -> FelixAchievementBadge {
        badges.first { $0.id == id } ?? Self.placeholderBadge(for: id)
    }

    @discardableResult
    func synchronize(
        entries: [EmotionEntry],
        goals: [DailyGoal],
        hasPremiumAccess: Bool,
        now: Date = .now
    ) -> Bool {
        var didUnlockAnything = false

        if let firstEntryDate = entries.map(\.createdAt).min() {
            didUnlockAnything = unlock(.firstEntry, at: firstEntryDate) || didUnlockAnything
        }

        if entries.count >= 7 {
            let sortedEntryDates = entries.map(\.createdAt).sorted()
            didUnlockAnything = unlock(.sevenEntries, at: sortedEntryDates[6]) || didUnlockAnything
        }

        if let firstGoalDate = goals.map(\.createdAt).min() {
            didUnlockAnything = unlock(.firstGoal, at: firstGoalDate) || didUnlockAnything
        }

        if let firstCompletedGoalDate = goals
            .flatMap(\.completionHistory)
            .min()
        {
            didUnlockAnything = unlock(.firstCompletedGoal, at: firstCompletedGoalDate) || didUnlockAnything
        }

        if hasPremiumAccess {
            didUnlockAnything = unlock(.premiumHappyCat, at: now) || didUnlockAnything
        }

        return didUnlockAnything
    }

    func replaceUnlockedDates(fromTimestamps timestamps: [String: Double]) {
        let restoredDates = Self.unlockedDates(fromTimestamps: timestamps)
        guard restoredDates != unlockedDates else { return }
        unlockedDates = restoredDates
        persist()
    }

    @discardableResult
    private func unlock(_ id: FelixAchievementID, at date: Date) -> Bool {
        guard unlockedDates[id] == nil else { return false }
        unlockedDates[id] = date
        persist()
        return true
    }

    private func persist() {
        defaults.set(exportedUnlockedDateTimestamps, forKey: Self.storageKey)
    }

    private static func loadUnlockedDates(from defaults: UserDefaults) -> [FelixAchievementID: Date] {
        guard let dictionary = defaults.dictionary(forKey: storageKey) as? [String: Double] else {
            return [:]
        }

        return unlockedDates(fromTimestamps: dictionary)
    }

    private static func unlockedDates(fromTimestamps timestamps: [String: Double]) -> [FelixAchievementID: Date] {
        var result: [FelixAchievementID: Date] = [:]

        for (rawValue, timestamp) in timestamps {
            guard let id = FelixAchievementID(rawValue: rawValue) else { continue }
            result[id] = Date(timeIntervalSince1970: timestamp)
        }

        return result
    }

    private static func placeholderBadge(for id: FelixAchievementID) -> FelixAchievementBadge {
        let language = AppLanguage.current()
        let definition = catalog.first { $0.id == id } ?? catalog[0]
        return FelixAchievementBadge(
            id: definition.id,
            title: definition.title(for: language),
            subtitle: definition.subtitle(for: language),
            reward: definition.reward(for: language),
            icon: definition.icon,
            artworkAssetName: definition.artworkAssetName(for: language),
            starCount: definition.starCount,
            tint: definition.tint,
            unlockedAt: nil
        )
    }

    private static let catalog: [AchievementDefinition] = [
        AchievementDefinition(
            id: .firstEntry,
            titleRussian: "Твоя первая запись",
            titleUkrainian: "Твій перший запис",
            titleEnglish: "Your first entry",
            subtitleRussian: "Открывается, когда ты честно отмечаешь свою первую эмоцию.",
            subtitleUkrainian: "Відкривається, коли ти чесно відзначаєш свою першу емоцію.",
            subtitleEnglish: "Unlocked when you honestly log your very first emotion.",
            rewardRussian: "Феликс заметил начало твоего дневника.",
            rewardUkrainian: "Фелікс помітив початок твого щоденника.",
            rewardEnglish: "Felix noticed the beginning of your journal.",
            icon: "sparkles",
            artworkAssetName: "FirstEntryAchievement",
            localizedArtworkAssetName: "FirstEntryAchievementLocalized",
            starCount: 1,
            tint: Color(red: 0.98, green: 0.73, blue: 0.29)
        ),
        AchievementDefinition(
            id: .sevenEntries,
            titleRussian: "7 дней рядом",
            titleUkrainian: "7 днів разом",
            titleEnglish: "7 days together",
            subtitleRussian: "Открывается после семи записей в дневнике.",
            subtitleUkrainian: "Відкривається після семи записів у щоденнику.",
            subtitleEnglish: "Unlocked after seven entries in your journal.",
            rewardRussian: "Феликс видит, что ты держишь ритм.",
            rewardUkrainian: "Фелікс бачить, що ти тримаєш ритм.",
            rewardEnglish: "Felix can see that you're keeping the rhythm.",
            icon: "calendar.badge.checkmark",
            artworkAssetName: "SevenDaysAchievement",
            localizedArtworkAssetName: "SevenDaysAchievementLocalized",
            starCount: 2,
            tint: Color(red: 0.58, green: 0.73, blue: 0.98)
        ),
        AchievementDefinition(
            id: .firstGoal,
            titleRussian: "Первая цель",
            titleUkrainian: "Перша ціль",
            titleEnglish: "First goal",
            subtitleRussian: "Добавь первую цель, чтобы начать поддерживать себя маленькими шагами.",
            subtitleUkrainian: "Додай першу ціль, щоб почати підтримувати себе маленькими кроками.",
            subtitleEnglish: "Add your first goal to start supporting yourself with small steps.",
            rewardRussian: "У тебя появляется собственный вектор дня.",
            rewardUkrainian: "У тебе з'являється власний вектор дня.",
            rewardEnglish: "You now have your own direction for the day.",
            icon: "target",
            artworkAssetName: "FirstGoalAchievement",
            localizedArtworkAssetName: "FirstGoalAchievementLocalized",
            starCount: 1,
            tint: Color(red: 0.69, green: 0.61, blue: 0.95)
        ),
        AchievementDefinition(
            id: .firstCompletedGoal,
            titleRussian: "Галочка дня",
            titleUkrainian: "Галочка дня",
            titleEnglish: "Checkmark of the day",
            subtitleRussian: "Открывается, когда ты впервые отмечаешь выполненную цель.",
            subtitleUkrainian: "Відкривається, коли ти вперше відзначаєш виконану ціль.",
            subtitleEnglish: "Unlocked when you mark a goal as completed for the first time.",
            rewardRussian: "Феликс празднует твою первую маленькую победу.",
            rewardUkrainian: "Фелікс святкує твою першу маленьку перемогу.",
            rewardEnglish: "Felix is celebrating your first little win.",
            icon: "checkmark.seal.fill",
            artworkAssetName: "CompletedGoalAchievement",
            localizedArtworkAssetName: "CompletedGoalAchievementLocalized",
            starCount: 2,
            tint: Color(red: 0.42, green: 0.79, blue: 0.53)
        ),
        AchievementDefinition(
            id: .premiumHappyCat,
            titleRussian: "Котик счастлив",
            titleUkrainian: "Котик щасливий",
            titleEnglish: "Happy kitty",
            subtitleRussian: "Открывается после оформления premium-подписки.",
            subtitleUkrainian: "Відкривається після оформлення premium-підписки.",
            subtitleEnglish: "Unlocked after activating your premium subscription.",
            rewardRussian: "Ещё одна вкусняшка прилетела Феликсу.",
            rewardUkrainian: "Ще одна смаколика прилетіла Феліксу.",
            rewardEnglish: "Another tasty treat has arrived for Felix.",
            icon: "crown.fill",
            artworkAssetName: "PremiumHappyCatAchievement",
            localizedArtworkAssetName: "PremiumHappyCatAchievementLocalized",
            starCount: 3,
            tint: Color(red: 0.97, green: 0.48, blue: 0.41)
        ),
    ]
}

private struct AchievementDefinition {
    let id: FelixAchievementID
    let titleRussian: String
    let titleUkrainian: String
    let titleEnglish: String
    let subtitleRussian: String
    let subtitleUkrainian: String
    let subtitleEnglish: String
    let rewardRussian: String
    let rewardUkrainian: String
    let rewardEnglish: String
    let icon: String
    let artworkAssetName: String?
    let localizedArtworkAssetName: String?
    let starCount: Int
    let tint: Color

    func title(for language: AppLanguage) -> String {
        language.localized(titleRussian, titleUkrainian, titleEnglish)
    }

    func subtitle(for language: AppLanguage) -> String {
        language.localized(subtitleRussian, subtitleUkrainian, subtitleEnglish)
    }

    func reward(for language: AppLanguage) -> String {
        language.localized(rewardRussian, rewardUkrainian, rewardEnglish)
    }

    func artworkAssetName(for language: AppLanguage) -> String? {
        switch language {
        case .russian:
            return artworkAssetName
        case .ukrainian, .english:
            return localizedArtworkAssetName ?? artworkAssetName
        }
    }
}

struct AchievementsCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var achievementManager: AchievementManager
    @EnvironmentObject private var localization: LocalizationManager
    @State private var selectedAchievementID: FelixAchievementID = .firstEntry
    @State private var spotlightAchievementID: FelixAchievementID?

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    private var selectedBadge: FelixAchievementBadge {
        achievementManager.badge(for: selectedAchievementID)
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 18), count: 3)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AchievementsBackground(palette: palette)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        AchievementHeroCard(
                            palette: palette,
                            unlockedCount: achievementManager.unlockedCount,
                            totalCount: achievementManager.totalCount,
                            hasUnlockedAny: achievementManager.unlockedCount > 0
                        )

                        LazyVGrid(columns: gridColumns, spacing: 26) {
                            ForEach(achievementManager.badges) { badge in
                                AchievementMedalTile(
                                    badge: badge,
                                    isSelected: badge.id == selectedAchievementID,
                                    onTap: {
                                        selectedAchievementID = badge.id
                                        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                                            spotlightAchievementID = badge.id
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.top, 6)

                        AchievementSelectedCard(
                            badge: selectedBadge,
                            palette: palette
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .overlay {
                if let spotlightAchievementID {
                    AchievementSpotlightOverlay(
                        badge: achievementManager.badge(for: spotlightAchievementID),
                        dismissAction: {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                self.spotlightAchievementID = nil
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }
            .navigationTitle(localization.pick("Достижения", "Achievements"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let firstUnlocked = achievementManager.recentUnlockedBadges.first?.id {
                    selectedAchievementID = firstUnlocked
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localization.pick("Закрыть", "Close")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct AchievementsBackground: View {
    let palette: ThemePalette

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    palette.background.opacity(0.96),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(red: 0.39, green: 0.95, blue: 0.58).opacity(0.15))
                .frame(width: 280, height: 280)
                .blur(radius: 85)
                .offset(x: -120, y: -260)

            Circle()
                .fill(palette.accent.opacity(0.18))
                .frame(width: 230, height: 230)
                .blur(radius: 70)
                .offset(x: 160, y: 320)
        }
        .ignoresSafeArea()
    }
}

private struct AchievementHeroCard: View {
    @EnvironmentObject private var localization: LocalizationManager

    let palette: ThemePalette
    let unlockedCount: Int
    let totalCount: Int
    let hasUnlockedAny: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(localization.pick("Коллекция наград", "Reward collection"))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(
                        hasUnlockedAny
                            ? localization.pick(
                                "Ты уже открыла часть наград. Дальше будет ещё ярче.",
                                "You've already unlocked part of the collection. It only gets brighter from here."
                            )
                            : localization.pick(
                                "Сделай первую запись, и Феликс начнёт собирать награды вместе с тобой.",
                                "Create your first entry and Felix will start collecting rewards with you."
                            )
                    )
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Text("\(unlockedCount)/\(totalCount)")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.45, green: 0.93, blue: 0.56))
            }

            HStack(spacing: 10) {
                AchievementSummaryChip(
                    title: localization.pick("Открыто", "Unlocked"),
                    value: "\(unlockedCount)"
                )
                AchievementSummaryChip(
                    title: localization.pick("Закрыто", "Locked"),
                    value: "\(max(totalCount - unlockedCount, 0))"
                )
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.10, blue: 0.14),
                            Color(red: 0.14, green: 0.09, blue: 0.18),
                            Color(red: 0.08, green: 0.08, blue: 0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 24, y: 12)
    }
}

private struct AchievementSummaryChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.56))

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct AchievementMedalTile: View {
    let badge: FelixAchievementBadge
    let isSelected: Bool
    let onTap: () -> Void

    private var orbSize: CGFloat {
        isSelected ? 112 : 96
    }

    private var artworkSize: CGFloat {
        isSelected ? 62 : 46
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    badge.isUnlocked ? badge.tint.opacity(isSelected ? 0.26 : 0.16) : Color.white.opacity(0.08),
                                    Color.white.opacity(0.03)
                                ],
                                center: .center,
                                startRadius: 8,
                                endRadius: orbSize / 2
                            )
                        )
                        .frame(width: orbSize, height: orbSize)

                    Circle()
                        .trim(from: 0.08, to: 0.92)
                        .stroke(
                            badge.isUnlocked
                                ? Color(red: 0.45, green: 0.93, blue: 0.56)
                                : Color.white.opacity(0.20),
                            style: StrokeStyle(lineWidth: isSelected ? 6 : 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(96))
                        .frame(width: orbSize, height: orbSize)

                    AchievementBadgeIcon(badge: badge)
                        .frame(width: artworkSize, height: artworkSize)

                    AchievementStarsRow(
                        activeCount: badge.isUnlocked ? badge.starCount : 0
                    )
                    .scaleEffect(isSelected ? 1.12 : 1)
                    .offset(y: orbSize / 2 - 4)
                }
                .frame(height: isSelected ? 134 : 120)
                .shadow(
                    color: badge.isUnlocked ? badge.tint.opacity(isSelected ? 0.30 : 0.16) : .clear,
                    radius: isSelected ? 18 : 10,
                    y: 8
                )

                Text(badge.title)
                    .font(.system(size: 14, weight: isSelected ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(badge.isUnlocked ? 0.98 : 0.72))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 2)
            .scaleEffect(isSelected ? 1.08 : 1)
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

private struct AchievementBadgeIcon: View {
    let badge: FelixAchievementBadge

    var body: some View {
        Group {
            if let artworkAssetName = badge.artworkAssetName {
                Image(artworkAssetName)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: badge.icon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(badge.isUnlocked ? badge.tint : Color.white.opacity(0.24))
            }
        }
    }
}

private struct AchievementStarsRow: View {
    let activeCount: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.caption.weight(.black))
                    .foregroundStyle(
                        index < activeCount
                            ? Color(red: 0.45, green: 0.93, blue: 0.56)
                            : Color.white.opacity(0.28)
                    )
            }
        }
    }
}

private struct AchievementSelectedCard: View {
    @EnvironmentObject private var localization: LocalizationManager

    let badge: FelixAchievementBadge
    let palette: ThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(badge.isUnlocked ? badge.tint.opacity(0.18) : Color.white.opacity(0.04))
                        .frame(width: 64, height: 64)

                    Circle()
                        .stroke(
                            badge.isUnlocked ? Color(red: 0.45, green: 0.93, blue: 0.56) : Color.white.opacity(0.18),
                            lineWidth: 3
                        )
                        .frame(width: 64, height: 64)

                    AchievementBadgeIcon(badge: badge)
                        .frame(width: 28, height: 28)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(badge.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(
                        badge.isUnlocked
                            ? localization.pick("Достижение открыто", "Achievement unlocked")
                            : localization.pick("Достижение пока закрыто", "Achievement still locked")
                    )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(
                            badge.isUnlocked
                                ? Color(red: 0.45, green: 0.93, blue: 0.56)
                                : Color.white.opacity(0.55)
                        )
                }

                Spacer(minLength: 0)
            }

            Text(badge.subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text(localization.pick("Награда", "Reward"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.50))

                Text(badge.reward)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                AchievementStarsRow(activeCount: badge.isUnlocked ? badge.starCount : 0)

                Spacer()

                if let unlockedAt = badge.unlockedAt {
                    Text(localization.pick("Получено", "Unlocked") + " " + formattedDate(unlockedAt))
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.56))
                } else {
                    Text(localization.pick("Продолжай вести дневник", "Keep journaling"))
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.56))
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.11, green: 0.11, blue: 0.14),
                            Color(red: 0.08, green: 0.08, blue: 0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(badge.isUnlocked ? badge.tint.opacity(0.30) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 22, y: 12)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = localization.locale
        formatter.dateFormat = localization.selectedLanguage.dayMonthFormat
        return formatter.string(from: date)
    }
}

private struct AchievementSpotlightOverlay: View {
    @EnvironmentObject private var localization: LocalizationManager

    let badge: FelixAchievementBadge
    let dismissAction: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .onTapGesture(perform: dismissAction)

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    badge.tint.opacity(0.34),
                                    Color.white.opacity(0.04)
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 130
                            )
                        )
                        .frame(width: 236, height: 236)

                    Circle()
                        .stroke(
                            badge.isUnlocked
                                ? Color(red: 0.45, green: 0.93, blue: 0.56)
                                : Color.white.opacity(0.28),
                            lineWidth: 7
                        )
                        .frame(width: 214, height: 214)

                    AchievementBadgeIcon(badge: badge)
                        .frame(width: 148, height: 148)
                }

                VStack(spacing: 10) {
                    Text(badge.title)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(badge.subtitle)
                        .font(.body)
                        .foregroundStyle(Color.white.opacity(0.76))
                        .multilineTextAlignment(.center)
                }

                AchievementStarsRow(activeCount: badge.isUnlocked ? badge.starCount : 0)
                    .scaleEffect(1.25)

                Button(localization.pick("Понятно", "Got it")) {
                    dismissAction()
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 26)
                .padding(.vertical, 14)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white)
                )
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 28)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.12, green: 0.12, blue: 0.16),
                                Color(red: 0.08, green: 0.08, blue: 0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.34), radius: 28, y: 16)
            .padding(.horizontal, 24)
        }
    }
}

struct AchievementPreviewRow: View {
    @EnvironmentObject private var localization: LocalizationManager

    let badge: FelixAchievementBadge
    let palette: ThemePalette

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 56, height: 56)

                Circle()
                    .trim(from: 0.08, to: 0.92)
                    .stroke(
                        badge.isUnlocked
                            ? Color(red: 0.45, green: 0.93, blue: 0.56)
                            : Color.white.opacity(0.18),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(96))
                    .frame(width: 56, height: 56)

                AchievementBadgeIcon(badge: badge)
                    .frame(width: 24, height: 24)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(badge.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    AchievementStarsRow(activeCount: badge.isUnlocked ? badge.starCount : 0)

                    if let unlockedAt = badge.unlockedAt {
                        Text(formattedDate(unlockedAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = localization.locale
        formatter.dateFormat = localization.selectedLanguage.shortDayMonthFormat
        return formatter.string(from: date)
    }
}

private struct AchievementsEmptyStateRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct AchievementBadgeCard: View {
    @EnvironmentObject private var localization: LocalizationManager

    let badge: FelixAchievementBadge
    let palette: ThemePalette

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(badge.tint.opacity(badge.isUnlocked ? 0.18 : 0.08))
                .frame(width: 54, height: 54)
                .overlay(
                    Image(systemName: badge.icon)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(badge.isUnlocked ? badge.tint : .secondary)
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(badge.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(badge.isUnlocked ? localization.pick("Открыто", "Unlocked") : localization.pick("Закрыто", "Locked"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(badge.isUnlocked ? badge.tint : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill((badge.isUnlocked ? badge.tint : Color.white).opacity(badge.isUnlocked ? 0.14 : 0.08))
                        )
                }

                Text(badge.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(badge.reward)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(badge.isUnlocked ? .primary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let unlockedAt = badge.unlockedAt {
                    Text(localization.pick("Получено", "Unlocked") + " " + formattedDateTime(unlockedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(palette.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(badge.isUnlocked ? badge.tint.opacity(0.22) : palette.stroke, lineWidth: 1)
        )
    }

    private func formattedDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = localization.locale
        formatter.dateFormat = localization.selectedLanguage.dayMonthTimeFormat
        return formatter.string(from: date)
    }
}
