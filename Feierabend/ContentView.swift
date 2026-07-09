//
//  ContentView.swift
//  Feierabend
//
//  Created by Furkan Aydin on 09.07.2026.
//

import SwiftUI
internal import Combine

// MARK: - Model
struct Pause: Identifiable {
    let id = UUID()
    var minutes: Int
}

// MARK: - ContentView
struct ContentView: View {
    @State private var startTime: Date = Calendar.current.date(
        bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var sollMinutes: Int = 516 // 8 h 36 Standard
    @State private var pausen: [Pause] = [Pause(minutes: 30)]
    @State private var now: Date = Date()
    @FocusState private var keyboardActive: Bool

    private let timer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    private let presets: [(label: String, min: Int)] = [
        ("4 h 18", 258),
        ("8 h 00", 480),
        ("8 h 36", 516),
    ]

    // MARK: Berechnungen
    private var pauseTotal: Int { pausen.reduce(0) { $0 + $1.minutes } }

    private var startMinutes: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: startTime)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private var nowMinutes: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private var endMinutes: Int { startMinutes + sollMinutes + pauseTotal }
    private var remaining: Int { endMinutes - nowMinutes }
    private var done: Bool { remaining <= 0 }

    private var progress: Double {
        guard nowMinutes >= startMinutes else { return 0 }
        let worked = min(nowMinutes - startMinutes - pauseTotal, sollMinutes)
        return max(0, min(1, Double(worked) / Double(sollMinutes)))
    }

    private func fmt(_ minutes: Int) -> String {
        let m = ((minutes % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    private func fmtDur(_ minutes: Int) -> String {
        let m = abs(minutes)
        return "\(m / 60) h \(String(format: "%02d", m % 60)) min"
    }

    private var accent: Color { done ? .green : Color(red: 0.92, green: 0, blue: 0) }

    // MARK: Body
    var body: some View {
        NavigationStack {
            Form {
                // Ergebnis
                Section {
                    VStack(spacing: 6) {
                        Text(done ? "Feierabend war um" : "Feierabend um")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(fmt(endMinutes))
                            .font(.system(size: 56, weight: .bold, design: .monospaced))
                            .foregroundStyle(accent)
                            .contentTransition(.numericText())
                        if done {
                            Text("Zeit erreicht — schönen Feierabend! 🎉")
                                .font(.subheadline)
                        } else if nowMinutes < startMinutes {
                            Text("Arbeitsbeginn erst um \(fmt(startMinutes))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("noch \(fmtDur(remaining))")
                                .font(.subheadline)
                        }
                        ProgressView(value: progress)
                            .tint(accent)
                            .padding(.top, 8)
                        HStack {
                            Text(fmt(startMinutes))
                            Spacer()
                            Text("\(Int(progress * 100)) % geleistet")
                            Spacer()
                            Text(fmt(endMinutes))
                        }
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                // Arbeitsbeginn
                Section("Arbeitsbeginn") {
                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                }

                // Sollzeit
                Section("Sollzeit heute") {
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.min) { p in
                            Button(p.label) { sollMinutes = p.min }
                                .buttonStyle(.bordered)
                                .tint(sollMinutes == p.min ? accent : .gray)
                                .font(.system(.subheadline, design: .monospaced))
                        }
                    }
                    Stepper(value: $sollMinutes, in: 0...960, step: 6) {
                        Text("Eigene Zeit: \(fmtDur(sollMinutes))")
                            .monospacedDigit()
                    }
                }

                // Pausen
                Section {
                    ForEach($pausen) { $pause in
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
                    .onDelete { pausen.remove(atOffsets: $0) }

                    Button {
                        withAnimation { pausen.append(Pause(minutes: 15)) }
                    } label: {
                        Label("Pause hinzufügen", systemImage: "plus.circle")
                    }
                } header: {
                    HStack {
                        Text("Pausen")
                        Spacer()
                        Text("Total \(fmtDur(pauseTotal))")
                    }
                } footer: {
                    Text("Zum Löschen einer Pause nach links wischen.")
                }
            }
            .navigationTitle("Feierabend")
            .onReceive(timer) { now = $0 }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { keyboardActive = false }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
