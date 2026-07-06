//
//  FelixIslandLiveActivity.swift
//  FelixIslandExtension
//
//  Created by Codex on 14.05.2026.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct FelixIslandLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FelixIslandAttributes.self) { context in
            FelixIslandExpandedCard(state: context.state)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    FelixIslandKittenView(size: 56)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(context.state.noteCount)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("записей")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.74))
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        FelixIslandKittenView(size: 48)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(context.state.headline)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text(context.state.detail)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.76))
                                .lineLimit(2)
                        }

                        Spacer(minLength: 0)
                    }
                }
            } compactLeading: {
                FelixIslandKittenView(size: 22)
            } compactTrailing: {
                Text("\(context.state.noteCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            } minimal: {
                FelixIslandKittenView(size: 18)
            }
            .keylineTint(Color.orange)
        }
    }
}

private struct FelixIslandExpandedCard: View {
    let state: FelixIslandAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            FelixIslandKittenView(size: 64)

            VStack(alignment: .leading, spacing: 6) {
                Text(state.headline)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(state.detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(2)

                Text("\(state.noteCount) записей в дневнике")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.orange.opacity(0.9))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 33 / 255, green: 25 / 255, blue: 41 / 255),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private struct FelixIslandKittenView: View {
    let size: CGFloat

    var body: some View {
        Image("FelixIslandKitten")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: Color.orange.opacity(0.22), radius: size * 0.12, y: size * 0.05)
    }
}

#Preview("Felix Island", as: .content, using: FelixIslandAttributes(name: "Феликс")) {
    FelixIslandLiveActivity()
} contentStates: {
    FelixIslandAttributes.ContentState(
        headline: "Феликс рядом",
        detail: "Записей сегодня: 3. Нажми и продолжи дневник.",
        moodTitle: "Нормально",
        noteCount: 3
    )
}
