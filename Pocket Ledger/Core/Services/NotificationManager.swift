//
//  NotificationManager.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 10/2/26.
//

import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    // MARK: - Scheduling
    
    private func scheduleNotification(for template: TransactionTemplate, schedule: ReminderSchedule, bookID: UUID) {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "Record Transaction"
        content.body = "Time to record: \(template.name)"
        content.sound = .default
        
        content.userInfo = [
            "bookID": bookID.uuidString,
            "templateID": template.id.uuidString
        ]
        
        var dateComponents = DateComponents()
        dateComponents.hour = schedule.hour
        dateComponents.minute = schedule.minute
        
        switch schedule.frequency {
        case .daily:
            break
        case .weekly:
            dateComponents.weekday = schedule.dayOfWeek
        case .monthly:
            dateComponents.day = schedule.dayOfMonth
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let identifier = Self.identifier(for: template.id, bookID: bookID)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Identifier Helper
    
    private static func identifier(for templateID: UUID, bookID: UUID) -> String {
        "\(bookID.uuidString)_\(templateID.uuidString)"
    }
    
    // MARK: - Batch Update (The "Public" API)
    
    /// Synchronously removes all stale notifications for this book, then schedules valid ones.
    /// No Task wrapper — the caller is responsible for calling this on the right queue.
    func updateReminders(for templates: [TransactionTemplate], bookID: UUID) {
        let center = UNUserNotificationCenter.current()
        let currentBookPrefix = bookID.uuidString + "_"
        
        // 1. Build the set of notification IDs that SHOULD exist
        let validIDs = Set(
            templates
                .filter { $0.reminderSchedule != nil }
                .map { Self.identifier(for: $0.id, bookID: bookID) }
        )
        
        // 2. Query pending requests and remove stale ones
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            
            // Find notification IDs belonging to this book that are no longer valid
            let staleIDs = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix(currentBookPrefix) && !validIDs.contains($0) }
            
            if !staleIDs.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: staleIDs)
            }
            
            // 3. Schedule (or replace) all templates that have an active reminder
            for template in templates {
                if let schedule = template.reminderSchedule {
                    self.scheduleNotification(for: template, schedule: schedule, bookID: bookID)
                }
            }
        }
    }
    
    // MARK: - Single Removal (for quick cleanup on delete)
    
    func removeReminder(for templateID: UUID, bookID: UUID) {
        let identifier = Self.identifier(for: templateID, bookID: bookID)
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
