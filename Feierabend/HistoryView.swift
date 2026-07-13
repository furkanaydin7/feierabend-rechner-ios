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

    var body: some View {
        List {
            if sortedDays.isEmpty {
                ContentUnavailableView(
                    "Noch keine Einträge",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Deine Arbeitstage erscheinen hier automatisch.")
                )
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

    private func row(for day: WorkDay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
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
            }
            HStack(spacing: 16) {
                Label("\(TimeFormat.clock(day.startMinutes)) – \(TimeFormat.clock(day.endMinutes))", systemImage: "clock")
                Label(TimeFormat.duration(day.sollMinutes), systemImage: "briefcase")
                Label(TimeFormat.duration(day.pauseTotal), systemImage: "cup.and.saucer")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        HistoryView(store: WorkDayStore())
    }
}
