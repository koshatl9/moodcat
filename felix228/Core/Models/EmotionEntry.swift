//
//  EmotionEntry.swift
//  felix228
//
//  Created by Codex on 12.05.2026.
//

import Foundation
import SwiftData

@Model
final class EmotionEntry {
    var syncID: String?
    var createdAt: Date
    var moodID: String
    var intensity: Double
    var trigger: String
    var note: String
    var activitySnapshotsData: String

    init(
        syncID: String? = UUID().uuidString,
        createdAt: Date = .now,
        mood: Mood,
        intensity: Double,
        trigger: String = "",
        note: String = "",
        activitySnapshots: [EntryActivitySnapshot] = []
    ) {
        self.syncID = syncID
        self.createdAt = createdAt
        self.moodID = mood.rawValue
        self.intensity = intensity
        self.trigger = trigger
        self.note = note
        self.activitySnapshotsData = Self.encodeActivitySnapshots(activitySnapshots)
    }

    var mood: Mood {
        get { Mood(storageValue: moodID) }
        set { moodID = newValue.rawValue }
    }

    var activitySnapshots: [EntryActivitySnapshot] {
        get { Self.decodeActivitySnapshots(from: activitySnapshotsData) }
        set { activitySnapshotsData = Self.encodeActivitySnapshots(newValue) }
    }

    private static func encodeActivitySnapshots(_ snapshots: [EntryActivitySnapshot]) -> String {
        guard
            let data = try? JSONEncoder().encode(snapshots),
            let string = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }

        return string
    }

    private static func decodeActivitySnapshots(from string: String) -> [EntryActivitySnapshot] {
        guard
            let data = string.data(using: .utf8),
            let snapshots = try? JSONDecoder().decode([EntryActivitySnapshot].self, from: data)
        else {
            return []
        }

        return snapshots
    }
}
