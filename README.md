# Pocket Ledger

**A simple, offline personal finance app built on zero-budgeting principles.**

Pocket Ledger is designed for those who want to be active guardians of their wealth. While other finance apps try to do the work for you, the automation often leaves you disconnected from the reality of your balance. Pocket Ledger provides *helpful friction* — it asks you to pause, think, and record every transaction yourself.

The result is a diagnostic tool that helps you understand the *why* behind your money, reducing the decision fatigue and anxiety that so often comes with financial management.

---

## The Four Pillars

Your money is organised into four distinct account types, each built around a behavioural contract — whether money is for *Now* or the *Future*, and whether it is *Free* to spend or *Locked* away.

| Account | Role | Behaviour |
|---|---|---|
| **Debit** — The Liquid Hub | Your everyday "Now" money | Standard checking accounts and cash. Money flows freely in and out. |
| **Goal** — The Vault | Savings for the "Future" | Funds are locked until you reach your target, preventing the accidental leakage that quietly drains savings. |
| **Limit** — The Capacity Tank | A healthier view of credit | Tracks *available capacity* rather than debt. Your credit card is a finite envelope — spending depletes it, repayment refills it. |
| **Debt** — The Sink | A liability to be destroyed | Outflows are blocked. Every transfer in is a visible victory, shrinking the balance toward zero. |

---

## Features

### Intentional Insights

- **Smart Tags & Keyword Aliases** — Create thematic buckets like `#Caffeine` and attach keywords such as *Starbucks* or *Nespresso*. The app groups those searches automatically, so you never need a separate category for every merchant.
- **Categories & Tags together** — Categories answer *what* (Housing, Food, Transport). Tags answer *why* or *who* (#DateNight, #WorkExpense). Kept separate, they stay readable at scale.
- **Multi-Ledger Isolation** — Keep Personal, Business, and Side-Hustle books strictly separate. Switching between ledgers is instant; the data never mixes.

### Built for Day-to-Day Realities

- **Traffic Light Reconciliation** — Every account shows a Green, Yellow, or Red indicator based on how recently you verified the balance against your bank. You always know exactly how much you can trust your data.
- **The Plug** — If the app and your bank disagree by a few dollars, don't waste hours hunting for the discrepancy. The reconciliation tool calculates the difference and inserts an adjustment transaction to close the gap. *Perfection is the enemy of consistency.*

### Power Features

- **Math Engine** — Every amount field is a live calculator. Splitting a $45.00 dinner? Type `45 / 2` directly into the field.
- **Templates & Smart Reminders** — Save recurring transactions as templates. Attach a daily, weekly, or monthly reminder, and the notification deep-links straight into the pre-filled form.
- **Thumb-Friendly Design** — Built for one-handed use. Save, Add, and Cancel are always within reach of your thumb.
- **Keyboard Shortcuts** — Full iPad and Mac keyboard navigation with `⌘1`, `⌘T`, `⌘A`, and more.

### Privacy First

Your data stays on your device. Pocket Ledger is offline-first and uses encrypted local storage. Your financial life is never sent to a third-party server without your explicit command.

- Export to **JSON** for a full backup you control.
- Export to **CSV** for tax records or your accountant.

---

## Getting Started

1. **Create your accounts** — mirror what you actually have: a checking account, any credit cards, savings goals, and any outstanding debts.
2. **Set up a few broad categories** — Housing, Food, Transport, Income. Five to eight is plenty.
3. **Record your first transaction** — tap `+`, choose Inflow, Outflow, or Transfer, pick an account, and save.
4. **Reconcile weekly** — open your bank app, compare balances, and use the Reconcile tool if anything is off.

The built-in User Manual (tap **Help** in Settings) covers every feature in detail.

---

## Technical Notes

- **Platform:** iOS 17+
- **Language:** Swift / SwiftUI
- **Storage:** Local JSON with `.completeFileProtection` encryption at rest
- **No network access required**
- **No account or subscription required**

---

## License

This project is a personal project for learning. Copyright © 2026 Zhi Zheng Yeo
