//
//  HistoryView.swift
//  Feierabend
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: WorkDayStore

    private var sortedDays: [WorkDay] {
        store.days.sorted { $0.dateKey > $1.dateKey }
    }

    private var todayKey: String { WorkDay.key(for: .now) }

    /// Summe der Über-/Minusstunden über alle Tage mit Stempelungen.
    private var balance: Int {
        store.days
            .filter { !$0.intervals.isEmpty }
            .reduce(0) { $0 + (worked(for: $1) - $1.sollMinutes) }
    }

    var body: some View {
        List {
            if sortedDays.isEmpty {
                ContentUnavailableView(
                    "Noch keine Einträge",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Deine Arbeitstage erscheinen hier automatisch.")
                )
            } else {
                Section {
                    HStack {
                        Text("Saldo gesamt")
                        Spacer()
                        Text(TimeFormat.signedDuration(balance))
                            .monospacedDigit()
                            .foregroundStyle(balance < 0 ? .red : .green)
                    }
                }
            }

            ForEach(sortedDays) { day in
                row(for: day)
                    .swipeActions {
                        Button(role: .destructive) {
                            store.delete(day)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
            }
        }
        .navigationTitle("Verlauf")
    }

    /// Bezugszeitpunkt: für vergangene Tage die letzte Stempelung, für heute jetzt.
    private func reference(for day: WorkDay) -> Int {
        day.dateKey == todayKey
            ? TimeFormat.minutes(of: .now)
            : (day.lastEnd ?? day.firstStart ?? 0)
    }

    private func worked(for day: WorkDay) -> Int {
        day.workedMinutes(now: reference(for: day))
    }

    private func row(for day: WorkDay) -> some View {
        let workedMinutes = worked(for: day)
        let diff = workedMinutes - day.sollMinutes

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(day.date, format: .dateTime.weekday(.wide).day().month().year())
                    .font(.headline)
                if day.dateKey == todayKey {
                    Text("Heute")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.2), in: Capsule())
                        .foregroundStyle(.green)
                }
                Spacer()
                if !day.intervals.isEmpty {
                    Text(TimeFormat.signedDuration(diff))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(diff < 0 ? .red : .green)
                }
            }
            HStack(spacing: 16) {
                Label(
                    "\(TimeFormat.clockOrDash(day.firstStart)) – \(TimeFormat.clockOrDash(day.lastEnd))",
                    systemImage: "clock"
                )
                Label(TimeFormat.duration(workedMinutes), systemImage: "briefcase")
                Label(TimeFormat.duration(day.pauseMinutes(now: reference(for: day))), systemImage: "cup.and.saucer")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        HistoryView(store: WorkDayStore())
    }
}
