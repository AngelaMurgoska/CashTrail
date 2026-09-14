import Foundation
import SwiftData

@Model
final class Trip {
    var name: String
    var startDate: Date
    var endDate: Date?
    var notes: String?
    /// ISO 4217 currency code (e.g. "USD", "EUR"). All receipts in this trip
    /// are assumed to be in this currency — this doesn't convert values,
    /// it just controls how amounts are labeled/formatted.
    var currencyCode: String

    @Relationship(deleteRule: .cascade, inverse: \Receipt.trip)
    var receipts: [Receipt] = []

    init(
        name: String,
        startDate: Date = .now,
        endDate: Date? = nil,
        notes: String? = nil,
        currencyCode: String = Trip.defaultCurrencyCode
    ) {
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.currencyCode = currencyCode
    }

    /// The device's current currency, used as a sensible default when creating a new trip.
    static var defaultCurrencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    /// Sum of all receipts belonging to this trip.
    var totalAmount: Decimal {
        receipts.reduce(Decimal(0)) { $0 + $1.amount }
    }

    /// Formats an amount using this trip's currency rather than the device locale's.
    func formattedAmount(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: currencyCode))
    }
}

