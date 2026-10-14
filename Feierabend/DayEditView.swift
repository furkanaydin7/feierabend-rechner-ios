//
//  DayEditView.swift
//  Feierabend
//

import SwiftUI

/// Nachträgliches Bearbeiten eines Tages aus dem Verlauf: Stempelungen und Sollzeit.
struct DayEditView: View {
    @Binding var day: WorkDay
    let isToday: Bool

    /// Bezugszeitpunkt wie im Verlauf: für vergangene Tage die letzte Stempelung, für heute jetzt.
    private var reference: Int {
        isToday ? TimeFormat.minutes(of: .now) : (day.lastEnd ?? day.firstStart ?? 0)
    }

    private var worked: Int { day.workedMinutes(now: reference) }
    private var diff: Int { worked - day.sollMinutes }

    var body: some View {
        Form {
            summarySection
            intervalSection
            sollSection
        }
        .navigationTitle(Text(day.date, format: .dateTime.weekday(.abbreviated).day().month()))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Übersicht
    private var summarySection: some View {
        Section {
            LabeledContent("Arbeitszeit", value: TimeFormat.duration(worked))
            LabeledContent("Pause", value: TimeFormat.duration(day.pauseMinutes(now: reference)))
            if !day.intervals.isEmpty {
                LabeledContent("Saldo") {
                    Text(TimeFormat.signedDuration(diff))
                        .foregroundStyle(diff < 0 ? .red : .green)
                }
            }
        } header: {
            Text(day.date, format: .dateTime.weekday(.wide).day().month(.wide).year())
        }
        .monospacedDigit()
    }

    // MARK: Stempelungen
    private var intervalSection: some View {
        Section {
            if day.intervals.isEmpty {
                Text("Keine Stempelungen an diesem Tag.")
                    .foregroundStyle(.secondary)
            }

            ForEach(day.sortedIntervals) { interval in
                IntervalRow(interval: binding(for: interval.id), now: reference)
                    .swipeActions {
                        Button(role: .destructive) {
                            day.intervals.removeAll { $0.id == interval.id }
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
            }

            Button {
                withAnimation {
                    day.addManualInterval(defaultStart: 8 * 60)
                }
            } label: {
                Label("Eintrag hinzufügen", systemImage: "plus.circle")
            }
        } header: {
            Text("Stempelungen")
        } footer: {
            Text("Zeiten antippen, um sie zu ändern. Zum Löschen nach links wischen.")
        }
    }

    // MARK: Sollzeit
    private var sollSection: some View {
        Section {
            DurationWheelPicker(minutes: $day.sollMinutes)
        } header: {
            HStack {
                Text("Sollzeit")
                Spacer()
                Text(TimeFormat.duration(day.sollMinutes))
                    .monospacedDigit()
            }
        }
    }

    // MARK: Helfer

    /// Binding über die id statt über den Index – so greift es beim Löschen nicht ins Leere.
    private func binding(for id: UUID) -> Binding<WorkInterval> {
        Binding {
            day.intervals.first { $0.id == id } ?? WorkInterval(start: 0, end: nil)
        } set: { newValue in
            guard let index = day.intervals.firstIndex(where: { $0.id == id }) else { return }
            day.intervals[index] = newValue
        }
    }
}

#Preview {
    @Previewable @State var day = WorkDay(
        dateKey: "2026-10-12",
        sollMinutes: 516,
        intervals: [
            WorkInterval(start: 469, end: 720),
            WorkInterval(start: 785, end: 1036),
        ],
        finished: true
    )
    NavigationStack {
        DayEditView(day: $day, isToday: false)
    }
}
