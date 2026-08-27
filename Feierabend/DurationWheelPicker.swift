//
//  DurationWheelPicker.swift
//  Feierabend
//

import SwiftUI

/// Zwei Drehregler für Stunden und Minuten – im Stil der Wecker-/Timer-Eingabe der Uhr-App.
struct DurationWheelPicker: View {
    @Binding var minutes: Int

    var hourRange: ClosedRange<Int> = 0...16

    private var hours: Binding<Int> {
        Binding {
            min(max(minutes / 60, hourRange.lowerBound), hourRange.upperBound)
        } set: { newValue in
            minutes = newValue * 60 + minutes % 60
        }
    }

    private var singleMinutes: Binding<Int> {
        Binding {
            minutes % 60
        } set: { newValue in
            minutes = (minutes / 60) * 60 + newValue
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Spacer(minLength: 0)

            wheel(selection: hours, values: Array(hourRange))
                .accessibilityLabel("Stunden")
            unitLabel("Std.")

            wheel(selection: singleMinutes, values: Array(0...59))
                .accessibilityLabel("Minuten")
            unitLabel("Min.")

            Spacer(minLength: 0)
        }
        .frame(height: 150)
        .accessibilityElement(children: .contain)
    }

    private func wheel(selection: Binding<Int>, values: [Int]) -> some View {
        Picker("", selection: selection) {
            ForEach(values, id: \.self) { value in
                Text("\(value)")
                    .monospacedDigit()
                    .tag(value)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .frame(width: 72)
        .clipped()
    }

    private func unitLabel(_ text: String) -> some View {
        Text(text)
            .font(.body.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: 44, alignment: .leading)
            .accessibilityHidden(true)
    }
}

#Preview {
    @Previewable @State var minutes = 516
    Form {
        Section("Eigene Zeit") {
            DurationWheelPicker(minutes: $minutes)
            Text(TimeFormat.duration(minutes))
        }
    }
}
