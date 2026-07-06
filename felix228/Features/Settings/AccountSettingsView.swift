//
//  AccountSettingsView.swift
//  felix228
//
//  Created by Codex on 13.05.2026.
//

import AuthenticationServices
import SwiftData
import SwiftUI

struct AccountSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var cloudAccount: CloudAccountManager
    @EnvironmentObject private var achievementManager: AchievementManager

    @State private var errorMessage: String?
    @State private var isShowingDeleteAccountDialog = false

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    private var isBusy: Bool {
        cloudAccount.isAuthenticating || cloudAccount.isSyncing
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView(palette: palette)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        StatisticsSectionCard(
                            palette: palette,
                            title: cloudAccount.accountStatusTitle,
                            subtitle: cloudAccount.accountStatusDetail
                        ) {
                            VStack(alignment: .leading, spacing: 14) {
                                Label(
                                    cloudAccount.isSignedIn
                                        ? (cloudAccount.userEmail ?? cloudAccount.userDisplayName ?? "Аккаунт готов")
                                        : "Локальные данные всё равно продолжают храниться на телефоне",
                                    systemImage: cloudAccount.isSignedIn ? "checkmark.circle.fill" : "iphone"
                                )
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(cloudAccount.isSignedIn ? palette.accent : .primary)

                                if let statusMessage = cloudAccount.statusMessage {
                                    Text(statusMessage)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }

                        if let blockerTitle = cloudAccount.primaryBlockerTitle,
                           let blockerDetail = cloudAccount.primaryBlockerDetail {
                            StatisticsSectionCard(
                                palette: palette,
                                title: blockerTitle,
                                subtitle: blockerDetail
                            ) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                            .padding(.top, 2)

                                        Text("Сейчас дело не в логике приложения, а в недостающей конфигурации Firebase. Как только добавим её, вход и синхронизация смогут заработать по-настоящему.")
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }

                        if !cloudAccount.isSignedIn {
                            StatisticsSectionCard(
                                palette: palette,
                                title: "Создать или открыть аккаунт",
                                subtitle: "После входа можно хранить заметки и цели не только на этом iPhone, но и в своём аккаунте."
                            ) {
                                VStack(spacing: 12) {
                                    Button {
                                        Task {
                                            await runGoogleSignIn()
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "g.circle.fill")
                                                .font(.title3.weight(.bold))

                                            Text("Войти через Google")
                                                .font(.headline.weight(.semibold))

                                            Spacer()
                                        }
                                        .foregroundStyle(palette.floatingButtonForeground)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                                .fill(
                                                    cloudAccount.canStartGoogleSignIn
                                                        ? palette.floatingButton
                                                        : palette.stroke
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isBusy || !cloudAccount.canStartGoogleSignIn)

                                    SignInWithAppleButton(.signIn) { request in
                                        cloudAccount.prepareAppleSignInRequest(request)
                                    } onCompletion: { result in
                                        Task {
                                            await runAppleSignIn(result)
                                        }
                                    }
                                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                                    .frame(height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                    .disabled(isBusy || !cloudAccount.canStartAppleSignIn)

                                    if let blockerDetail = cloudAccount.primaryBlockerDetail {
                                        Text(blockerDetail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }

                        if !cloudAccount.setupChecklist.isEmpty {
                            StatisticsSectionCard(
                                palette: palette,
                                title: "Что нужно для облачного аккаунта",
                                subtitle: "Если какой-то пункт ещё не выполнен, вход и синхронизация могут не завершиться."
                            ) {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(Array(cloudAccount.setupChecklist.enumerated()), id: \.offset) { _, item in
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: "checkmark.seal.fill")
                                                .foregroundStyle(palette.accent)
                                                .padding(.top, 2)

                                            Text(item)
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                            }
                        }

                        if cloudAccount.isSignedIn {
                            StatisticsSectionCard(
                                palette: palette,
                                title: "Синхронизация",
                                subtitle: "Отправка сохранит текущие записи, цели и занятия в аккаунт. Загрузка подтянет данные из аккаунта обратно на этот телефон."
                            ) {
                                VStack(spacing: 12) {
                                    Button {
                                        Task {
                                            await runCloudUpload()
                                        }
                                    } label: {
                                        syncButtonLabel(
                                            title: cloudAccount.isSyncing ? "Сохраняем..." : "Сохранить в аккаунт",
                                            icon: "icloud.and.arrow.up.fill"
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isBusy)

                                    Button {
                                        Task {
                                            await runCloudRestore()
                                        }
                                    } label: {
                                        syncButtonLabel(
                                            title: cloudAccount.isSyncing ? "Загружаем..." : "Загрузить из аккаунта",
                                            icon: "icloud.and.arrow.down.fill"
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isBusy)

                                    Text("Загрузка заменит локальные записи данными из аккаунта, поэтому её лучше нажимать, когда уверена, что в облаке лежит нужная версия дневника.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }

                            StatisticsSectionCard(
                                palette: palette,
                                title: "Аккаунт",
                                subtitle: "Можно просто выйти или полностью удалить облачный аккаунт. Локальный дневник на телефоне при этом останется."
                            ) {
                                VStack(spacing: 12) {
                                    Button(role: .destructive) {
                                        runSignOut()
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                                .font(.headline.weight(.semibold))

                                            Text("Выйти из аккаунта")
                                                .font(.headline.weight(.semibold))

                                            Spacer()
                                        }
                                        .foregroundStyle(.red.opacity(0.92))
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                                .fill(palette.surface)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                                .stroke(Color.red.opacity(0.18), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isBusy)

                                    Button(role: .destructive) {
                                        isShowingDeleteAccountDialog = true
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "trash.fill")
                                                .font(.headline.weight(.semibold))

                                            Text("Удалить аккаунт")
                                                .font(.headline.weight(.semibold))

                                            Spacer()
                                        }
                                        .foregroundStyle(.red.opacity(0.92))
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                                .fill(Color.red.opacity(0.10))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                                .stroke(Color.red.opacity(0.22), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isBusy)

                                    Text("Удаление сотрёт облачные данные и Firebase-аккаунт, но не тронет заметки, которые уже лежат локально на этом iPhone.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 140)
                }
            }
            .navigationTitle("Аккаунт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .alert("Не удалось выполнить действие", isPresented: isShowingError) {
                Button("Ок", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Попробуй ещё раз.")
            }
            .confirmationDialog(
                "Удалить аккаунт?",
                isPresented: $isShowingDeleteAccountDialog,
                titleVisibility: .visible
            ) {
                Button("Удалить аккаунт", role: .destructive) {
                    Task {
                        await runDeleteAccount()
                    }
                }

                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Будут удалены вход, облачные данные и профиль Firebase. Локальный дневник на этом iPhone останется.")
            }
        }
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { shouldShow in
                if !shouldShow {
                    errorMessage = nil
                }
            }
        )
    }

    @ViewBuilder
    private func syncButtonLabel(title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline.weight(.semibold))

            Text(title)
                .font(.headline.weight(.semibold))

            Spacer()
        }
        .foregroundStyle(palette.floatingButtonForeground)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.floatingButton)
        )
    }

    private func runGoogleSignIn() async {
        do {
            try await cloudAccount.signInWithGoogle(
                using: modelContext,
                achievementManager: achievementManager
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        do {
            try await cloudAccount.handleAppleSignInResult(
                result,
                using: modelContext,
                achievementManager: achievementManager
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runCloudUpload() async {
        do {
            try await cloudAccount.uploadLocalData(
                using: modelContext,
                achievementManager: achievementManager
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runCloudRestore() async {
        do {
            try await cloudAccount.restoreCloudData(
                using: modelContext,
                achievementManager: achievementManager
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runSignOut() {
        do {
            try cloudAccount.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runDeleteAccount() async {
        do {
            try await cloudAccount.deleteAccountAndCloudData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
