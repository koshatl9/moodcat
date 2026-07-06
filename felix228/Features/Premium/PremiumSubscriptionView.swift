//
//  PremiumSubscriptionView.swift
//  felix228
//
//  Created by Codex on 14.05.2026.
//

import Combine
import StoreKit
import SwiftUI

struct PremiumSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var premiumAccess: PremiumAccessManager

    @State private var selectedProductID: String?
    @State private var errorMessage: String?
    @State private var presentedLegalDestination: LegalDestination?

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    private var selectedProduct: Product? {
        guard let selectedProductID else { return premiumAccess.availableProducts.first }
        return premiumAccess.availableProducts.first { $0.id == selectedProductID }
    }

    private var isBusy: Bool {
        premiumAccess.isLoadingProducts || premiumAccess.isPurchasing || premiumAccess.isRestoring
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView(palette: palette)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        heroCard
                        featuresCard
                        plansCard
                        footerCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Подписка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .task {
                await premiumAccess.refreshStoreState()

                if selectedProductID == nil {
                    selectedProductID = premiumAccess.availableProducts.first?.id
                }
            }
            .onChange(of: premiumAccess.availableProducts.map(\.id)) { _, _ in
                if selectedProductID == nil {
                    selectedProductID = premiumAccess.availableProducts.first?.id
                }
            }
            .onReceive(premiumAccess.$purchaseErrorMessage.compactMap { $0 }) { message in
                errorMessage = message
            }
            .alert("Не удалось оформить подписку", isPresented: isShowingError) {
                Button("Ок", role: .cancel) {
                    premiumAccess.purchaseErrorMessage = nil
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "Попробуй ещё раз чуть позже.")
            }
            .sheet(item: $presentedLegalDestination) { destination in
                LegalAndSupportView(destination: destination)
            }
        }
    }

    private var heroCard: some View {
        StatisticsSectionCard(
            palette: palette,
            title: premiumAccess.paywallTitle,
            subtitle: premiumAccess.paywallSubtitle
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Label(
                    premiumAccess.hasPremiumAccess
                        ? "Премиум уже открыт и все темы стикеров доступны."
                        : "Премиум открывает всё приложение и закрытые темы.",
                    systemImage: premiumAccess.hasPremiumAccess ? "checkmark.circle.fill" : "sparkles"
                )
                .font(.headline.weight(.semibold))
                .foregroundStyle(premiumAccess.hasPremiumAccess ? palette.accent : .primary)

                Text("Каждая подписка на приложение — это вкусняшка коту Феликсу.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var featuresCard: some View {
        StatisticsSectionCard(
            palette: palette,
            title: "Что откроется",
            subtitle: "Подписка делает обычную версию полной и снимает замки с premium-контента."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(premiumAccess.premiumFeatures.enumerated()), id: \.offset) { _, feature in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "pawprint.fill")
                            .foregroundStyle(palette.accent)
                            .padding(.top, 2)

                        Text(feature)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var plansCard: some View {
        StatisticsSectionCard(
            palette: palette,
            title: "Оформить подписку",
            subtitle: "Выбери удобный тариф. После оплаты premium откроется автоматически."
        ) {
            VStack(spacing: 12) {
                if premiumAccess.availableProducts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(premiumAccess.isLoadingProducts ? "Тарифы загружаются" : "Тарифы пока недоступны")
                            .font(.headline.weight(.semibold))

                        Text(
                            premiumAccess.isLoadingProducts
                                ? "Как только App Store вернёт тарифы, здесь появятся варианты подписки и кнопка покупки."
                                : "Если запускаешь приложение из Xcode, перезапусти его через схему `felix228`: у неё уже подключён тестовый StoreKit-конфиг с тарифами. После этого варианты подписки появятся здесь автоматически."
                        )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if isBusy {
                            ProgressView()
                                .tint(palette.accent)
                        } else {
                            Button {
                                Task {
                                    await premiumAccess.refreshStoreState()
                                }
                            } label: {
                                Label("Обновить тарифы", systemImage: "arrow.clockwise")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(palette.accent)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(palette.accentSoft)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(palette.stroke, lineWidth: 1)
                    )
                } else {
                    ForEach(premiumAccess.availableProducts, id: \.id) { product in
                        PremiumPlanCard(
                            product: product,
                            isSelected: selectedProductID == product.id,
                            palette: palette,
                            action: {
                                selectedProductID = product.id
                            }
                        )
                    }

                    Button {
                        guard let selectedProduct else { return }

                        Task {
                            await premiumAccess.purchase(selectedProduct)
                        }
                    } label: {
                        HStack {
                            if premiumAccess.isPurchasing {
                                ProgressView()
                                    .tint(palette.floatingButtonForeground)
                            }

                            Text(premiumAccess.hasPremiumAccess ? "Открыть подписку" : "Оформить подписку")
                                .font(.headline.weight(.semibold))

                            Spacer()

                            Text(selectedProduct?.displayPrice ?? "")
                                .font(.headline.weight(.bold))
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
                    .buttonStyle(.plain)
                    .disabled(isBusy || selectedProduct == nil)
                }

                Button {
                    Task {
                        await premiumAccess.restorePurchases()
                    }
                } label: {
                    Text(premiumAccess.isRestoring ? "Восстанавливаем..." : "Восстановить покупки")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(palette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(palette.stroke, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isBusy)

                HStack(spacing: 12) {
                    Button {
                        presentedLegalDestination = .privacyPolicy
                    } label: {
                        Text("Конфиденциальность")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(palette.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(palette.stroke, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        presentedLegalDestination = .termsOfUse
                    } label: {
                        Text("Условия")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(palette.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(palette.stroke, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var footerCard: some View {
        StatisticsSectionCard(
            palette: palette,
            title: "Для кота Феликса",
            subtitle: nil
        ) {
            Text(premiumAccess.footerMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { shouldShow in
                if !shouldShow {
                    premiumAccess.purchaseErrorMessage = nil
                    errorMessage = nil
                }
            }
        )
    }
}

private struct PremiumPlanCard: View {
    let product: Product
    let isSelected: Bool
    let palette: ThemePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(planTitle)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(isSelected ? palette.floatingButtonForeground : .primary)

                        if product.id == PremiumAccessManager.yearlyProductID {
                            Text("Выгодно")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(isSelected ? palette.floatingButtonForeground : palette.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(isSelected ? Color.white.opacity(0.16) : palette.accentSoft)
                                .clipShape(Capsule())
                        }
                    }

                    Text(planSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(isSelected ? palette.floatingButtonForeground.opacity(0.82) : .secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text(product.displayPrice)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(isSelected ? palette.floatingButtonForeground : .primary)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? palette.floatingButtonForeground : .secondary)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(activeFill) : AnyShapeStyle(palette.surface))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? Color.clear : palette.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var planTitle: String {
        switch product.id {
        case PremiumAccessManager.monthlyProductID:
            "Ежемесячная подписка"
        case PremiumAccessManager.yearlyProductID:
            "Годовая подписка"
        default:
            product.displayName
        }
    }

    private var planSubtitle: String {
        switch product.id {
        case PremiumAccessManager.monthlyProductID:
            "Полный доступ ко всему на месяц."
        case PremiumAccessManager.yearlyProductID:
            "Полный доступ ко всему на год и больше вкусняшек Феликсу."
        default:
            "Полный доступ ко всем функциям приложения."
        }
    }

    private var activeFill: LinearGradient {
        LinearGradient(
            colors: [
                palette.floatingButton,
                palette.floatingButtonSecondary
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
