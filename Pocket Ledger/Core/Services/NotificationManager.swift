//
//  NotificationManager.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 10/2/26.
//

import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager() // Singleton is okay for system services

    // MARK: - Scheduling
    
    // CRITICAL FIX: We added 'bookID' as a parameter because this class
    // doesn't know what the "activeBook" is.
    func scheduleNotification(for template: TransactionTemplate, schedule: ReminderSchedule, bookID: UUID) {
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
        
        // We use the passed bookID here to create the unique ID
        let identifier = "\(bookID.uuidString)_\(template.id.uuidString)"
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Batch Update (The "Public" API)
    
    func updateReminders(for templates: [TransactionTemplate], bookID: UUID) {
        Task {
            let center = UNUserNotificationCenter.current()
            let requests = await center.pendingNotificationRequests()
            
            let currentBookPrefix = bookID.uuidString + "_"
            
            // 1. Clear old notifications for this specific book
            let idsToRemove = requests
                .filter { $0.identifier.hasPrefix(currentBookPrefix) }
                .map { $0.identifier }
            
            center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
            
            // 2. Schedule new ones
            for template in templates {
                if let schedule = template.reminderSchedule {
                    self.scheduleNotification(for: template, schedule: schedule, bookID: bookID)
                }
            }
        }
    }
}
