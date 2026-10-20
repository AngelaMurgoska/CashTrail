import Foundation

/// Display helpers only. This is an extension, not stored data, so it has
/// no effect on the SwiftData schema.
extension Trip {
    /// "Oct 3, 2026" or, when the trip has an end date, "Oct 3, 2026 – Oct 10, 2026".
    var dateRangeText: String {
        let start = startDate.formatted(date: .abbreviated, time: .omitted)
        guard let endDate else { return start }
        return "\(start) – \(endDate.formatted(date: .abbreviated, time: .omitted))"
    }

    var receiptCountText: String {
        receipts.count == 1 ? "1 receipt" : "\(receipts.count) receipts"
    }
}
