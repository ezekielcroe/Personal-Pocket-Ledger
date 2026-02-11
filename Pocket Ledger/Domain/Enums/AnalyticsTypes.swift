//
//  AnalyticsTypes.swift
//  Pocket Ledger
//
//

import Foundation

// MARK: - Time Range

/// The time window a user has selected for the Insights view.
/// Each case maps to a human-readable label shown in the segmented picker,
/// and knows how to compute its own DateInterval given an anchor date,
/// a fiscal start day, and a signed offset (0 = current, -1 = previous, etc.).
enum TimeRange: String, CaseIterable, Identifiable, Hashable {
    case thisWeek  = "Week"
    case thisMonth = "Month"
    case thisYear  = "Year"
    case allTime   = "All Time"
    
    var id: String { rawValue }
    
    /// Returns the DateInterval for this range, shifted by `offset` periods.
    ///
    /// - Parameters:
    ///   - anchor: The reference date (typically `Date()`). Used to determine
    ///             which week/month/year "this" refers to.
    ///   - fiscalStartDay: The day of the month on which a fiscal month begins (1–28).
    ///                     Only applies to `.thisMonth` and `.thisYear`.
    ///   - offset: Integer shift. 0 = the current period containing `anchor`,
    ///             -1 = the previous period, 1 = the next period, etc.
    func dateInterval(relativeTo anchor: Date, fiscalStartDay: Int, offset: Int) -> DateInterval {
        let calendar = Calendar.current
        let clampedFiscalDay = max(1, min(fiscalStartDay, 28))
        
        switch self {
            
        // MARK: Week
        case .thisWeek:
            // ISO week: Monday → Sunday
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: anchor) else {
                return DateInterval(start: anchor, duration: 0)
            }
            let offsetSeconds = TimeInterval(offset) * 7 * 24 * 60 * 60
            return DateInterval(
                start: weekInterval.start.addingTimeInterval(offsetSeconds),
                end:   weekInterval.end.addingTimeInterval(offsetSeconds)
            )
            
        // MARK: Month (fiscal-aware)
        case .thisMonth:
            // Find the most recent fiscal start on or before `anchor`, then shift by `offset` months.
            let anchorComponents = calendar.dateComponents([.year, .month, .day], from: anchor)
            let anchorDay = anchorComponents.day ?? 1
            
            // Determine whether the fiscal month that contains `anchor` started this calendar month
            // or last calendar month.
            let fiscalStartThisCalMonth = calendar.date(from: DateComponents(
                year: anchorComponents.year,
                month: anchorComponents.month,
                day: clampedFiscalDay
            )) ?? anchor
            
            // If anchor is before this calendar month's fiscal start, the fiscal month
            // started in the *previous* calendar month.
            let currentFiscalMonthStart: Date
            if anchorDay >= clampedFiscalDay {
                currentFiscalMonthStart = fiscalStartThisCalMonth
            } else {
                currentFiscalMonthStart = calendar.date(
                    byAdding: .month, value: -1, to: fiscalStartThisCalMonth
                ) ?? fiscalStartThisCalMonth
            }
            
            // Shift by offset months
            let shiftedStart = calendar.date(
                byAdding: .month, value: offset, to: currentFiscalMonthStart
            ) ?? currentFiscalMonthStart
            
            let shiftedEnd = calendar.date(
                byAdding: .month, value: 1, to: shiftedStart
            ) ?? shiftedStart
            
            return DateInterval(start: shiftedStart, end: shiftedEnd)
            
        // MARK: Year (fiscal-aware)
        case .thisYear:
            // Fiscal year starts on `fiscalStartDay` of January (or configurable — here we use Jan).
            let anchorYear = calendar.component(.year, from: anchor)
            
            let fiscalYearStart = calendar.date(from: DateComponents(
                year: anchorYear,
                month: 1,
                day: clampedFiscalDay
            )) ?? anchor
            
            // If anchor is before this year's fiscal start, the fiscal year started last year.
            let currentFiscalYearStart: Date
            if anchor >= fiscalYearStart {
                currentFiscalYearStart = fiscalYearStart
            } else {
                currentFiscalYearStart = calendar.date(
                    byAdding: .year, value: -1, to: fiscalYearStart
                ) ?? fiscalYearStart
            }
            
            let shiftedStart = calendar.date(
                byAdding: .year, value: offset, to: currentFiscalYearStart
            ) ?? currentFiscalYearStart
            
            let shiftedEnd = calendar.date(
                byAdding: .year, value: 1, to: shiftedStart
            ) ?? shiftedStart
            
            return DateInterval(start: shiftedStart, end: shiftedEnd)
            
        // MARK: All Time
        case .allTime:
            // Offset has no meaning for "all time" — always return the full span.
            return DateInterval(start: .distantPast, end: .distantFuture)
        }
    }
}

// MARK: - Breakdown Mode

/// How the spending breakdown chart groups its bars in the Insights view.
enum BreakdownMode: String, CaseIterable, Identifiable, Hashable {
    case category = "Category"
    case account  = "Account"
    case group    = "Group"
    case tag      = "Tag"
    
    var id: String { rawValue }
}
