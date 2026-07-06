//
//  CloudAccountManager.swift
//  felix228
//
//  Created by Codex on 13.05.2026.
//

import AuthenticationServices
import Combine
import CryptoKit
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn
import Security
import SwiftData
import SwiftUI
import UIKit

enum CloudSyncDirection: String {
    case upload
    case download
}

@MainActor
final class CloudAccountManager: ObservableObject {
    @Published private(set) var userID: String?
    @Published private(set) var userEmail: String?
    @Published private(set) var userDisplayName: String?
    @Published private(set) var isFirebaseConfigured = false
    @Published private(set) var hasGoogleURLScheme = false
    @Published private(set) var isAuthenticating = false
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var lastSyncDirection: CloudSyncDirection?
    @Published private(set) var statusMessage: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    private var pendingUploadTask: Task<Void, Never>?

    private static let lastSyncDateKey = "cloudLastSyncDate"
    private static let lastSyncDirectionKey = "cloudLastSyncDirection"

    private enum CollectionName {
        static let entries = "entries"
        static let goals = "goals"
        static let activities = "activities"
        static let achievements = "achievements"
    }

    init() {
        Self.configureFirebaseIfPossible()
        restoreSyncState()
        refreshConfigurationState()
        attachAuthListenerIfNeeded()
    }

    var isSignedIn: Bool {
        userID != nil
    }

    var accountRowText: String {
        if let userEmail, !userEmail.isEmpty {
            return userEmail
        }

        if let userDisplayName, !userDisplayName.isEmpty {
            return userDisplayName
        }

        let language = AppLanguage.current()
        return isFirebaseConfigured
            ? language.localized("Войти", "Увійти", "Sign in")
            : language.localized("Настроить", "Налаштувати", "Set up")
    }

    var accountStatusTitle: String {
        if isSignedIn {
            return "Аккаунт подключён"
        }

        if !isFirebaseConfigured {
            return "Firebase пока не настроен"
        }

        if !isFirebaseConfigMatchingCurrentApp {
            return "Firebase подключён не для этого приложения"
        }

        if !hasGoogleClientIDConfigured || !hasGoogleReversedClientIDConfigured {
            return "Firebase-конфиг неполный"
        }

        return "Вход ещё не выполнен"
    }

    var accountStatusDetail: String {
        if let lastSyncDate {
            let dateString = Self.syncFormatter.string(from: lastSyncDate)
            switch lastSyncDirection {
            case .upload:
                return "Последняя отправка в аккаунт была \(dateString)."
            case .download:
                return "Последняя загрузка из аккаунта была \(dateString)."
            case .none:
                return "Аккаунт готов к синхронизации."
            }
        }

        if isSignedIn {
            return "После входа заметки, цели и занятия можно сохранять в аккаунт и подтягивать обратно на телефон."
        }

        if let appBundleID, let firebaseBundleID = firebaseConfigBundleID, firebaseBundleID != appBundleID {
            return "Сейчас в проекте лежит Firebase-конфиг для `\(firebaseBundleID)`, а приложение собрано как `\(appBundleID)`. Нужен plist именно от этого iOS-приложения."
        }

        if !hasGoogleClientIDConfigured {
            return "Firebase уже виден приложению, но в этом plist нет `CLIENT_ID`, поэтому Google-вход ещё не получится открыть."
        }

        if !hasGoogleReversedClientIDConfigured {
            return "Firebase уже виден приложению, но в этом plist нет `REVERSED_CLIENT_ID`, поэтому Google-вход не сможет вернуться обратно в приложение."
        }

        if isFirebaseConfigured {
            return "Войди через Google или Apple, и мы сможем хранить записи не только на устройстве, но и в аккаунте."
        }

        return "Нужен Firebase-конфиг приложения, чтобы включить Google и Apple аутентификацию."
    }

    var primaryBlockerTitle: String? {
        if !Self.hasGoogleServiceInfoPlist {
            return "Регистрация ещё не активирована"
        }

        if !isFirebaseConfigMatchingCurrentApp {
            return "Нужен Firebase-конфиг именно для этого приложения"
        }

        if !hasGoogleClientIDConfigured {
            return "Google-вход ещё не настроен до конца"
        }

        if !hasGoogleReversedClientIDConfigured {
            return "В Firebase-конфиге не хватает URL scheme"
        }

        if !hasGoogleURLScheme {
            return "Нужно завершить настройку Google-входа"
        }

        return nil
    }

    var primaryBlockerDetail: String? {
        if !Self.hasGoogleServiceInfoPlist {
            return "В проекте ещё нет `GoogleService-Info.plist`, поэтому Firebase не может создать и открыть аккаунт."
        }

        if let appBundleID, let firebaseBundleID = firebaseConfigBundleID, firebaseBundleID != appBundleID {
            return "В добавленном `GoogleService-Info.plist` указан bundle id `\(firebaseBundleID)`, а у приложения сейчас `\(appBundleID)`. Нужен plist, скачанный именно для этого iOS app в Firebase."
        }

        if !hasGoogleClientIDConfigured {
            return "В этом `GoogleService-Info.plist` нет `CLIENT_ID`. Обычно так бывает, когда скачан не тот iOS-конфиг из Firebase."
        }

        if !hasGoogleReversedClientIDConfigured {
            return "В этом `GoogleService-Info.plist` нет `REVERSED_CLIENT_ID`, поэтому Google-входу нечем вернуться обратно в приложение."
        }

        if !hasGoogleURLScheme, let reversedClientID = googleReversedClientID {
            return "Осталось добавить URL scheme `\(reversedClientID)` в target, и Google-вход сможет вернуть пользователя обратно в приложение."
        }

        if !hasGoogleURLScheme {
            return "Осталось добавить URL scheme из Firebase-конфига в настройки target."
        }

        return nil
    }

    var setupChecklist: [String] {
        var checklist: [String] = []

        if !Self.hasGoogleServiceInfoPlist {
            checklist.append("Добавь `GoogleService-Info.plist` из Firebase Console в target приложения.")
        } else if let appBundleID, let firebaseBundleID = firebaseConfigBundleID, firebaseBundleID != appBundleID {
            checklist.append("Пересоздай или заново скачай `GoogleService-Info.plist` для iOS app с bundle id `\(appBundleID)`.")
        } else if !hasGoogleClientIDConfigured {
            checklist.append("Скачай свежий `GoogleService-Info.plist` именно из iOS app в Firebase: в нём должен быть ключ `CLIENT_ID`.")
        } else if !hasGoogleReversedClientIDConfigured {
            checklist.append("Скачай свежий `GoogleService-Info.plist` из Firebase: в нём должен быть ключ `REVERSED_CLIENT_ID` для Google-входа.")
        } else if !hasGoogleURLScheme, let reversedClientID = googleReversedClientID {
            checklist.append("Добавь URL scheme `\(reversedClientID)` в настройки target, чтобы Google-вход мог вернуть пользователя обратно в приложение.")
        }

        checklist.append("В Firebase Console включи провайдеры `Google` и `Apple` для Authentication.")
        checklist.append("После этого можно войти и хранить заметки ещё и в облачном аккаунте.")

        return checklist
    }

    var canStartGoogleSignIn: Bool {
        isFirebaseConfigured
            && isFirebaseConfigMatchingCurrentApp
            && hasGoogleClientIDConfigured
            && hasGoogleReversedClientIDConfigured
            && hasGoogleURLScheme
    }

    var canStartAppleSignIn: Bool {
        isFirebaseConfigured && isFirebaseConfigMatchingCurrentApp
    }

    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func signInWithGoogle(
        using modelContext: ModelContext,
        achievementManager: AchievementManager
    ) async throws {
        guard isFirebaseConfigured else {
            throw CloudAccountError.missingFirebaseConfiguration
        }

        guard isFirebaseConfigMatchingCurrentApp else {
            throw CloudAccountError.firebaseConfigurationBundleIDMismatch(
                appBundleID: appBundleID,
                configBundleID: firebaseConfigBundleID
            )
        }

        guard hasGoogleReversedClientIDConfigured else {
            throw CloudAccountError.missingGoogleReversedClientID
        }

        guard hasGoogleURLScheme else {
            throw CloudAccountError.missingGoogleURLScheme(expectedScheme: googleReversedClientID)
        }

        guard let clientID = firebaseClientID else {
            throw CloudAccountError.missingGoogleClientID
        }

        guard let presentingController = UIApplication.topMostViewController() else {
            throw CloudAccountError.missingPresentingController
        }

        statusMessage = nil
        isAuthenticating = true
        defer { isAuthenticating = false }

        let configuration = GIDConfiguration(clientID: clientID)
        let result = try await signInToGoogle(with: configuration, presenting: presentingController)

        guard let idToken = result.user.idToken?.tokenString else {
            throw CloudAccountError.missingGoogleIdentityToken
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )

        _ = try await signInToFirebase(with: credential)
        try await uploadLocalData(
            using: modelContext,
            achievementManager: achievementManager,
            successMessage: "Аккаунт подключён, а текущие записи уже сохранены в облако."
        )
    }

    func handleAppleSignInResult(
        _ result: Result<ASAuthorization, Error>,
        using modelContext: ModelContext,
        achievementManager: AchievementManager
    ) async throws {
        guard isFirebaseConfigured else {
            throw CloudAccountError.missingFirebaseConfiguration
        }

        guard isFirebaseConfigMatchingCurrentApp else {
            throw CloudAccountError.firebaseConfigurationBundleIDMismatch(
                appBundleID: appBundleID,
                configBundleID: firebaseConfigBundleID
            )
        }

        statusMessage = nil
        isAuthenticating = true
        defer { isAuthenticating = false }

        switch result {
        case .failure(let error):
            throw error

        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw CloudAccountError.invalidAppleCredential
            }

            guard let nonce = currentNonce else {
                throw CloudAccountError.missingAppleNonce
            }

            guard
                let identityToken = appleIDCredential.identityToken,
                let idTokenString = String(data: identityToken, encoding: .utf8)
            else {
                throw CloudAccountError.missingAppleIdentityToken
            }

            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )

            _ = try await signInToFirebase(with: credential)
            try await uploadLocalData(
                using: modelContext,
                achievementManager: achievementManager,
                successMessage: "Аккаунт подключён через Apple, а локальные данные уже сохранены в облако."
            )
        }
    }

    func uploadLocalData(
        using modelContext: ModelContext,
        achievementManager: AchievementManager,
        successMessage: String? = "Изменения сохранены в аккаунт."
    ) async throws {
        guard let firestore = firestore else {
            throw CloudAccountError.missingFirebaseConfiguration
        }

        guard let userID else {
            throw CloudAccountError.notSignedIn
        }

        isSyncing = true
        defer { isSyncing = false }

        let snapshot = try buildLocalSnapshot(using: modelContext, achievementManager: achievementManager)
        let userDocument = firestore.collection("users").document(userID)

        try await syncCollection(
            snapshot.achievements.map(\.documentPayload),
            in: userDocument.collection(CollectionName.achievements),
            firestore: firestore
        )
        try await syncCollection(
            snapshot.activities.map(\.documentPayload),
            in: userDocument.collection(CollectionName.activities),
            firestore: firestore
        )
        try await syncCollection(
            snapshot.goals.map(\.documentPayload),
            in: userDocument.collection(CollectionName.goals),
            firestore: firestore
        )
        try await syncCollection(
            snapshot.entries.map(\.documentPayload),
            in: userDocument.collection(CollectionName.entries),
            firestore: firestore
        )

        let profilePayload: [String: Any] = [
            "displayName": userDisplayName ?? NSNull(),
            "email": userEmail ?? NSNull(),
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        try await setData(profilePayload, on: userDocument, merge: true)

        registerSync(direction: .upload, message: successMessage)
    }

    func restoreCloudData(
        using modelContext: ModelContext,
        achievementManager: AchievementManager
    ) async throws {
        guard let firestore = firestore else {
            throw CloudAccountError.missingFirebaseConfiguration
        }

        guard let userID else {
            throw CloudAccountError.notSignedIn
        }

        isSyncing = true
        defer { isSyncing = false }

        let userDocument = firestore.collection("users").document(userID)
        let remoteAchievements = try await fetchAchievements(from: userDocument.collection(CollectionName.achievements))
        let remoteActivities = try await fetchActivities(from: userDocument.collection(CollectionName.activities))
        let remoteGoals = try await fetchGoals(from: userDocument.collection(CollectionName.goals))
        let remoteEntries = try await fetchEntries(from: userDocument.collection(CollectionName.entries))

        guard !remoteAchievements.isEmpty || !remoteActivities.isEmpty || !remoteGoals.isEmpty || !remoteEntries.isEmpty else {
            throw CloudAccountError.emptyCloudState
        }

        let localEntries = try modelContext.fetch(FetchDescriptor<EmotionEntry>())
        let localGoals = try modelContext.fetch(FetchDescriptor<DailyGoal>())
        let localActivities = try modelContext.fetch(FetchDescriptor<ActivityOption>())

        for entry in localEntries {
            modelContext.delete(entry)
        }

        for goal in localGoals {
            modelContext.delete(goal)
        }

        for activity in localActivities {
            modelContext.delete(activity)
        }

        for activity in remoteActivities.sorted(by: { $0.createdAt < $1.createdAt }) {
            modelContext.insert(
                ActivityOption(
                    syncID: activity.id,
                    createdAt: activity.createdAt,
                    title: activity.title,
                    symbolName: activity.symbolName
                )
            )
        }

        for goal in remoteGoals.sorted(by: { $0.createdAt < $1.createdAt }) {
            modelContext.insert(
                DailyGoal(
                    syncID: goal.id,
                    createdAt: goal.createdAt,
                    title: goal.title,
                    lastCompletedAt: goal.lastCompletedAt,
                    completionHistory: goal.completionHistory
                )
            )
        }

        for entry in remoteEntries.sorted(by: { $0.createdAt > $1.createdAt }) {
            modelContext.insert(
                EmotionEntry(
                    syncID: entry.id,
                    createdAt: entry.createdAt,
                    mood: Mood(storageValue: entry.moodID),
                    intensity: entry.intensity,
                    trigger: entry.trigger,
                    note: entry.note,
                    activitySnapshots: entry.activities
                )
            )
        }

        if !remoteAchievements.isEmpty {
            achievementManager.replaceUnlockedDates(
                fromTimestamps: Dictionary(
                    uniqueKeysWithValues: remoteAchievements.map { achievement in
                        (achievement.id, achievement.unlockedAt.timeIntervalSince1970)
                    }
                )
            )
        }

        try modelContext.save()
        registerSync(direction: .download, message: "Данные из аккаунта загружены на телефон.")
    }

    func signOut() throws {
        guard isFirebaseConfigured else { return }

        pendingUploadTask?.cancel()
        pendingUploadTask = nil
        statusMessage = "Аккаунт отключён."

        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
    }

    func deleteAccountAndCloudData() async throws {
        guard let firestore else {
            throw CloudAccountError.missingFirebaseConfiguration
        }

        guard let userID else {
            throw CloudAccountError.notSignedIn
        }

        guard let authenticatedUser = Auth.auth().currentUser else {
            throw CloudAccountError.missingAuthenticatedUser
        }

        pendingUploadTask?.cancel()
        pendingUploadTask = nil
        statusMessage = nil
        isSyncing = true
        defer { isSyncing = false }

        let userDocument = firestore.collection("users").document(userID)

        try await deleteCollection(
            at: userDocument.collection(CollectionName.achievements),
            firestore: firestore
        )
        try await deleteCollection(
            at: userDocument.collection(CollectionName.activities),
            firestore: firestore
        )
        try await deleteCollection(
            at: userDocument.collection(CollectionName.goals),
            firestore: firestore
        )
        try await deleteCollection(
            at: userDocument.collection(CollectionName.entries),
            firestore: firestore
        )
        try await deleteDocument(userDocument)
        try await deleteFirebaseUser(authenticatedUser)

        GIDSignIn.sharedInstance.signOut()
        clearSyncState()
        updateSignedInUser(nil)
        statusMessage = "Аккаунт и облачные данные удалены. Локальный дневник на этом iPhone остался."
    }

    func scheduleAutoBackup(
        using modelContext: ModelContext,
        achievementManager: AchievementManager
    ) {
        guard isSignedIn else { return }

        pendingUploadTask?.cancel()
        pendingUploadTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                try await self.uploadLocalData(
                    using: modelContext,
                    achievementManager: achievementManager,
                    successMessage: nil
                )
            } catch is CancellationError {
                return
            } catch {
                self.statusMessage = "Автосинхронизация не дошла до облака: \(error.localizedDescription)"
            }
        }
    }

    static func configureFirebaseIfPossible() {
        guard FirebaseApp.app() == nil else { return }
        guard hasGoogleServiceInfoPlist else { return }
        FirebaseApp.configure()
    }

    private var firestore: Firestore? {
        guard isFirebaseConfigured else { return nil }
        return Firestore.firestore()
    }

    private var appBundleID: String? {
        Self.nonEmptyString(Bundle.main.bundleIdentifier)
    }

    private var firebaseConfigBundleID: String? {
        Self.nonEmptyString(Self.googleServiceInfoValue(forKey: "BUNDLE_ID") as? String)
    }

    private var isFirebaseConfigMatchingCurrentApp: Bool {
        guard Self.hasGoogleServiceInfoPlist else { return false }
        guard let appBundleID, let firebaseBundleID = firebaseConfigBundleID else { return false }
        return appBundleID == firebaseBundleID
    }

    private var firebaseClientID: String? {
        Self.nonEmptyString(FirebaseApp.app()?.options.clientID)
            ?? Self.nonEmptyString(Self.googleServiceInfoValue(forKey: "CLIENT_ID") as? String)
    }

    private var googleReversedClientID: String? {
        Self.nonEmptyString(Self.googleServiceInfoValue(forKey: "REVERSED_CLIENT_ID") as? String)
    }

    private var hasGoogleClientIDConfigured: Bool {
        firebaseClientID != nil
    }

    private var hasGoogleReversedClientIDConfigured: Bool {
        googleReversedClientID != nil
    }

    private func attachAuthListenerIfNeeded() {
        guard isFirebaseConfigured, authStateHandle == nil else { return }

        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.updateSignedInUser(user)
            }
        }
    }

    private func refreshConfigurationState() {
        isFirebaseConfigured = FirebaseApp.app() != nil
        hasGoogleURLScheme = Self.isRegisteredURLScheme(googleReversedClientID)

        if !isFirebaseConfigured {
            updateSignedInUser(nil)
        }
    }

    private func restoreSyncState() {
        lastSyncDate = UserDefaults.standard.object(forKey: Self.lastSyncDateKey) as? Date

        if
            let rawDirection = UserDefaults.standard.string(forKey: Self.lastSyncDirectionKey),
            let direction = CloudSyncDirection(rawValue: rawDirection)
        {
            lastSyncDirection = direction
        }
    }

    private func registerSync(direction: CloudSyncDirection, message: String?) {
        let now = Date()
        lastSyncDate = now
        lastSyncDirection = direction
        statusMessage = message

        UserDefaults.standard.set(now, forKey: Self.lastSyncDateKey)
        UserDefaults.standard.set(direction.rawValue, forKey: Self.lastSyncDirectionKey)
    }

    private func clearSyncState() {
        lastSyncDate = nil
        lastSyncDirection = nil
        UserDefaults.standard.removeObject(forKey: Self.lastSyncDateKey)
        UserDefaults.standard.removeObject(forKey: Self.lastSyncDirectionKey)
    }

    private func updateSignedInUser(_ user: User?) {
        userID = user?.uid
        userEmail = user?.email
        userDisplayName = user?.displayName
    }

    private func buildLocalSnapshot(
        using modelContext: ModelContext,
        achievementManager: AchievementManager
    ) throws -> LocalSnapshot {
        let entries = try modelContext.fetch(
            FetchDescriptor<EmotionEntry>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        )
        let goals = try modelContext.fetch(
            FetchDescriptor<DailyGoal>(
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
        )
        let activities = try modelContext.fetch(
            FetchDescriptor<ActivityOption>(
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
        )
        let achievementRecords = achievementManager.exportedUnlockedDateTimestamps.compactMap { rawValue, timestamp in
            CloudAchievementRecord(
                id: rawValue,
                unlockedAt: Date(timeIntervalSince1970: timestamp)
            )
        }

        var didMutateLocalState = false

        let activityRecords = activities.map { activity in
            if activity.lookupKey != ActivityOption.makeLookupKey(activity.title) {
                activity.lookupKey = ActivityOption.makeLookupKey(activity.title)
                didMutateLocalState = true
            }

            return CloudActivityRecord(
                id: ensureSyncID(for: activity, didMutate: &didMutateLocalState),
                createdAt: activity.createdAt,
                title: activity.title,
                symbolName: activity.symbolName
            )
        }

        let goalRecords = goals.map { goal in
            CloudGoalRecord(
                id: ensureSyncID(for: goal, didMutate: &didMutateLocalState),
                createdAt: goal.createdAt,
                title: goal.title,
                lastCompletedAt: goal.lastCompletedAt,
                completionHistory: goal.completionHistory
            )
        }

        let entryRecords = entries.map { entry in
            CloudEntryRecord(
                id: ensureSyncID(for: entry, didMutate: &didMutateLocalState),
                createdAt: entry.createdAt,
                moodID: entry.moodID,
                intensity: entry.intensity,
                trigger: entry.trigger,
                note: entry.note,
                activities: entry.activitySnapshots
            )
        }

        if didMutateLocalState {
            try modelContext.save()
        }

        return LocalSnapshot(
            achievements: achievementRecords,
            activities: activityRecords,
            goals: goalRecords,
            entries: entryRecords
        )
    }

    private func ensureSyncID(
        for entry: EmotionEntry,
        didMutate: inout Bool
    ) -> String {
        if let normalized = Self.normalizedSyncID(entry.syncID) {
            entry.syncID = normalized
            return normalized
        }

        let identifier = UUID().uuidString
        entry.syncID = identifier
        didMutate = true
        return identifier
    }

    private func ensureSyncID(
        for goal: DailyGoal,
        didMutate: inout Bool
    ) -> String {
        if let normalized = Self.normalizedSyncID(goal.syncID) {
            goal.syncID = normalized
            return normalized
        }

        let identifier = UUID().uuidString
        goal.syncID = identifier
        didMutate = true
        return identifier
    }

    private func ensureSyncID(
        for activity: ActivityOption,
        didMutate: inout Bool
    ) -> String {
        if let normalized = Self.normalizedSyncID(activity.syncID) {
            activity.syncID = normalized
            return normalized
        }

        let identifier = UUID().uuidString
        activity.syncID = identifier
        didMutate = true
        return identifier
    }

    private func syncCollection(
        _ payloads: [CloudDocumentPayload],
        in collection: CollectionReference,
        firestore: Firestore
    ) async throws {
        let snapshot = try await getDocuments(from: collection)
        let localIDs = Set(payloads.map(\.id))

        var operations: [FirestoreBatchOperation] = payloads.map {
            .set(document: collection.document($0.id), data: $0.data)
        }

        for document in snapshot.documents where !localIDs.contains(document.documentID) {
            operations.append(.delete(document: document.reference))
        }

        try await commit(operations: operations, in: firestore)
    }

    private func fetchActivities(from collection: CollectionReference) async throws -> [CloudActivityRecord] {
        let snapshot = try await getDocuments(from: collection)
        return snapshot.documents.compactMap(CloudActivityRecord.init)
    }

    private func fetchAchievements(from collection: CollectionReference) async throws -> [CloudAchievementRecord] {
        let snapshot = try await getDocuments(from: collection)
        return snapshot.documents.compactMap(CloudAchievementRecord.init)
    }

    private func fetchGoals(from collection: CollectionReference) async throws -> [CloudGoalRecord] {
        let snapshot = try await getDocuments(from: collection)
        return snapshot.documents.compactMap(CloudGoalRecord.init)
    }

    private func fetchEntries(from collection: CollectionReference) async throws -> [CloudEntryRecord] {
        let snapshot = try await getDocuments(from: collection)
        return snapshot.documents.compactMap(CloudEntryRecord.init)
    }

    private func signInToGoogle(
        with configuration: GIDConfiguration,
        presenting presentingController: UIViewController
    ) async throws -> GIDSignInResult {
        try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.configuration = configuration
            GIDSignIn.sharedInstance.signIn(withPresenting: presentingController) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: CloudAccountError.googleFlowReturnedNoResult)
                }
            }
        }
    }

    private func signInToFirebase(with credential: AuthCredential) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signIn(with: credential) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: CloudAccountError.firebaseAuthReturnedNoResult)
                }
            }
        }
    }

    private func getDocuments(from collection: CollectionReference) async throws -> QuerySnapshot {
        try await withCheckedThrowingContinuation { continuation in
            collection.getDocuments { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: CloudAccountError.cloudRequestReturnedNoData)
                }
            }
        }
    }

    private func deleteCollection(
        at collection: CollectionReference,
        firestore: Firestore
    ) async throws {
        let snapshot = try await getDocuments(from: collection)
        let operations = snapshot.documents.map { FirestoreBatchOperation.delete(document: $0.reference) }
        try await commit(operations: operations, in: firestore)
    }

    private func deleteDocument(_ document: DocumentReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            document.delete { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func deleteFirebaseUser(_ user: User) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            user.delete { error in
                if let nsError = error as NSError? {
                    if AuthErrorCode(rawValue: nsError.code) == .requiresRecentLogin {
                        continuation.resume(
                            throwing: CloudAccountError.requiresRecentReauthenticationForAccountDeletion
                        )
                    } else {
                        continuation.resume(throwing: nsError)
                    }
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func setData(
        _ data: [String: Any],
        on document: DocumentReference,
        merge: Bool
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            document.setData(data, merge: merge) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func commit(
        operations: [FirestoreBatchOperation],
        in firestore: Firestore
    ) async throws {
        guard !operations.isEmpty else { return }

        var startIndex = 0
        while startIndex < operations.count {
            let batch = firestore.batch()
            let endIndex = min(startIndex + 400, operations.count)

            for operation in operations[startIndex..<endIndex] {
                switch operation {
                case .set(let document, let data):
                    batch.setData(data, forDocument: document, merge: true)
                case .delete(let document):
                    batch.deleteDocument(document)
                }
            }

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                batch.commit { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }

            startIndex = endIndex
        }
    }

    private static var hasGoogleServiceInfoPlist: Bool {
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }

    private static func googleServiceInfoValue(forKey key: String) -> Any? {
        guard
            let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
            let dictionary = NSDictionary(contentsOfFile: path) as? [String: Any]
        else {
            return nil
        }

        return dictionary[key]
    }

    private static func nonEmptyString(_ candidate: String?) -> String? {
        guard let candidate else { return nil }
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedSyncID(_ candidate: String?) -> String? {
        guard let candidate else { return nil }
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func isRegisteredURLScheme(_ scheme: String?) -> Bool {
        guard let scheme = scheme?.lowercased(), !scheme.isEmpty else { return false }

        let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        let schemes = urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        return schemes.contains { $0.lowercased() == scheme }
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            for random in randoms {
                if remainingLength == 0 {
                    continue
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    private static let syncFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct LocalSnapshot {
    let achievements: [CloudAchievementRecord]
    let activities: [CloudActivityRecord]
    let goals: [CloudGoalRecord]
    let entries: [CloudEntryRecord]
}

private struct CloudDocumentPayload {
    let id: String
    let data: [String: Any]
}

private enum FirestoreBatchOperation {
    case set(document: DocumentReference, data: [String: Any])
    case delete(document: DocumentReference)
}

private struct CloudAchievementRecord {
    let id: String
    let unlockedAt: Date

    init(
        id: String,
        unlockedAt: Date
    ) {
        self.id = id
        self.unlockedAt = unlockedAt
    }

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard let unlockedAt = CloudRecordParsing.date(from: data["unlockedAt"]) else {
            return nil
        }

        self.id = document.documentID
        self.unlockedAt = unlockedAt
    }

    var documentPayload: CloudDocumentPayload {
        CloudDocumentPayload(
            id: id,
            data: [
                "unlockedAt": Timestamp(date: unlockedAt),
            ]
        )
    }
}

private struct CloudActivityRecord {
    let id: String
    let createdAt: Date
    let title: String
    let symbolName: String

    init(
        id: String,
        createdAt: Date,
        title: String,
        symbolName: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.symbolName = symbolName
    }

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard
            let createdAt = CloudRecordParsing.date(from: data["createdAt"]),
            let title = data["title"] as? String,
            let symbolName = data["symbolName"] as? String
        else {
            return nil
        }

        self.id = document.documentID
        self.createdAt = createdAt
        self.title = title
        self.symbolName = symbolName
    }

    var documentPayload: CloudDocumentPayload {
        CloudDocumentPayload(
            id: id,
            data: [
                "createdAt": Timestamp(date: createdAt),
                "title": title,
                "symbolName": symbolName,
            ]
        )
    }
}

private struct CloudGoalRecord {
    let id: String
    let createdAt: Date
    let title: String
    let lastCompletedAt: Date?
    let completionHistory: [Date]

    init(
        id: String,
        createdAt: Date,
        title: String,
        lastCompletedAt: Date?,
        completionHistory: [Date]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.lastCompletedAt = lastCompletedAt
        self.completionHistory = Self.normalizedCompletionHistory(
            from: completionHistory,
            fallbackLastCompletedAt: lastCompletedAt
        )
    }

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard
            let createdAt = CloudRecordParsing.date(from: data["createdAt"]),
            let title = data["title"] as? String
        else {
            return nil
        }

        self.id = document.documentID
        self.createdAt = createdAt
        self.title = title
        self.lastCompletedAt = CloudRecordParsing.date(from: data["lastCompletedAt"])
        self.completionHistory = Self.normalizedCompletionHistory(
            from: CloudRecordParsing.dates(from: data["completionHistory"]),
            fallbackLastCompletedAt: self.lastCompletedAt
        )
    }

    var documentPayload: CloudDocumentPayload {
        CloudDocumentPayload(
            id: id,
            data: [
                "createdAt": Timestamp(date: createdAt),
                "title": title,
                "lastCompletedAt": lastCompletedAt.map(Timestamp.init(date:)) ?? NSNull(),
                "completionHistory": completionHistory.map(Timestamp.init(date:)),
            ]
        )
    }

    private static func normalizedCompletionHistory(
        from dates: [Date],
        fallbackLastCompletedAt: Date?
    ) -> [Date] {
        var uniqueDays: [Date] = []
        var seenTimestamps = Set<TimeInterval>()

        for date in dates + [fallbackLastCompletedAt].compactMap({ $0 }) {
            let normalizedDate = Calendar.current.startOfDay(for: date)
            let timestamp = normalizedDate.timeIntervalSinceReferenceDate

            if seenTimestamps.insert(timestamp).inserted {
                uniqueDays.append(normalizedDate)
            }
        }

        return uniqueDays.sorted()
    }
}

private struct CloudEntryRecord {
    let id: String
    let createdAt: Date
    let moodID: String
    let intensity: Double
    let trigger: String
    let note: String
    let activities: [EntryActivitySnapshot]

    init(
        id: String,
        createdAt: Date,
        moodID: String,
        intensity: Double,
        trigger: String,
        note: String,
        activities: [EntryActivitySnapshot]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.moodID = moodID
        self.intensity = intensity
        self.trigger = trigger
        self.note = note
        self.activities = activities
    }

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard
            let createdAt = CloudRecordParsing.date(from: data["createdAt"]),
            let moodID = data["moodID"] as? String,
            let intensity = CloudRecordParsing.double(from: data["intensity"])
        else {
            return nil
        }

        self.id = document.documentID
        self.createdAt = createdAt
        self.moodID = moodID
        self.intensity = intensity
        self.trigger = data["trigger"] as? String ?? ""
        self.note = data["note"] as? String ?? ""
        self.activities = CloudRecordParsing.activitySnapshots(from: data["activities"])
    }

    var documentPayload: CloudDocumentPayload {
        CloudDocumentPayload(
            id: id,
            data: [
                "createdAt": Timestamp(date: createdAt),
                "moodID": moodID,
                "intensity": intensity,
                "trigger": trigger,
                "note": note,
                "activities": activities.map { snapshot in
                    [
                        "title": snapshot.title,
                        "symbolName": snapshot.symbolName,
                    ]
                },
            ]
        )
    }
}

private enum CloudRecordParsing {
    static func date(from value: Any?) -> Date? {
        switch value {
        case let timestamp as Timestamp:
            return timestamp.dateValue()
        case let date as Date:
            return date
        default:
            return nil
        }
    }

    static func double(from value: Any?) -> Double? {
        switch value {
        case let double as Double:
            return double
        case let number as NSNumber:
            return number.doubleValue
        default:
            return nil
        }
    }

    static func activitySnapshots(from value: Any?) -> [EntryActivitySnapshot] {
        let items = value as? [[String: Any]] ?? []
        return items.compactMap { item in
            guard
                let title = item["title"] as? String,
                let symbolName = item["symbolName"] as? String
            else {
                return nil
            }

            return EntryActivitySnapshot(title: title, symbolName: symbolName)
        }
    }

    static func dates(from value: Any?) -> [Date] {
        let values = value as? [Any] ?? []
        return values.compactMap { value in
            date(from: value)
        }
    }
}

private enum CloudAccountError: LocalizedError {
    case missingFirebaseConfiguration
    case firebaseConfigurationBundleIDMismatch(appBundleID: String?, configBundleID: String?)
    case missingGoogleURLScheme(expectedScheme: String?)
    case missingGoogleClientID
    case missingGoogleReversedClientID
    case missingPresentingController
    case missingGoogleIdentityToken
    case googleFlowReturnedNoResult
    case firebaseAuthReturnedNoResult
    case cloudRequestReturnedNoData
    case invalidAppleCredential
    case missingAppleNonce
    case missingAppleIdentityToken
    case missingAuthenticatedUser
    case notSignedIn
    case emptyCloudState
    case requiresRecentReauthenticationForAccountDeletion

    var errorDescription: String? {
        switch self {
        case .missingFirebaseConfiguration:
            return "В приложении пока нет рабочего Firebase-конфига, поэтому облачный аккаунт ещё нельзя включить."
        case .firebaseConfigurationBundleIDMismatch(let appBundleID, let configBundleID):
            if let appBundleID, let configBundleID {
                return "Этот `GoogleService-Info.plist` рассчитан на `\(configBundleID)`, а приложение сейчас использует `\(appBundleID)`."
            }

            return "Добавленный Firebase-конфиг не совпадает с текущим приложением."
        case .missingGoogleURLScheme(let expectedScheme):
            if let expectedScheme {
                return "Для входа через Google нужно добавить URL scheme `\(expectedScheme)` в настройки target."
            }

            return "Для входа через Google нужно добавить URL scheme из Firebase-конфига в настройки target."
        case .missingGoogleClientID:
            return "Не удалось прочитать Google Client ID из Firebase-конфига."
        case .missingGoogleReversedClientID:
            return "В Firebase-конфиге не найден `REVERSED_CLIENT_ID`, который нужен для возврата из Google-входа."
        case .missingPresentingController:
            return "Не удалось открыть системное окно входа. Попробуй ещё раз."
        case .missingGoogleIdentityToken:
            return "Google не вернул ID token для входа в аккаунт."
        case .googleFlowReturnedNoResult:
            return "Google-вход завершился без результата. Попробуй ещё раз."
        case .firebaseAuthReturnedNoResult:
            return "Firebase не вернул результат авторизации."
        case .cloudRequestReturnedNoData:
            return "Облачный ответ пришёл пустым. Попробуй ещё раз."
        case .invalidAppleCredential:
            return "Apple не передал корректные данные для входа."
        case .missingAppleNonce:
            return "Сессия Apple-входа устарела. Нажми кнопку входа ещё раз."
        case .missingAppleIdentityToken:
            return "Apple не вернул токен для авторизации в Firebase."
        case .missingAuthenticatedUser:
            return "Не удалось найти текущую авторизацию Firebase. Попробуй снова войти в аккаунт."
        case .notSignedIn:
            return "Сначала нужно войти в аккаунт."
        case .emptyCloudState:
            return "В аккаунте пока нет сохранённых записей, целей или занятий."
        case .requiresRecentReauthenticationForAccountDeletion:
            return "Для удаления аккаунта нужно заново подтвердить вход. Войди ещё раз и повтори удаление: облачные данные уже очищены, осталось удалить сам аккаунт."
        }
    }
}

private extension UIApplication {
    static func topMostViewController(
        base: UIViewController? = UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    ) -> UIViewController? {
        if let navigationController = base as? UINavigationController {
            return topMostViewController(base: navigationController.visibleViewController)
        }

        if let tabBarController = base as? UITabBarController {
            return topMostViewController(base: tabBarController.selectedViewController)
        }

        if let presentedViewController = base?.presentedViewController {
            return topMostViewController(base: presentedViewController)
        }

        return base
    }
}
