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
    @FocusState private var keyboardActive: Bool

    private let presets: [(label: String, min: Int)] = [
        ("4 h 18", 258),
        ("8 h 00", 480),
        ("8 h 36", 516),
    ]

    // MARK: Berechnungen
    private var nowMinutes: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private var remaining: Int { day.endMinutes - nowMinutes }
    private var done: Bool { remaining <= 0 }

    private var progress: Double {
        guard nowMinutes >= day.startMinutes else { return 0 }
        let worked = min(nowMinutes - day.startMinutes - day.pauseTotal, day.sollMinutes)
        return max(0, min(1, Double(worked) / Double(day.sollMinutes)))
    }

    private var accent: Color { done ? .green : Color(red: 0.92, green: 0, blue: 0) }

    private var startTime: Binding<Date> {
        Binding {
            Calendar.current.date(
                bySettingHour: day.startMinutes / 60,
                minute: day.startMinutes % 60,
                second: 0, of: now) ?? now
        } set: { newValue in
            let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            day.startMinutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
    }

    // MARK: Body
    var body: some View {
        Form {
            // Ergebnis
            Section {
                VStack(spacing: 6) {
                    Text(done ? "Feierabend war um" : "Feierabend um")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(TimeFormat.clock(day.endMinutes))
                        .font(.system(size: 56, weight: .bold, design: .monospaced))
                        .foregroundStyle(accent)
                        .contentTransition(.numericText())
                    if done {
                        Text("Zeit erreicht — schönen Feierabend! 🎉")
                            .font(.subheadline)
                    } else if nowMinutes < day.startMinutes {
                        Text("Arbeitsbeginn erst um \(TimeFormat.clock(day.startMinutes))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("noch \(TimeFormat.duration(remaining))")
                            .font(.subheadline)
                    }
                    ProgressView(value: progress)
                        .tint(accent)
                        .padding(.top, 8)
                    HStack {
                        Text(TimeFormat.clock(day.startMinutes))
                        Spacer()
                        Text("\(Int(progress * 100)) % geleistet")
                        Spacer()
                        Text(TimeFormat.clock(day.endMinutes))
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            // Arbeitsbeginn
            Section("Arbeitsbeginn") {
                DatePicker("Start", selection: startTime, displayedComponents: .hourAndMinute)
            }

            // Sollzeit
            Section("Sollzeit heute") {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.min) { p in
                        Button(p.label) { day.sollMinutes = p.min }
                            .buttonStyle(.bordered)
                            .tint(day.sollMinutes == p.min ? accent : .gray)
                            .font(.system(.subheadline, design: .monospaced))
                    }
                }
                Stepper(value: $day.sollMinutes, in: 0...960, step: 6) {
                    Text("Eigene Zeit: \(TimeFormat.duration(day.sollMinutes))")
                        .monospacedDigit()
                }
            }

            // Pausen
            Section {
                ForEach($day.pausen) { $pause in
                    HStack {
                        Text("Pause")
                        Spacer()
                        TextField("min", value: $pause.minutes, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 56)
                            .textFieldStyle(.roundedBorder)
                            .monospacedDigit()
                            .focused($keyboardActive)
                        Text("min")
                            .foregroundStyle(.secondary)
                        Stepper("", value: $pause.minutes, in: 0...240, step: 1)
                            .labelsHidden()
                    }
                }
                .onDelete { day.pausen.remove(atOffsets: $0) }

                Button {
                    withAnimation { day.pausen.append(Pause(minutes: 15)) }
                } label: {
                    Label("Pause hinzufügen", systemImage: "plus.circle")
                }
            } header: {
                HStack {
                    Text("Pausen")
                    Spacer()
                    Text("Total \(TimeFormat.duration(day.pauseTotal))")
                }
            } footer: {
                Text("Zum Löschen einer Pause nach links wischen.")
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { keyboardActive = false }
            }
        }
    }
}

#Preview {
    ContentView()
}
