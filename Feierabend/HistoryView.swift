//
//  HistoryView.swift
//  Feierabend
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: WorkDayStore

    private var todayKey: String { WorkDay.key(for: .now) }

    /// Tage nach Monat gruppiert ("2026-09"), neueste Monate und Tage zuerst.
    private var months: [(key: String, days: [WorkDay])] {
        Dictionary(grouping: store.days) { String($0.dateKey.prefix(7)) }
            .map { (key: $0.key, days: $0.value.sorted { $0.dateKey > $1.dateKey }) }
            .sorted { $0.key > $1.key }
    }

    /// Summe der Über-/Minusstunden eines Monats über alle Tage mit Stempelungen.
    /// Jeder Monat beginnt dadurch wieder bei null.
    private func balance(of days: [WorkDay]) -> Int {
        days
            .filter { !$0.intervals.isEmpty }
            .reduce(0) { $0 + (worked(for: $1) - $1.sollMinutes) }
    }

    var body: some View {
        List {
            if store.days.isEmpty {
                ContentUnavailableView(
                    "Noch keine Einträge",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Deine Arbeitstage erscheinen hier automatisch.")
                )
            }

            ForEach(months, id: \.key) { month in
                Section {
                    ForEach(month.days) { day in
                        NavigationLink {
                            DayEditView(day: binding(for: day.id), isToday: day.dateKey == todayKey)
                        } label: {
                            row(for: day)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                store.delete(day)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    monthHeader(key: month.key, balance: balance(of: month.days))
                }
            }
        }
        .navigationTitle("Verlauf")
    }

    private func monthHeader(key: String, balance: Int) -> some View {
        let date = WorkDay.keyFormatter.date(from: key + "-01") ?? .now
        return HStack {
            Text(date, format: .dateTime.month(.wide).year())
            Spacer()
            Text("Saldo \(TimeFormat.signedDuration(balance))")
                .monospacedDigit()
                .foregroundStyle(balance < 0 ? .red : .green)
        }
    }

    /// Binding über die id statt über den Index – so greift es beim Löschen nicht ins Leere.
    private func binding(for id: String) -> Binding<WorkDay> {
        Binding {
            store.days.first { $0.id == id } ?? WorkDay(dateKey: id, sollMinutes: 0)
        } set: { newValue in
            guard let index = store.days.firstIndex(where: { $0.id == id }) else { return }
            store.days[index] = newValue
        }
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
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
            HStack(spacing: 10) {
                // Die Uhrzeiten haben Vorrang und werden nie gekürzt –
                // wird es eng, verkleinern sich Arbeitszeit und Pause.
                item("clock", "\(TimeFormat.clockOrDash(day.firstStart))–\(TimeFormat.clockOrDash(day.lastEnd))")
                    .fixedSize()
                    .layoutPriority(1)
                item("briefcase", TimeFormat.duration(workedMinutes))
                item("cup.and.saucer", TimeFormat.duration(day.pauseMinutes(now: reference(for: day))))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    /// Kompakte Variante von `Label` mit wenig Abstand zwischen Symbol und Text.
    private func item(_ systemImage: String, _ text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView(store: WorkDayStore())
    }
}
