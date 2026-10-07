import Foundation
import SwiftData

@Model
final class Receipt {
    /// Always in the trip's currency — this is what trip totals sum.
    /// If the receipt was entered in a different currency, this is the converted value.
    var merchant: String
    var amount: Decimal
    var date: Date
    var rawOCRText: String
    var notes: String?

    // Stored externally so large image blobs don't bloat the SwiftData store file.
    @Attribute(.externalStorage) var imageData: Data?

    // Populated only when this receipt was entered in a currency different from
    // its trip's currency. Kept so the original entry and the rate used stay on
    // record, rather than being silently lost or recalculated later with a
    // different (now-current) rate.
    var originalAmount: Decimal?
    var originalCurrencyCode: String?
    var exchangeRate: Decimal?

    var trip: Trip?

    init(
        merchant: String,
        amount: Decimal,
        date: Date = .now,
        rawOCRText: String = "",
        notes: String? = nil,
        imageData: Data? = nil,
        originalAmount: Decimal? = nil,
        originalCurrencyCode: String? = nil,
        exchangeRate: Decimal? = nil,
        trip: Trip? = nil
    ) {
        self.merchant = merchant
        self.amount = amount
        self.date = date
        self.rawOCRText = rawOCRText
        self.notes = notes
        self.imageData = imageData
        self.originalAmount = originalAmount
        self.originalCurrencyCode = originalCurrencyCode
        self.exchangeRate = exchangeRate
        self.trip = trip
    }

    /// True if this receipt required currency conversion when it was entered.
    var wasConverted: Bool {
        originalCurrencyCode != nil
    }
}

