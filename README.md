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

- **Where It Went** — Each period shows Income, then where it went across the pillars: **Spent**, **Saved** into Goals, **Debt paid**, and what's **Left over**. One-off purchases are shown separately, so an unusual month doesn't look like a bad one.
- **A Fair Comparison** — While a month is still in progress, it's compared with the same point last month, not with the whole of it. A trend chart marks your typical month.
- **Every Number Opens Up** — Tap any figure to see exactly the transactions behind it.
- **Know What to Trust** — If an account hasn't been verified in a while, or the period contains reconciliation plugs, Insights says so, rather than presenting shaky numbers as fact.
- **Multi-Ledger Isolation** — Keep Personal, Business, and Side-Hustle books strictly separate. Switching between ledgers is instant; the data never mixes.

### Categories, Remarks & Tags

Three independent dimensions, each answering a different question:

| | Answers | Example |
|---|---|---|
| **Category** | *What* — broad and permanent | Food, Housing, Transport |
| **Remark** | *Who* — the payee, in plain words | Starbucks, FairPrice, Client lunch |
| **#tag** (in the remark) | *Why* — a deliberate label | `#work`, `#datenight`, `#japantrip` |

Keep categories broad and remarks specific, and your charts stay readable at scale.

- **Buckets** group remarks under one name without a new category for every merchant: a `Coffee` bucket with the terms `starbucks`, `*bean` and `#coffee` gathers them all. Buckets are searches, not labels, so adding a term regroups your entire history instantly. The editor previews exactly which remarks a bucket catches.
- **Remark Lookup** — type any word or `#tag` on the Insights page to get its total, count, average and trend.

### Built for Day-to-Day Realities

- **Traffic Light Reconciliation** — Every account shows a Green, Yellow, or Red indicator based on how recently you verified the balance against your bank. You always know exactly how much you can trust your data.
- **The Plug** — If the app and your bank disagree by a few dollars, don't waste hours hunting for the discrepancy. The reconciliation tool calculates the difference and inserts an adjustment to close the gap. Plugs are kept out of your income and spending figures. *Perfection is the enemy of consistency.*

### Fast, Deliberate Capture

- **Math Engine** — Every amount field is a calculator. Splitting a $45.00 dinner? Type `45 / 2` and the result ($22.50) appears as you type.
- **Less Tapping, Same Thinking** — Your last-used account is pre-selected, your most-used categories are one tap away, and past remarks and #tags complete as you type. When a remark matches one you've used before, the form offers what you did last time — but never applies it without your tap.
- **Templates & Smart Reminders** — Save recurring transactions as templates. Attach a daily, weekly, or monthly reminder, and the notification deep-links straight into the pre-filled form.
- **Thumb-Friendly Design** — Built for one-handed use. Save, Add, and Cancel are always within reach of your thumb. "Save &" records one entry and starts the next.
- **Keyboard Shortcuts** — Full iPad and Mac keyboard navigation with `⌘1`, `⌘T`, `⌘A`, and more.

### Privacy First

Your data stays on your device. Pocket Ledger is offline-first and uses encrypted local storage. Your financial life is never sent to a third-party server without your explicit command.

- Export to **JSON** for a full backup you control.
- Export to **CSV** for tax records or your accountant.

---

## Getting Started

1. **Create your accounts** — mirror what you actually have: a checking account, any credit cards, savings goals, and any outstanding debts.
2. **Set up a few broad categories** — Housing, Food, Transport, Income. Five to eight is plenty.
3. **Record your first transaction** — tap `+`, choose Inflow, Outflow, or Transfer, type the amount, pick an account and category, and save. Write the payee in the remark; add a #tag if there's a reason worth tracking.
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
