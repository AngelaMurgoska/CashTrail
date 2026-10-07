import SwiftUI
import SwiftData

/// Lets the user add a Receipt by typing in the details directly,
/// as an alternative to scanning one with the camera.
struct AddManualExpenseView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var merchant = ""
    @State private var amountText = ""
    @State private var currencyCode: String
    @State private var convertedAmountText = ""
    @State private var exchangeRate: Decimal?
    @State private var date = Date()
    @State private var notes = ""
    @FocusState private var focusedField: EntryField?

    init(trip: Trip) {
        self.trip = trip
        _currencyCode = State(initialValue: trip.currencyCode)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Merchant", text: $merchant)
                        .focused($focusedField, equals: .merchant)
                    CurrencyAmountField(
                        tripCurrencyCode: trip.currencyCode,
                        amountText: $amountText,
                        currencyCode: $currencyCode,
                        convertedAmountText: $convertedAmountText,
                        exchangeRate: $exchangeRate,
                        focusedField: $focusedField
                    )
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .focused($focusedField, equals: .notes)
                }
            }
            .interactiveKeyboardDismissal { focusedField = nil }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveExpense() }
                        .disabled(
                            merchant.trimmingCharacters(in: .whitespaces).isEmpty
                            || finalAmount == nil
                        )
                }
            }
        }
    }

    private var needsConversion: Bool {
        currencyCode.uppercased() != trip.currencyCode.uppercased()
    }

    /// Parses using the current locale so a comma decimal separator (e.g. "12,50")
    /// works correctly on devices set to a European-style locale, not just "12.50".
    private var enteredAmount: Decimal? {
        Decimal(string: amountText, locale: .current)
    }

    /// The amount that will actually be saved, always in the trip's currency.
    private var finalAmount: Decimal? {
        needsConversion ? Decimal(string: convertedAmountText, locale: .current) : enteredAmount
    }

    private func saveExpense() {
        guard let amount = finalAmount else { return }
        let receipt = Receipt(
            merchant: merchant.trimmingCharacters(in: .whitespaces),
            amount: amount,
            date: date,
            rawOCRText: "",
            notes: notes.isEmpty ? nil : notes,
            imageData: nil,
            originalAmount: needsConversion ? enteredAmount : nil,
            originalCurrencyCode: needsConversion ? currencyCode : nil,
            exchangeRate: needsConversion ? exchangeRate : nil,
            trip: trip
        )
        modelContext.insert(receipt)
        dismiss()
    }
}
