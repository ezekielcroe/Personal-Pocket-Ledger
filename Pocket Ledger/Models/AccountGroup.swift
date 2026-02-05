//
//  AccountGroup.swift
//  Pocket Ledger
//
//  Enhanced with recursive nesting support
//

import Foundation

struct AccountGroup: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    
    /// Unified container for both accounts and nested groups
    var memberIDs: [UUID]
    
    init(id: UUID = UUID(), name: String, memberIDs: [UUID] = []) {
        self.id = id
        self.name = name
        self.memberIDs = memberIDs
    }
}

// MARK: - Member Type Identification

enum MemberType {
    case account(Account)
    case group(AccountGroup)
    
    var id: UUID {
        switch self {
        case .account(let account):
            return account.id
        case .group(let group):
            return group.id
        }
    }
    
    var name: String {
        switch self {
        case .account(let account):
            return account.name
        case .group(let group):
            return group.name
        }
    }
}

// MARK: - Helper Functions

extension AccountGroup {
    // CONSTANT: Safety limit to prevent stack overflows
    private static let maxRecursionDepth = 5
    
    /// Returns the depth of nesting for this group (0 = top-level)
    func depth(in allGroups: [AccountGroup]) -> Int {
        var maxDepth = 0
        
        for memberID in memberIDs {
            if let childGroup = allGroups.first(where: { $0.id == memberID }) {
                // Note: Simple depth check doesn't strictly need the limit guard
                // as much as the recursive collector, but good to be aware.
                let childDepth = childGroup.depth(in: allGroups)
                maxDepth = max(maxDepth, childDepth + 1)
            }
        }
        
        return maxDepth
    }
    
    /// Returns all UNIQUE account IDs contained in this group (recursive)
    /// Returns a Set to prevent double-counting
    func allAccountIDs(in allGroups: [AccountGroup],
                       accounts: [Account],
                       visited: Set<UUID> = [],
                       currentDepth: Int = 0) -> Set<UUID> {
        
        // SAFETY GUARD: Stop recursion if we hit the limit
        guard currentDepth < AccountGroup.maxRecursionDepth else {
            print("⚠️ Max group depth reached for \(name). Stopping recursion.")
            return []
        }
        
        var result: Set<UUID> = []
        
        // Cycle safety
        var newVisited = visited
        newVisited.insert(self.id)
        
        for memberID in memberIDs {
            // Check if it's an account
            if accounts.contains(where: { $0.id == memberID }) {
                result.insert(memberID)
            }
            // Check if it's a group (recurse)
            else if let childGroup = allGroups.first(where: { $0.id == memberID }) {
                // Only recurse if we haven't visited this group in this chain
                if !visited.contains(childGroup.id) {
                    // Pass incremented depth
                    result.formUnion(childGroup.allAccountIDs(in: allGroups,
                                                              accounts: accounts,
                                                              visited: newVisited,
                                                              currentDepth: currentDepth + 1))
                }
            }
        }
        
        return result
    }
    
    /// Checks if adding a member would create a cycle
    func wouldCreateCycle(byAdding candidateID: UUID,
                         in allGroups: [AccountGroup]) -> Bool {
        // If the candidate is this group itself, that's a cycle
        if candidateID == self.id {
            return true
        }
        
        // Check if the candidate is a group that contains this group (directly or indirectly)
        guard let candidateGroup = allGroups.first(where: { $0.id == candidateID }) else {
            return false  // Not a group, can't create cycle
        }
        
        return candidateGroup.containsGroup(self.id, in: allGroups)
    }
    
    /// Recursively checks if this group contains a specific group
    private func containsGroup(_ targetID: UUID, in allGroups: [AccountGroup]) -> Bool {
        // Direct membership check
        if memberIDs.contains(targetID) {
            return true
        }
        
        // Recursive check through child groups
        for memberID in memberIDs {
            if let childGroup = allGroups.first(where: { $0.id == memberID }) {
                if childGroup.containsGroup(targetID, in: allGroups) {
                    return true
                }
            }
        }
        
        return false
    }
}
