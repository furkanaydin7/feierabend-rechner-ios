//
//  Models.swift
//  Feierabend
//

import Foundation
internal import Combine

// MARK: - Model

struct Pause: Identifiable, Codable, Equatable {
    var id = UUID()
    var minutes: Int
}

struct WorkDay: Identifiable, Codable, Equatable {
    var dateKey: String // "2026-07-13"
    var startMinutes: Int
    var sollMinutes: Int
    var pausen: [Pause]

    var id: String { dateKey }

    var pauseTotal: Int { pausen.reduce(0) { $0 + $1.minutes } }
    var endMinutes: Int { startMinutes + sollMinutes + pauseTotal }

    var date: Date { Self.keyFormatter.date(from: dateKey) ?? .now }

    static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(for date: Date) -> String {
        keyFormatter.string(from: date)
    }
}

// MARK: - Formatierung

enum TimeFormat {
    static func clock(_ minutes: Int) -> String {
        let m = ((minutes % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    static func duration(_ minutes: Int) -> String {
        let m = abs(minutes)
        return "\(m / 60) h \(String(format: "%02d", m % 60)) min"
    }
}

// MARK: - Store

@MainActor
final class WorkDayStore: ObservableObject {
    @Published var days: [WorkDay] = [] {
        didSet {
            guard days != oldValue else { return }
            save()
        }
    }

    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = dir.appendingPathComponent("workdays.json")
        load()
    }

    /// Liefert den Index des heutigen Eintrags, legt ihn bei Bedarf neu an.
    func ensureToday() -> Int {
        let key = WorkDay.key(for: .now)
        if let i = days.firstIndex(where: { $0.dateKey == key }) { return i }
        let last = days.max(by: { $0.dateKey < $1.dateKey })
        days.append(WorkDay(
            dateKey: key,
            startMinutes: 8 * 60,
            sollMinutes: last?.sollMinutes ?? 516,
            pausen: [Pause(minutes: 30)]
        ))
        return days.count - 1
    }

    func delete(_ day: WorkDay) {
        days.removeAll { $0.id == day.id }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([WorkDay].self, from: data)
        else { return }
        days = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(days) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
