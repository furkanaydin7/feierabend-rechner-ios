//
//  MinutePicker.swift
//  Feierabend
//

import SwiftUI

/// Kompakter Uhrzeit-Picker, der auf Minuten seit Mitternacht arbeitet.
struct MinutePicker: View {
    @Binding var minutes: Int

    var body: some View {
        DatePicker("", selection: time, displayedComponents: .hourAndMinute)
            .labelsHidden()
    }

    private var time: Binding<Date> {
        Binding {
            let m = ((minutes % 1440) + 1440) % 1440
            return Calendar.current.date(
                bySettingHour: m / 60, minute: m % 60, second: 0, of: .now
            ) ?? .now
        } set: { newValue in
            minutes = TimeFormat.minutes(of: newValue)
        }
    }
}
