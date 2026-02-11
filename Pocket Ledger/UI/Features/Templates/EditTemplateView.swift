//
//  EditTemplateView.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 17/1/26.
//


import SwiftUI

struct EditTemplateView: View {
    @EnvironmentObject var transactionStore: TransactionStore
    @Environment(\.dismiss) var dismiss
    
    @State var template: TransactionTemplate
    
    // Schedule State
    @State private var enableReminder: Bool = false
    @State private var frequency: ReminderSchedule.Frequency = .daily
    @State private var reminderTime: Date = Date()
    @State private var dayOfWeek: Int = 2 // Monday
    @State private var dayOfMonth: Int = 1
    
    init(template: TransactionTemplate) {
        _template = State(initialValue: template)
        
        // Initialize state from existing schedule if present
        if let schedule = template.reminderSchedule {
            _enableReminder = State(initialValue: true)
            _frequency = State(initialValue: schedule.frequency)
            _dayOfWeek = State(initialValue: schedule.dayOfWeek ?? 2)
            _dayOfMonth = State(initialValue: schedule.dayOfMonth ?? 1)
            
            let calendar = Calendar.current
            var components = DateComponents()
            components.hour = schedule.hour
            components.minute = schedule.minute
            let date = calendar.date(from: components) ?? Date()
            _reminderTime = State(initialValue: date)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Template Details")) {
                    TextField("Name", text: $template.name)
                }
                
                Section(header: Text("Smart Reminder")) {
                    Toggle("Enable Reminder", isOn: $enableReminder)
                    
                    if enableReminder {
                        Picker("Frequency", selection: $frequency) {
                            ForEach(ReminderSchedule.Frequency.allCases) { freq in
                                Text(freq.rawValue).tag(freq)
                            }
                        }
                        
                        if frequency == .weekly {
                            Picker("Day", selection: $dayOfWeek) {
                                Text("Sunday").tag(1)
                                Text("Monday").tag(2)
                                Text("Tuesday").tag(3)
                                Text("Wednesday").tag(4)
                                Text("Thursday").tag(5)
                                Text("Friday").tag(6)
                                Text("Saturday").tag(7)
                            }
                        }
                        
                        if frequency == .monthly {
                            Picker("Day of Month", selection: $dayOfMonth) {
                                ForEach(1...31, id: \.self) { day in
                                    Text("\(day)").tag(day)
                                }
                            }
                        }
                        
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }
                
                if enableReminder {
                    Section {
                        Text("Pocket Ledger will send a notification: 'Time to record: \(template.name)'")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formToolbar(title: "Edit Template") {
                save()
            } onCancel: {
                dismiss()
            }
        }
    }
    
    private func save() {
        if enableReminder {
            let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            let schedule = ReminderSchedule(
                frequency: frequency,
                hour: components.hour ?? 9,
                minute: components.minute ?? 0,
                dayOfWeek: frequency == .weekly ? dayOfWeek : nil,
                dayOfMonth: frequency == .monthly ? dayOfMonth : nil
            )
            template.reminderSchedule = schedule
        } else {
            template.reminderSchedule = nil
        }
        
        transactionStore.updateTemplate(template)
        dismiss()
    }
}
