//
//  FelixIslandSettingsView.swift
//  felix228
//
//  Created by Codex on 14.05.2026.
//

import Combine
import SwiftUI

struct FelixIslandSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var premiumAccess: PremiumAccessManager
    @EnvironmentObject private var felixIslandManager: FelixIslandManager

    let snapshot: FelixIslandSnapshot

    @State private var errorMessage: String?

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView(palette: palette)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        heroCard
                        behaviorCard
                        actionCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Felix Island")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .task {
                felixIslandManager.refreshSystemState()
            }
            .onReceive(felixIslandManager.$errorMessage.compactMap { $0 }) { message in
                errorMessage = message
            }
            .alert("Felix Island недоступен", isPresented: isShowingError) {
                Button("Ок", role: .cancel) {
                    felixIslandManager.errorMessage = nil
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "Попробуй ещё раз.")
            }
        }
    }

    private var heroCard: some View {
        StatisticsSectionCard(
            palette: palette,
            title: "Сидящий Феликс в Dynamic Island",
            subtitle: "Premium-функция, которая держит рыжего котёнка рядом наверху экрана."
        ) {
            HStack(spacing: 18) {
                Image("NormalMoodKitten")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)

                VStack(alignment: .leading, spacing: 8) {
                    Text(felixIslandManager.isLiveActivityActive ? "Феликс уже сидит на островке" : "Феликс пока отдыхает")
                        .font(.headline.weight(.bold))

                    Text("На iPhone с Dynamic Island котёнок будет наверху. На других моделях он появится как Live Activity на экране блокировки.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var behaviorCard: some View {
        StatisticsSectionCard(
            palette: palette,
            title: "Что он показывает",
            subtitle: "Felix обновляется по твоим заметкам в течение дня."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Label(snapshot.headline, systemImage: "sparkles")
                    .font(.headline.weight(.semibold))

                Text(snapshot.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    statusPill("Настроение: \(snapshot.moodTitle)")
                    statusPill("Записей: \(snapshot.noteCount)")
                }

                Text("Это не GIF, а настоящая Live Activity по правилам iPhone, поэтому Felix выглядит живо и системно.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actionCard: some View {
        StatisticsSectionCard(
            palette: palette,
            title: "Управление",
            subtitle: premiumAccess.hasPremiumAccess ? "Включай или отключай Felix Island в любой момент." : "Функция открывается только по подписке."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Text(felixIslandManager.areActivitiesAuthorized
                        ? "Live Activities разрешены системой."
                        : "Разреши Live Activities в настройках iPhone, чтобы Felix появился наверху.")
                    .font(.subheadline)
                    .foregroundStyle(felixIslandManager.areActivitiesAuthorized ? .secondary : palette.accent)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Task {
                        if felixIslandManager.isFeatureEnabled {
                            await felixIslandManager.disable()
                        } else {
                            await felixIslandManager.enable(
                                snapshot: snapshot,
                                hasPremiumAccess: premiumAccess.hasPremiumAccess
                            )
                        }
                    }
                } label: {
                    Text(felixIslandManager.isFeatureEnabled ? "Выключить Felix Island" : "Включить Felix Island")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(palette.floatingButtonForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(premiumAccess.hasPremiumAccess ? palette.floatingButton : palette.elevatedSurface)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!premiumAccess.hasPremiumAccess)
            }
        }
    }

    private func statusPill(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(palette.accentSoft)
            )
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { newValue in
                if !newValue {
                    errorMessage = nil
                }
            }
        )
    }
}
