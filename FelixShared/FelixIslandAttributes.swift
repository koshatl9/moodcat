//
//  FelixIslandAttributes.swift
//  felix228
//
//  Created by Codex on 14.05.2026.
//

import ActivityKit
import Foundation

struct FelixIslandAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var headline: String
        var detail: String
        var moodTitle: String
        var noteCount: Int
    }

    var name: String
}

struct FelixIslandSnapshot: Equatable {
    let headline: String
    let detail: String
    let moodTitle: String
    let noteCount: Int

    static let empty = FelixIslandSnapshot(
        headline: "Феликс ждёт запись",
        detail: "Напиши, как прошёл твой день, и котёнок останется рядом.",
        moodTitle: "Пока пусто",
        noteCount: 0
    )
}
