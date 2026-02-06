//
//  AppData+CRUD.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 5/2/26.
//

import Foundation
import Combine

extension AppData {
    // MARK: - CREATE Operations

    func addAccount(name: String,
                    initialAmount: Double,
                    isCredit: Bool = false,
                    targetAmount: Double? = nil,
                    targetDate: Date? = nil,
                    paymentFrequency: PaymentFrequency? = nil) {
        let account = Account(
            name: name,
            initialAmount: initialAmount,
            isCredit: isCredit,
            targetAmount: targetAmount,
            targetDate: targetDate,
            paymentFrequency: paymentFrequency
        )
        accounts.append(account)
        save()
    }
    
    func addAccountGroup(name: String, memberIDs: [UUID]) {
        let group = AccountGroup(name: name, memberIDs: memberIDs)
        accountGroups.append(group)
        save()
    }

    func addCategory(name: String, type: CategoryType, emoji: String) {
        let category = Category(name: name, type: type, emoji: emoji)
        categories.append(category)
        save()
    }

    func addTag(name: String, keywords: [String] = []) {
        let tag = Tag(name: name, keywords: keywords)
        tags.append(tag)
        save()
    }

    func addTransaction(id: String? = nil,
                        linkedTransactionID: String? = nil,
                        type: TransactionType,
                        accountID: UUID,
                        categoryID: UUID,
                        tagIDs: [UUID],
                        amount: Double,
                        date: Date,
                        isOutlier: Bool = false) {
        let transaction = Transaction(id: id,
                                      linkedTransactionID: linkedTransactionID,
                                      type: type,
                                      accountID: accountID,
                                      categoryID: categoryID,
                                      tagIDs: tagIDs,
                                      amount: amount,
                                      date: date,
                                      isOutlier: isOutlier)
        transactions.append(transaction)
        
        // Auto-Unarchive: If we use an account, it must be active.
        unarchiveAccountIfNeeded(id: accountID)
        
        save()
    }

    // MARK: - UPDATE & DELETE Operations

    func updateAccount(id: UUID,
                       name: String,
                       initialAmount: Double,
                       targetAmount: Double? = nil,
                       targetDate: Date? = nil,
                       paymentFrequency: PaymentFrequency? = nil) {
        if let index = accounts.firstIndex(where: { $0.id == id }) {
            accounts[index].name = name
            accounts[index].initialAmount = initialAmount
            accounts[index].targetAmount = targetAmount
            accounts[index].targetDate = targetDate
            accounts[index].paymentFrequency = paymentFrequency
            save()
        }
    }

    func deleteAccount(_ account: Account) {
        // 1. Remove from physical list
        accounts.removeAll { $0.id == account.id }
        
        // 2. Scrub reference from virtual groups
        for i in 0..<accountGroups.count {
            accountGroups[i].memberIDs.removeAll { $0 == account.id }
        }
        
        save()
    }
    
    func updateAccountGroup(_ group: AccountGroup) {
        if let index = accountGroups.firstIndex(where: { $0.id == group.id }) {
            accountGroups[index] = group
            save()
        }
    }
    
    func deleteAccountGroup(_ group: AccountGroup) {
        if let index = accountGroups.firstIndex(where: { $0.id == group.id }) {
            accountGroups.remove(at: index)
            save()
        }
    }

    func updateCategory(id: UUID, name: String, type: CategoryType, emoji: String) {
        if let index = categories.firstIndex(where: { $0.id == id }) {
            categories[index].name = name
            categories[index].type = type
            categories[index].emoji = emoji
            save()
        }
    }

    func updateTag(id: UUID, name: String, keywords: [String]) {
        if let index = tags.firstIndex(where: { $0.id == id }) {
            tags[index].name = name
            tags[index].keywords = keywords
            save()
        }
    }
    
    func updateTransaction(_ transaction: Transaction) {
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions[index] = transaction
            
            // Sync logic: Update partner if linked
            if let linkedID = transaction.linkedTransactionID,
               let linkedIndex = transactions.firstIndex(where: { $0.id == linkedID }) {
                
                var partner = transactions[linkedIndex]
                
                // Sync shared properties (Amount, Date, Tags, Outlier Status)
                partner.amount = transaction.amount
                partner.date = transaction.date
                partner.tagIDs = transaction.tagIDs
                partner.isOutlier = transaction.isOutlier
                
                // Save partner update
                transactions[linkedIndex] = partner
            }
            
            // Auto-Unarchive: Check the account in case it was changed to an archived one
            unarchiveAccountIfNeeded(id: transaction.accountID)
            
            save()
        }
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        // 1. Remove the target transaction
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions.remove(at: index)
        }
        
        // 2. Remove the linked partner if it exists
        if let linkedID = transaction.linkedTransactionID,
           let linkedIndex = transactions.firstIndex(where: { $0.id == linkedID }) {
            transactions.remove(at: linkedIndex)
        }
        
        save()
    }

    func removeTagFromTransactions(tagID: UUID) {
        for i in 0..<transactions.count {
            if transactions[i].tagIDs.contains(tagID) {
                transactions[i].tagIDs.removeAll { $0 == tagID }
            }
        }
        save()
    }
    
    // MARK: - Archive Operations (Public)

    func archiveAccount(_ account: Account) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index].archivedDate = Date()
            save()
        }
    }

    func unarchiveAccount(_ account: Account) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index].archivedDate = nil
            save()
        }
    }
    
    /// Helper to automatically unarchive an account if it is used in a new transaction
    private func unarchiveAccountIfNeeded(id: UUID) {
        if let index = accounts.firstIndex(where: { $0.id == id }) {
            if accounts[index].isArchived {
                accounts[index].archivedDate = nil
                // No save() here; it relies on the caller (addTransaction/updateTransaction) to save.
            }
        }
    }
    
    // MARK: - Preset Operations
    
    func savePreset(_ preset: InsightPreset) {
        if let index = insightPresets.firstIndex(where: { $0.id == preset.id }) {
            insightPresets[index] = preset
        } else {
            insightPresets.append(preset)
        }
        save()
    }
    
    func deletePreset(_ preset: InsightPreset) {
        insightPresets.removeAll { $0.id == preset.id }
        save()
    }
    
    // MARK: - Template Operations

    func addTemplate(name: String,
                     type: TransactionType,
                     accountID: UUID? = nil,
                     categoryID: UUID? = nil,
                     tagIDs: [UUID] = [],
                     isOutlier: Bool = false,
                     transferTargetAccountID: UUID? = nil) {
        let template = TransactionTemplate(name: name,
                                           type: type,
                                           accountID: accountID,
                                           categoryID: categoryID,
                                           tagIDs: tagIDs,
                                           isOutlier: isOutlier,
                                           transferTargetAccountID: transferTargetAccountID)
        templates.append(template)
        save()
    }
    
    func updateTemplate(_ template: TransactionTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
            save()
            updateReminders()
        }
    }

    func removeTemplate(_ template: TransactionTemplate) {
        templates.removeAll { $0.id == template.id }
        save()
        updateReminders()
    }
    
}
