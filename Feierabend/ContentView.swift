//
//  ContentView.swift
//  Feierabend
//
//  Created by Furkan Aydin on 09.07.2026.
//

import SwiftUI
internal import Combine

// MARK: - ContentView
struct ContentView: View {
    @StateObject private var store = WorkDayStore()
    @State private var now: Date = Date()
    @Environment(\.scenePhase) private var scenePhase

    private let timer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    private var todayKey: String { WorkDay.key(for: now) }

    var body: some View {
        NavigationStack {
            Group {
                if let index = store.days.firstIndex(where: { $0.dateKey == todayKey }) {
                    TodayView(day: $store.days[index], now: now)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Feierabend")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        HistoryView(store: store)
                    } label: {
                        Label("Verlauf", systemImage: "clock.arrow.circlepath")
                    }
                }
            }
        }
        .onAppear { _ = store.ensureToday() }
        .onChange(of: store.days) { _, _ in
            _ = store.ensureToday() // z. B. nach Löschen des heutigen Eintrags im Verlauf
        }
        .onReceive(timer) { date in
            now = date
            _ = store.ensureToday() // legt beim Tageswechsel automatisch einen neuen Eintrag an
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                now = Date()
                _ = store.ensureToday()
            }
        }
    }
}

// MARK: - TodayView
struct TodayView: View {
    @Binding var day: WorkDay
    let now: Date
    @State private var showCustomTime = false
    @State private var stampCount = 0

    private let presets: [(label: String, min: Int)] = [
        ("4 h 18", 258),
        ("8 h 00", 480),
        ("8 h 36", 516),
    ]

    // MARK: Berechnungen
    private var nowMinutes: Int { TimeFormat.minutes(of: now) }
    private var worked: Int { day.workedMinutes(now: nowMinutes) }
    private var pause: Int { day.pauseMinutes(now: nowMinutes) }
    private var remaining: Int { day.remainingMinutes(now: nowMinutes) }
    private var done: Bool { day.isDone(now: nowMinutes) }
    private var endMinutes: Int? { day.endMinutes(now: nowMinutes) }

    private var accent: Color { done ? .green : Color(red: 0.92, green: 0, blue: 0) }

    private var statusText: String {
        if let running = day.runningInterval {
            return "Eingestempelt seit \(TimeFormat.clock(running.start))"
        }
        if day.finished, let end = day.lastEnd {
            return "Ausgestempelt um \(TimeFormat.clock(end))"
        }
        if let end = day.lastEnd {
            return "Pause seit \(TimeFormat.clock(end))"
        }
        return "Heute noch nicht gestempelt"
    }

    private var statusIcon: String {
        if day.isRunning { return "record.circle" }
        if day.finished { return "checkmark.circle" }
        if day.lastEnd != nil { return "pause.circle" }
        return "clock"
    }

    private var statusColor: Color {
        if day.isRunning { return .green }
        if day.finished { return .secondary }
        if day.lastEnd != nil { return .orange }
        return .secondary
    }

    // MARK: Body
    var body: some View {
        Form {
            headerSection
            stampSection
            statsSection
            intervalSection
            sollSection
        }
        .sensoryFeedback(.impact, trigger: stampCount)
        .onAppear {
            showCustomTime = !presets.contains(where: { $0.min == day.sollMinutes })
        }
    }

    // MARK: Kopf mit Feierabend-Uhrzeit
    private var headerSection: some View {
        Section {
            VStack(spacing: 6) {
                Text(done ? "Feierabend war um" : "Feierabend um")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(endMinutes.map(TimeFormat.clock) ?? "--:--")
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
                    .foregroundStyle(accent)
                    .contentTransition(.numericText())

                if done {
                    Text("Sollzeit erreicht — schönen Feierabend! 🎉")
                        .font(.subheadline)
                } else if endMinutes == nil {
                    Text("Stemple dich ein, um zu starten")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if day.isRunning {
                    Text("noch \(TimeFormat.duration(remaining))")
                        .font(.subheadline)
                } else {
                    Text("noch \(TimeFormat.duration(remaining)) — wenn du jetzt weitermachst")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                ProgressView(value: day.progress(now: nowMinutes))
                    .tint(accent)
                    .padding(.top, 8)
                HStack {
                    Text(day.firstStart.map(TimeFormat.clock) ?? "--:--")
                    Spacer()
                    Text("\(Int(day.progress(now: nowMinutes) * 100)) %")
                    Spacer()
                    Text(endMinutes.map(TimeFormat.clock) ?? "--:--")
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: Stempeluhr
    private var stampSection: some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                Text(statusText)
                    .font(.subheadline)
                Spacer()
            }

            if day.isRunning {
                HStack(spacing: 12) {
                    Button {
                        stamp { day.punchOut(at: nowMinutes, asFeierabend: false) }
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.orange)

                    Button {
                        stamp { day.punchOut(at: nowMinutes, asFeierabend: true) }
                    } label: {
                        Label("Feierabend", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.red)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button {
                    stamp { day.punchIn(at: nowMinutes) }
                } label: {
                    Label(
                        day.intervals.isEmpty ? "Jetzt einstempeln" : "Weiter arbeiten",
                        systemImage: "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.green)
            }
        } header: {
            Text("Stempeluhr")
        } footer: {
            Text("„Pause“ und „Feierabend“ stempeln beide aus – der Unterschied ist nur die Anzeige.")
        }
    }

    // MARK: Kennzahlen
    private var statsSection: some View {
        Section("Heute") {
            HStack(spacing: 0) {
                stat(title: "Geleistet", value: TimeFormat.duration(worked), tint: accent)
                Divider().frame(height: 40)
                stat(title: "Pause", value: TimeFormat.duration(pause), tint: .primary)
                Divider().frame(height: 40)
                if done {
                    stat(title: "Überstunden", value: TimeFormat.duration(day.overtimeMinutes(now: nowMinutes)), tint: .green)
                } else {
                    stat(title: "Verbleibend", value: TimeFormat.duration(remaining), tint: .primary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: Stempelungen
    private var intervalSection: some View {
        Section {
            if day.intervals.isEmpty {
                Text("Noch keine Stempelungen heute.")
                    .foregroundStyle(.secondary)
            }

            ForEach(day.sortedIntervals) { interval in
                IntervalRow(interval: binding(for: interval.id), now: nowMinutes)
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
                Label("Eintrag manuell hinzufügen", systemImage: "plus.circle")
            }
        } header: {
            HStack {
                Text("Stempelungen")
                Spacer()
                Text("\(day.intervals.count) Abschnitt\(day.intervals.count == 1 ? "" : "e")")
            }
        } footer: {
            Text("Zeiten lassen sich direkt antippen und korrigieren. Zum Löschen nach links wischen.")
        }
    }

    // MARK: Sollzeit
    private var sollSection: some View {
        Section("Sollzeit heute") {
            HStack(spacing: 8) {
                ForEach(presets, id: \.min) { p in
                    Button(p.label) { day.sollMinutes = p.min }
                        .buttonStyle(.bordered)
                        .tint(day.sollMinutes == p.min ? accent : .gray)
                        .font(.system(.subheadline, design: .monospaced))
                }
            }
            DisclosureGroup(isExpanded: $showCustomTime) {
                DurationWheelPicker(minutes: $day.sollMinutes)
            } label: {
                HStack {
                    Text("Eigene Zeit")
                    Spacer()
                    Text(TimeFormat.duration(day.sollMinutes))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Helfer
    private func stamp(_ action: () -> Void) {
        withAnimation { action() }
        stampCount += 1
    }

    /// Binding über die id statt über den Index – so greift es beim Löschen nicht ins Leere.
    private func binding(for id: UUID) -> Binding<WorkInterval> {
        Binding {
            day.intervals.first { $0.id == id } ?? WorkInterval(start: 0, end: nil)
        } set: { newValue in
            guard let index = day.intervals.firstIndex(where: { $0.id == id }) else { return }
            day.intervals[index] = newValue
        }
    }

    private func stat(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - IntervalRow
struct IntervalRow: View {
    @Binding var interval: WorkInterval
    let now: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                MinutePicker(minutes: $interval.start)

                Text("–")
                    .foregroundStyle(.secondary)

                if let end = Binding($interval.end) {
                    MinutePicker(minutes: end)
                } else {
                    Text("läuft …")
                        .foregroundStyle(.green)
                    Button {
                        interval.end = max(interval.start, now)
                    } label: {
                        Image(systemName: "stop.circle")
                    }
                    .buttonStyle(.borderless)
                }

                Spacer(minLength: 4)

                Text(TimeFormat.duration(interval.duration(now: now)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            if let end = interval.end, end < interval.start {
                Text("Ende liegt vor dem Beginn")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }
}

#Preview {
    ContentView()
}
