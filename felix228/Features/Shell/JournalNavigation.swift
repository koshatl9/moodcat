//
//  JournalNavigation
//  felix228
//
//  Created by Codex on 13.05.2026.
//

import SwiftUI
import UIKit
enum JournalTab: String, CaseIterable, Identifiable {
    case records
    case statistics
    case calendar
    case more

    var id: String { rawValue }

    var title: String {
        switch self {
        case .records:
            "Записи"
        case .statistics:
            "Статистика"
        case .calendar:
            "Календарь"
        case .more:
            "Больше"
        }
    }

    var symbolName: String {
        switch self {
        case .records:
            "list.bullet.rectangle.portrait"
        case .statistics:
            "chart.bar.xaxis"
        case .calendar:
            "calendar"
        case .more:
            "ellipsis"
        }
    }

    var selectedSymbolName: String {
        switch self {
        case .records:
            "list.bullet.rectangle.fill"
        case .statistics:
            "chart.bar.xaxis"
        case .calendar:
            "calendar.circle.fill"
        case .more:
            "ellipsis.circle.fill"
        }
    }
}

enum CalendarOverviewMode: String, CaseIterable, Identifiable {
    case moods
    case activities
    case goals

    var id: String { rawValue }

    var title: String {
        switch self {
        case .moods:
            "Эмоции"
        case .activities:
            "Занятия"
        case .goals:
            "Цели"
        }
    }

    var systemImage: String {
        switch self {
        case .moods:
            "face.smiling"
        case .activities:
            "sparkles.square.filled.on.square"
        case .goals:
            "target"
        }
    }
}

struct JournalFloatingTabBar: View {
    @EnvironmentObject private var localization: LocalizationManager

    @Binding var selectedTab: JournalTab
    let palette: ThemePalette
    let createAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            HStack(spacing: 8) {
                ForEach(JournalTab.allCases) { tab in
                    Button {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: selectedTab == tab ? tab.selectedSymbolName : tab.symbolName)
                                .font(.system(size: 18, weight: .semibold))
                            Text(localization.title(for: tab))
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(selectedTab == tab ? palette.accent : palette.primaryText.opacity(0.78))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(selectedTab == tab ? palette.accentSoft : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(palette.elevatedSurface.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(palette.stroke, lineWidth: 1)
            )
            .shadow(color: palette.shadow.opacity(0.7), radius: 24, y: 10)

            Button(action: createAction) {
                Image(systemName: "plus")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(palette.floatingButtonForeground)
                    .frame(width: 82, height: 82)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        palette.floatingButtonSecondary,
                                        palette.floatingButton
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(palette.stroke, lineWidth: 1)
                    )
                    .shadow(color: palette.accent.opacity(0.24), radius: 20, y: 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localization.pick("Создать запись", "Create entry"))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }
}
