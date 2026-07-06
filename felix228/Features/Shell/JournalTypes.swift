//
//  JournalTypes
//  felix228
//
//  Created by Codex on 13.05.2026.
//

import SwiftUI
import UIKit
struct MoodStatItem: Identifiable {
    let mood: Mood
    let count: Int

    var id: String { mood.id }
}

struct ActivityStatItem: Identifiable {
    let snapshot: EntryActivitySnapshot
    let count: Int

    var id: String { snapshot.id }
}

struct StatisticsMoodTrendPoint: Identifiable {
    let dayNumber: Int
    let score: Double
    let entryCount: Int

    var id: Int { dayNumber }
}

struct StatisticsStreakDay: Identifiable {
    let date: Date
    let label: String
    let isToday: Bool

    var id: TimeInterval { date.timeIntervalSince1970 }
}

struct MoreRowModel: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let tint: Color
    let trailingText: String?
    let action: (() -> Void)?
}
