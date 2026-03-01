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
    
    // MARK: - Identifier Helper
    
    private static func identifier(for templateID: UUID, bookID: UUID) -> String {
        "\(bookID.uuidString)_\(templateID.uuidString)"
    }
    
    // MARK: - Scheduling (Private)
    
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
    
    // MARK: - Purge & Reschedule (Nuclear cleanup — call on app launch)
    
    /// Removes ALL pending and delivered notifications for this book from the
    /// iOS system, then re-schedules only the ones that should exist based on
    /// current template data.
    ///
    /// This guarantees no ghost notifications survive from old code or
    /// interrupted cleanup attempts. Safe to call on every app launch.
    func purgeAndReschedule(for templates: [TransactionTemplate], bookID: UUID) {
        let center = UNUserNotificationCenter.current()
        let currentBookPrefix = bookID.uuidString + "_"
        
        // Step 1: Ask iOS for everything currently pending
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            
            // Step 2: Remove ALL notifications belonging to this book (no exceptions)
            let allBookIDs = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix(currentBookPrefix) }
            
            if !allBookIDs.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: allBookIDs)
            }
            
            // Step 3: Also clear any delivered notifications sitting in the tray
            center.getDeliveredNotifications { delivered in
                let deliveredBookIDs = delivered
                    .map { $0.request.identifier }
                    .filter { $0.hasPrefix(currentBookPrefix) }
                
                if !deliveredBookIDs.isEmpty {
                    center.removeDeliveredNotifications(withIdentifiers: deliveredBookIDs)
                }
            }
            
            // Step 4: Re-schedule only templates that currently have an active reminder
            for template in templates {
                if let schedule = template.reminderSchedule {
                    self.scheduleNotification(for: template, schedule: schedule, bookID: bookID)
                }
            }
        }
    }
    
    // MARK: - Incremental Update (for individual changes during a session)
    
    /// Diffs current notifications against the template list: removes stale
    /// ones, then schedules or replaces valid ones.
    /// Used when adding/editing/deleting a single template mid-session.
    func updateReminders(for templates: [TransactionTemplate], bookID: UUID) {
        let center = UNUserNotificationCenter.current()
        let currentBookPrefix = bookID.uuidString + "_"
        
        // Build the set of notification IDs that SHOULD exist
        let validIDs = Set(
            templates
                .filter { $0.reminderSchedule != nil }
                .map { Self.identifier(for: $0.id, bookID: bookID) }
        )
        
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            
            // Remove notifications belonging to this book that are no longer valid
            let staleIDs = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix(currentBookPrefix) && !validIDs.contains($0) }
            
            if !staleIDs.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: staleIDs)
            }
            
            // Schedule (or replace) all templates that have an active reminder.
            // center.add() with the same identifier replaces the old request.
            for template in templates {
                if let schedule = template.reminderSchedule {
                    self.scheduleNotification(for: template, schedule: schedule, bookID: bookID)
                }
            }
        }
    }
    
    // MARK: - Single Removal (for quick cleanup on delete or toggle-off)
    
    func removeReminder(for templateID: UUID, bookID: UUID) {
        let identifier = Self.identifier(for: templateID, bookID: bookID)
        let center = UNUserNotificationCenter.current()
        
        // Remove both pending (future) and delivered (in tray) for this template
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}
