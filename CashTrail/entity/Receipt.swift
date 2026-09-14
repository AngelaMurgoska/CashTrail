import Foundation
import SwiftData

@Model
final class Receipt {
    var merchant: String
    var amount: Decimal
    var date: Date
    var rawOCRText: String
    var notes: String?

    // Stored externally so large image blobs don't bloat the SwiftData store file.
    @Attribute(.externalStorage) var imageData: Data?

    var trip: Trip?

    init(
        merchant: String,
        amount: Decimal,
        date: Date = .now,
        rawOCRText: String = "",
        notes: String? = nil,
        imageData: Data? = nil,
        trip: Trip? = nil
    ) {
        self.merchant = merchant
        self.amount = amount
        self.date = date
        self.rawOCRText = rawOCRText
        self.notes = notes
        self.imageData = imageData
        self.trip = trip
    }
}
