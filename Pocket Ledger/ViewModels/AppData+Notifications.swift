import Foundation
@preconcurrency import UserNotifications

extension AppData {

    func updateReminders() {
        guard let currentBook = activeBook else { return }
        
        Task {
            let center = UNUserNotificationCenter.current()
            let requests = await center.pendingNotificationRequests()
            
            let currentBookPrefix = currentBook.id.uuidString + "_"
            
            let idsToRemove = requests
                .filter { $0.identifier.hasPrefix(currentBookPrefix) }
                .map { $0.identifier }
            
            center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
            
            for template in self.templates {
                if let schedule = template.reminderSchedule {
                    self.scheduleNotification(for: template, schedule: schedule)
                }
            }
        }
    }

    // Changed to 'internal' (default) so other AppData extensions can see it if needed,
    // though 'private' works if only called from updateReminders.
    func scheduleNotification(for template: TransactionTemplate, schedule: ReminderSchedule) {
        guard let currentBook = activeBook else { return }
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "Record Transaction"
        content.body = "Time to record: \(template.name)"
        content.sound = .default
        
        content.userInfo = [
            "bookID": currentBook.id.uuidString,
            "templateID": template.id.uuidString
        ]
        
        var dateComponents = DateComponents()
        dateComponents.hour = schedule.time.hour
        dateComponents.minute = schedule.time.minute
        
        switch schedule.frequency {
        case .daily:
            break
        case .weekly:
            dateComponents.weekday = schedule.dayOfWeek
        case .monthly:
            dateComponents.day = schedule.dayOfMonth
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let identifier = "\(currentBook.id.uuidString)_\(template.id.uuidString)"
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
}
