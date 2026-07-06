//
//  PremiumAccessManager.swift
//  felix228
//
//  Created by Codex on 14.05.2026.
//

import Combine
import Foundation
import StoreKit
#if DEBUG && canImport(StoreKitTest)
import StoreKitTest
#endif

@MainActor
final class PremiumAccessManager: ObservableObject {
    @Published private(set) var hasPremiumAccess = false
    @Published private(set) var availableProducts: [Product] = []
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published var purchaseErrorMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?
    private let defaults = UserDefaults.standard
#if DEBUG && canImport(StoreKitTest)
    private var localTestSession: SKTestSession?
#endif

    private static let premiumAccessCacheKey = "felix228.premium.cachedAccess"

    static let monthlyProductID = "com.toelagm.felix228.premium.monthly"
    static let yearlyProductID = "com.toelagm.felix228.premium.yearly"

    let productIDs = [
        monthlyProductID,
        yearlyProductID
    ]

    init() {
        hasPremiumAccess = defaults.bool(forKey: Self.premiumAccessCacheKey)
        configureLocalStoreKitSessionIfPossible()
        transactionUpdatesTask = observeTransactions()

        Task {
            await refreshStoreState()
        }
    }

    var paywallTitle: String {
        hasPremiumAccess ? "Подписка уже активна" : "Подписка Felix Premium"
    }

    var paywallSubtitle: String {
        hasPremiumAccess
            ? "У тебя уже открыт полный доступ ко всем темам и будущим premium-обновлениям."
            : "Оформи подписку и открой все темы стикеров, расширенные обновления и весь дневник без ограничений."
    }

    var premiumFeatures: [String] {
        [
            "Доступ ко всем функциям приложения без ограничений.",
            "Разблокировка закрытых тем стикеров, включая Kitty Slime и Kitty Moji.",
            "Premium-функция Felix в Dynamic Island с живой карточкой котёнка наверху экрана.",
            "Доступ ко всем будущим premium-темам и визуальным обновлениям.",
            "Каждая подписка на приложение — это вкусняшка коту Феликсу."
        ]
    }

    var footerMessage: String {
        "Спасибо, что поддерживаешь дневник и кота Феликса. Каждая подписка помогает нам делать новые темы, экранчики и вкусняшки для него."
    }

    func refreshStoreState() async {
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let fetchedProducts = try await fetchProductsWithRetry()
            availableProducts = fetchedProducts.sorted { lhs, rhs in
                orderIndex(for: lhs.id) < orderIndex(for: rhs.id)
            }

            if availableProducts.isEmpty {
                purchaseErrorMessage = "Тарифы пока не пришли из StoreKit. Перезапусти приложение из Xcode или нажми обновить на экране подписки."
            }
        } catch {
            availableProducts = []
            purchaseErrorMessage = "Не удалось загрузить тарифы. \(error.localizedDescription)"
        }
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try verified(verification)
                setPremiumAccess(true)
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled:
                break
            case .pending:
                purchaseErrorMessage = "Платёж ещё обрабатывается. Как только магазин подтвердит подписку, премиум откроется автоматически."
            @unknown default:
                purchaseErrorMessage = "Покупка не завершилась. Попробуй ещё раз."
            }
        } catch {
            purchaseErrorMessage = "Подписку не удалось оформить. \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseErrorMessage = "Не удалось восстановить покупки. \(error.localizedDescription)"
        }
    }

    private func refreshEntitlements() async {
        var premiumIsActive = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verified(result) else { continue }
            guard productIDs.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }
            guard !transaction.isUpgraded else { continue }

            if let expirationDate = transaction.expirationDate, expirationDate < .now {
                continue
            }

            premiumIsActive = true
            break
        }

        setPremiumAccess(premiumIsActive)
    }

    private func observeTransactions() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                do {
                    let transaction = try verified(result)
                    await transaction.finish()
                    await refreshEntitlements()
                } catch {
                    purchaseErrorMessage = "Подписка обновилась с ошибкой проверки. Попробуй позже ещё раз."
                }
            }
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw PremiumAccessError.verificationFailed
        }
    }

    private func orderIndex(for productID: String) -> Int {
        productIDs.firstIndex(of: productID) ?? productIDs.count
    }

    private func setPremiumAccess(_ newValue: Bool) {
        hasPremiumAccess = newValue
        defaults.set(newValue, forKey: Self.premiumAccessCacheKey)
    }

    private func fetchProductsWithRetry() async throws -> [Product] {
        var lastProducts: [Product] = []

        for attempt in 0..<3 {
            let fetchedProducts = try await Product.products(for: productIDs)
            if !fetchedProducts.isEmpty {
                return fetchedProducts
            }

            lastProducts = fetchedProducts

            if attempt < 2 {
                try? await Task.sleep(for: .milliseconds(350))
            }
        }

        return lastProducts
    }

    private func configureLocalStoreKitSessionIfPossible() {
#if DEBUG && canImport(StoreKitTest)
        guard localTestSession == nil else { return }
        guard let configurationURL = storeKitConfigurationURL() else {
            return
        }

        do {
            let session = try SKTestSession(contentsOf: configurationURL)
            session.locale = Locale(identifier: "ru_RU")
            session.storefront = "USA"
            session.askToBuyEnabled = false
            session.disableDialogs = false
            localTestSession = session
        } catch {
            purchaseErrorMessage = "Не удалось подготовить локальную покупку для теста. \(error.localizedDescription)"
        }
#endif
    }

    private func storeKitConfigurationURL() -> URL? {
        if let bundledRootURL = Bundle.main.url(forResource: "FelixPremium", withExtension: "storekit") {
            return bundledRootURL
        }

        if let bundledConfigURL = Bundle.main.url(
            forResource: "FelixPremium",
            withExtension: "storekit",
            subdirectory: "Config"
        ) {
            return bundledConfigURL
        }

        return nil
    }
}

enum PremiumAccessError: LocalizedError {
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            "Не удалось подтвердить покупку у App Store."
        }
    }
}
