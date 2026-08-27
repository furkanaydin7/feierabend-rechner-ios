//
//  Models.swift
//  Feierabend
//

import Foundation
internal import Combine

// MARK: - Model

/// Ein Arbeitsabschnitt zwischen Ein- und Ausstempeln.
/// Zeiten sind Minuten seit Mitternacht (z. B. 8:12 Uhr = 492).
struct WorkInterval: Identifiable, Codable, Equatable {
    var id = UUID()
    var start: Int
    var end: Int?

    /// Läuft gerade – es wurde eingestempelt, aber noch nicht wieder heraus.
    var isRunning: Bool { end == nil }

    /// Dauer in Minuten. Ein laufender Abschnitt zählt bis `now`.
    func duration(now: Int) -> Int {
        max(0, (end ?? now) - start)
    }
}

struct WorkDay: Identifiable, Codable, Equatable {
    var dateKey: String // "2026-07-13"
    var sollMinutes: Int
    var intervals: [WorkInterval] = []
    /// true, sobald bewusst Feierabend gestempelt wurde (im Gegensatz zu einer Pause).
    var finished: Bool = false

    var id: String { dateKey }

    // MARK: Abschnitte

    var sortedIntervals: [WorkInterval] {
        intervals.sorted { $0.start < $1.start }
    }

    var runningInterval: WorkInterval? { intervals.first(where: \.isRunning) }
    var isRunning: Bool { runningInterval != nil }

    var firstStart: Int? { sortedIntervals.first?.start }
    var lastEnd: Int? { intervals.compactMap(\.end).max() }

    // MARK: Berechnungen

    /// Geleistete Arbeitszeit ohne Pausen.
    func workedMinutes(now: Int) -> Int {
        intervals.reduce(0) { $0 + $1.duration(now: now) }
    }

    /// Pausen = Lücken zwischen den Abschnitten, inklusive einer gerade laufenden Pause.
    func pauseMinutes(now: Int) -> Int {
        let list = sortedIntervals
        var total = 0
        for (previous, next) in zip(list, list.dropFirst()) {
            guard let end = previous.end else { continue }
            total += max(0, next.start - end)
        }
        if !isRunning, !finished, let end = lastEnd {
            total += max(0, now - end)
        }
        return total
    }

    func remainingMinutes(now: Int) -> Int {
        sollMinutes - workedMinutes(now: now)
    }

    /// Zeit über der Sollzeit hinaus.
    func overtimeMinutes(now: Int) -> Int {
        max(0, -remainingMinutes(now: now))
    }

    func isDone(now: Int) -> Bool {
        remainingMinutes(now: now) <= 0
    }

    func progress(now: Int) -> Double {
        guard sollMinutes > 0 else { return 1 }
        return max(0, min(1, Double(workedMinutes(now: now)) / Double(sollMinutes)))
    }

    /// Uhrzeit, zu der die Sollzeit erreicht ist bzw. war.
    /// Solange die Sollzeit nicht erreicht ist, eine Prognose ab jetzt.
    /// `nil`, wenn an diesem Tag noch gar nicht gestempelt wurde.
    func endMinutes(now: Int) -> Int? {
        guard !intervals.isEmpty else { return nil }
        var accumulated = 0
        for interval in sortedIntervals {
            let duration = interval.duration(now: now)
            if accumulated + duration >= sollMinutes {
                return interval.start + (sollMinutes - accumulated)
            }
            accumulated += duration
        }
        // Sollzeit noch nicht erreicht: Rest ab jetzt weiterarbeiten.
        return max(now, lastEnd ?? now) + (sollMinutes - accumulated)
    }

    // MARK: Stempeln

    /// Startet einen neuen Abschnitt, falls gerade keiner läuft.
    mutating func punchIn(at minutes: Int) {
        guard !isRunning else { return }
        finished = false
        intervals.append(WorkInterval(start: minutes, end: nil))
    }

    /// Beendet den laufenden Abschnitt. `asFeierabend` unterscheidet Pause von Feierabend.
    mutating func punchOut(at minutes: Int, asFeierabend: Bool) {
        guard let index = intervals.firstIndex(where: \.isRunning) else { return }
        intervals[index].end = max(intervals[index].start, minutes)
        finished = asFeierabend
    }

    /// Fügt einen manuellen Eintrag hinzu und liefert dessen id.
    @discardableResult
    mutating func addManualInterval(defaultStart: Int) -> UUID {
        let start = min(lastEnd ?? defaultStart, 23 * 60)
        let interval = WorkInterval(start: start, end: min(start + 60, 24 * 60 - 1))
        intervals.append(interval)
        return interval.id
    }

    // MARK: Datum

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

    // MARK: Codable inkl. Migration des alten Formats

    enum CodingKeys: String, CodingKey {
        case dateKey, sollMinutes, intervals, finished
    }

    /// Felder des früheren Formats (fester Arbeitsbeginn + Pausenliste).
    private enum LegacyKeys: String, CodingKey {
        case startMinutes, pausen
    }

    private struct LegacyPause: Codable {
        var minutes: Int
    }

    init(dateKey: String, sollMinutes: Int, intervals: [WorkInterval] = [], finished: Bool = false) {
        self.dateKey = dateKey
        self.sollMinutes = sollMinutes
        self.intervals = intervals
        self.finished = finished
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dateKey = try container.decode(String.self, forKey: .dateKey)
        sollMinutes = try container.decode(Int.self, forKey: .sollMinutes)
        finished = try container.decodeIfPresent(Bool.self, forKey: .finished) ?? false

        if let stored = try container.decodeIfPresent([WorkInterval].self, forKey: .intervals) {
            intervals = stored
            return
        }

        // Alte Einträge übernehmen: Arbeitsbeginn + Pausensumme.
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        let start = try legacy.decodeIfPresent(Int.self, forKey: .startMinutes) ?? 8 * 60
        let pause = (try legacy.decodeIfPresent([LegacyPause].self, forKey: .pausen) ?? [])
            .reduce(0) { $0 + $1.minutes }
        intervals = Self.migratedIntervals(start: start, soll: sollMinutes, pause: pause, dateKey: dateKey)
    }

    /// Baut aus den alten Feldern plausible Abschnitte. Der heutige Tag läuft
    /// vermutlich noch, ältere Tage werden als erfüllte Sollzeit abgebildet.
    private static func migratedIntervals(start: Int, soll: Int, pause: Int, dateKey: String) -> [WorkInterval] {
        // Heute und der Feierabend ist noch nicht erreicht: als laufender Abschnitt übernehmen.
        if dateKey >= key(for: .now), TimeFormat.minutes(of: .now) < start + soll + pause {
            return [WorkInterval(start: start, end: nil)]
        }
        guard pause > 0 else {
            return [WorkInterval(start: start, end: start + soll)]
        }
        // Die genaue Lage der Pause ist im alten Format nicht gespeichert –
        // sie wird in die Mitte gelegt, Summe und Feierabend stimmen dadurch.
        let firstHalf = soll / 2
        return [
            WorkInterval(start: start, end: start + firstHalf),
            WorkInterval(start: start + firstHalf + pause, end: start + soll + pause),
        ]
    }
}

// MARK: - Formatierung

enum TimeFormat {
    /// Minuten seit Mitternacht für ein Datum.
    static func minutes(of date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func clock(_ minutes: Int) -> String {
        let m = ((minutes % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    static func duration(_ minutes: Int) -> String {
        let m = abs(minutes)
        return "\(m / 60) h \(String(format: "%02d", m % 60)) min"
    }

    /// Mit Vorzeichen, z. B. "+0 h 12 min" für Überstunden.
    static func signedDuration(_ minutes: Int) -> String {
        (minutes < 0 ? "−" : "+") + duration(minutes)
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
        days.append(WorkDay(dateKey: key, sollMinutes: last?.sollMinutes ?? 516))
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
