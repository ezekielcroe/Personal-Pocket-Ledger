# Technical Documentation: Pocket Ledger

**Version:** 1.2

**Platform:** iOS 16.0+

**Language:** Swift 5 / SwiftUI

**Architecture:** MVVM (Model-View-ViewModel) with Multi-Tenant In-Memory Persistence

---

## 1. Executive Summary

Pocket Ledger is a manual-entry personal finance application designed for privacy and speed. It operates entirely offline, storing data locally on the device. Version 1.2 introduces a multi-tenant "Books" architecture, allowing users to maintain separate financial containers.

The application utilizes a monolithic JSON persistence strategy per book. Upon selection, the entire dataset for a specific book is loaded into RAM (AppData view model). This architectural choice prioritizes read-speed and UI responsiveness over write-efficiency, making it highly performant for datasets under 20,000 transactions per book.

### Design Philosophy

Pocket Ledger is built as a **flexible blank canvas** that supports both casual and power users:

- **Casual users** can use it as a simple expense tracker with minimal structure (basic accounts + activity classification)
- **Power users** can leverage it for sophisticated envelope budgeting, goal tracking, and multi-dimensional financial analysis

The app has an opinionated architecture: **accounts are the top-level organizing principle**, not categories. This enables envelope budgeting workflows that traditional category-first apps cannot support.

---

## 2. Data Architecture

### 2.1 Persistence Model (Multi-Tenant)

The persistence layer manages two distinct data types to support separate "Books":

* **Book Index:** A central `book_index.json` file tracks metadata for all created books and identifies the last active book.
* **Book Data:** Each book's contents (transactions, accounts, etc.) are stored in a unique JSON file named `book_[UUID].json`.
* **Loading Logic:** The Index is loaded at launch to determine the active file. The specific book data is then decoded asynchronously using `Task.detached` to prevent Main Thread blocking.
* **Saving Logic:** Writes are atomic and performed on a background thread. `AppData` snapshots the current state and serializes it to the specific URL associated with the `activeBook`.

### 2.2 Core Data Models

All models conform to `Identifiable`, `Codable`, `Hashable`, and `Sendable`.

#### BookMetadata
Stores lightweight header info (Name, UUID, Last Opened) to list books without loading full transaction histories.

#### Transaction
Primary entity. Uses a custom lexicographical string ID (`yyyyMMddHHmmSSS` + random suffix) for chronological sorting and thread safety.

**Key Fields:**
- `amount`: Decimal value
- `accountId`: Source account (mandatory)
- `activityId`: Activity classification (mandatory) - see Activities section
- `tagIds`: Array of tag references (optional)
- `note`: Text annotation (optional)
- `date`: Transaction timestamp

#### Account
Financial containers representing both real and virtual money locations.

**Types:**
- **Cash/Debit:** Standard accounts (checking, savings, cash)
- **Credit/Debt:** Accounts with negative balances and optional limits
- **Budget Accounts:** Virtual envelopes with spending targets
- **Goal Accounts:** Accumulation targets with goal amounts

**Key Fields:**
- `name`: Display name
- `type`: Account type enum
- `balance`: Current balance (calculated from transactions)
- `target`: Optional budget limit or goal amount
- `isCredit`: Boolean for visual debt/limit distinction
- `groupId`: Optional reference to parent account group

#### Account Groups
Optional organizational layer that pools balances of child accounts. Users define their own semantic meaning (e.g., "Real Accounts", "Monthly Budgets", "Savings Goals", "Projects").

**Key Characteristics:**
- Groups are themselves a special type of account
- Provide aggregated balance view of member accounts
- No enforced taxonomy - users create structure as needed
- Fully optional - accounts can exist without groups

#### Activity (formerly Category)
Classifies the economic nature of transactions for cross-account analysis. Mandatory field that identifies what type of economic activity occurred.

**Purpose:**
- Enable spending pattern analysis across all accounts
- Answer questions like "How much did I spend on groceries total?" when purchases span multiple budget accounts
- Provide tax-relevant classifications (Healthcare, Business Expenses, etc.)

**Key Fields:**
- `name`: Activity name (e.g., "Groceries", "Transportation", "Income - Employment")
- `type`: ActivityType (inflow/outflow)
- `emoji`: Optional icon support

**Design Note:** Activities do NOT have budgets. Budgets belong to accounts. Activities are purely for classification and reporting.

#### Tag
Auxiliary labels for multi-dimensional filtering and metadata.

**Common Use Cases:**
- Store/vendor tracking (`#whole-foods`, `#target`, `#amazon`)
- Project tracking (`#kitchen-remodel`, `#vacation-japan`)
- Person tracking (`#gift-mom`, `#reimbursable`)
- Lifecycle tracking (`#tax-deductible`, `#recurring`, `#business`)

**Relationship:** Many-to-many with transactions (one transaction can have multiple tags).

---

## 3. The Three-Layer Organization System

Pocket Ledger provides three complementary dimensions for organizing financial data:

### Layer 1: ACCOUNTS (Where?)
**Purpose:** Money allocation and budget execution

**Answers:**
- "Am I staying within my budgets?"
- "How much is left in my Food Budget?"
- "Am I on track to my Emergency Fund goal?"

**Usage:**
- Primary organizing structure
- Represents both real accounts (checking, credit cards) and virtual accounts (budget envelopes, savings goals)
- Budgets and targets live here, not on activities
- Optional grouping for aggregated views

### Layer 2: ACTIVITIES (What?)
**Purpose:** Economic classification and spending pattern analysis

**Answers:**
- "What am I actually spending money on?"
- "How much do I spend on food across ALL my accounts?"
- "What's my biggest spending category this year?"

**Usage:**
- Mandatory field on all transactions
- Cross-account analysis layer
- Shows true spending patterns even when budget accounts run out and spending shifts to other accounts
- No budget targets (use accounts for budgeting)

### Layer 3: TAGS (Details?)
**Purpose:** Granular metadata and multi-dimensional filtering

**Answers:**
- "How much did I spend at Whole Foods?"
- "What did my kitchen remodel project cost?"
- "How much did I spend on gifts for Mom this year?"

**Usage:**
- Optional, multi-select metadata
- Enables cross-cutting analysis (all `#tax-deductible` expenses across activities and accounts)
- Freeform - users create as needed

---

## 4. Core Modules & Logic

### 4.1 Transaction Management

* **Dual-Entry Transfers:** Transfers are perceived as a single action but internally generate an outflow from the source and an inflow to the destination.
* **Math Engine:** The Amount field supports inline arithmetic (e.g., "12.50+5") evaluated via `NSExpression`.
* **Batch Entry:** Supports "Save & Add Another" workflow, resetting the amount and tags while preserving account and date context for rapid data entry.

### 4.2 Multi-Dimensional Reporting

The three-layer system enables sophisticated analysis:

**Account Reports:** Budget performance and goal tracking
- "Food Budget: $437/$500 (87% used)"
- "Emergency Fund: $7,200/$10,000 goal"

**Activity Reports:** Spending patterns across accounts
- "Groceries: $562 total"
  - `$500 from Food Budget`
  - `$62 from Discretionary`
- Reveals when budget categories are under-funded

**Tag Reports:** Detailed breakdowns
- "All #vacation-japan spending: $3,247"
- "Tax-deductible expenses: $8,934"
- "Whole Foods: $1,234 (across all activities)"

**Combined Filtering:** Users can intersect dimensions
- "Show Groceries activity from Discretionary account with #organic tag"

### 4.3 UI/UX Standards

* **Reachability (Thumb-Friendly):** Critical actions follow a bottom-heavy layout. Primary "Save" buttons are full-width sticky footers, while "Cancel" actions are positioned at the top of the screen.
* **Floating Action Button (FAB):** Creation buttons are positioned in the bottom-right corner of list views for single-thumb access.
* **Visual Feedback:** The Amount field is color-coded by transaction type (Green for Inflow, Blue for Transfer, Primary for Outflow) to provide immediate cognitive confirmation.
* **Half-Menu Detents:** Selection interfaces (Accounts, Activities, Tags) utilize sheets with `.medium` presentation detents, keeping selection controls within the bottom half of the device.

### 4.4 Security & Safety

* **Interactive Dismissal:** Destructive swipe-down gestures on sheets are disabled via `.interactiveDismissDisabled()` to prevent accidental data loss during entry.
* **Biometrics:** Optional FaceID/TouchID protection for app access.

---

## 5. Data Portability

* **Backup (JSON):** Exports a full snapshot of the active book, including accounts, activities, and templates.
* **Restore:** Imports JSON backups to overwrite the current active book.
* **Report (CSV):** Exports human-readable tables for external analysis.

---

## 6. Performance Thresholds

The application is optimized for speed per book but has known scalability limits due to its In-Memory architecture.

| Metric | Threshold | Consequence |
| --- | --- | --- |
| **Transaction Count** | ~20,000 (per book) | App launch/load time may exceed 2 seconds. |
| **JSON File Size** | ~5-10 MB | Background saves may cause CPU spikes. |
| **Memory Usage** | Negligible | Typically <50MB, well within iOS limits. |

**Recommendation:** If a single book exceeds 20,000 transactions, users should utilize the "Books" feature to archive older data into a separate container (e.g., "2025 Archive").

---

## 7. Architectural Trade-offs

### What This Architecture Enables

**Account-First Design:**
- Envelope budgeting with virtual accounts
- Complex goal tracking (multiple simultaneous savings goals)
- Project-specific budgets (dedicated accounts)
- Flexible user-defined structures via account groups
- Natural representation of real-world money movement (transfers)

**In-Memory Performance:**
- Instant UI responsiveness (no database queries)
- Simple state management (single source of truth)
- Deterministic performance (no query optimization needed)

**Offline-First Privacy:**
- Zero network dependencies = zero sync bugs
- Complete data ownership
- No authentication complexity
- Minimal attack surface

### What This Architecture Sacrifices

**Scalability:**
- 20K transaction limit per book (mitigated by multi-book support)
- Full-file rewrites on save (vs incremental updates)
- Not suitable for enterprise/business accounting

**Category-Based Budgeting:**
- Activities cannot have budget targets
- Users expecting Mint-style category budgets must use accounts instead
- Requires mental model shift from traditional apps

**Automatic Categorization:**
- Manual entry only (no bank imports)
- No AI-assisted activity classification
- Trade-off for privacy and offline operation

---

## 8. Design Principles

### Blank Canvas Philosophy
The app provides minimal defaults and maximum flexibility. Users discover features organically through use rather than forced tutorials.

**Required Fields:**
- Transaction: Amount + Account only
- Account: Name + Type only
- Activity: Name + Type only

**Optional Structure:**
- Account groups (user-defined)
- Tags (freeform)
- Notes, attachments, custom fields

### Progressive Complexity
- **Casual users:** Can use as simple expense tracker (1 account + activities)
- **Intermediate users:** Add budget accounts and basic goals
- **Power users:** Create complex multi-group structures with projects and sinking funds

The system doesn't force structure but supports arbitrary complexity when needed.

### Opinionated but Flexible
**Strong opinions:**
- Accounts are the budget layer (not activities)
- Activities are mandatory (economic classification matters)
- Privacy over convenience (offline-only)

**Flexibility:**
- No enforced account taxonomy
- User-defined semantic meaning for groups
- Freeform tag system
- Multiple books for different contexts

---

## 9. Use Case Examples

### Minimalist Tracking
```
Accounts:
  - Checking
  - Credit Card

Transactions:
  $47 | Checking | Groceries
  $12 | Credit Card | Coffee
```

### Envelope Budgeting
```
Account Groups:
  Real Money
    └─ Checking: $3,240
  
  Monthly Envelopes
    └─ Food Budget: $437/$500
    └─ Transport: $245/$300
    └─ Entertainment: $89/$150

Workflow:
  1. Transfer $950 from Checking to envelopes (monthly allocation)
  2. Spend from envelope accounts
  3. Track performance against targets
```

### Goal Tracking
```
Account Groups:
  Savings Goals
    └─ Emergency Fund: $7,200/$10,000
    └─ House Down Payment: $45,000/$80,000
    └─ Vacation: $1,450/$3,000

Transactions:
  Monthly contributions from income
  Track progress toward multiple goals
```

### Project Budgeting
```
Accounts:
  Kitchen Remodel (budget account, $15,000 target)

Transactions:
  $3,400 | Kitchen Remodel | Home Improvement | #contractor
  $890 | Kitchen Remodel | Shopping | #home-depot, #cabinets
  
Analysis:
  Account view: $4,290/$15,000 spent
  Tag view: #contractor = $3,400, #home-depot = $890
```

### Cross-Account Analysis
```
Scenario: Food Budget depleted mid-month

Transactions:
  $500 | Food Budget | Groceries (budget exhausted)
  $62 | Discretionary | Groceries (overflow spending)

Account Report:
  Food Budget: 100% used ✓
  Discretionary: 21% used ✓
  (Both look healthy individually)

Activity Report:
  Groceries: $562 total
  → Reveals $62 over-budget on food spending
```

---

## 10. Target User Profiles

### Supported Well
- Envelope budgeters (YNAB-style workflow)
- Privacy-focused individuals (offline requirement)
- Zero-based budgeting practitioners
- People with complex savings goals
- Manual entry enthusiasts (prefer control over automation)
- Users who think spatially about money allocation

### Not Ideal For
- Users expecting bank import/sync
- Category-based budgeters (Mint mental model)
- People wanting automatic categorization
- Business/enterprise accounting needs
- Users requiring multi-device cloud sync
- Casual "set and forget" tracking

---

*Last updated: January 2026*