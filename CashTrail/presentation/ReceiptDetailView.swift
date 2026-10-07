import SwiftUI
import SwiftData

struct ReceiptDetailView: View {
    @Bindable var receipt: Receipt
    @FocusState private var focusedField: Field?

    private enum Field {
        case merchant, amount, notes
    }

    private var currencyCode: String {
        receipt.trip?.currencyCode ?? Trip.defaultCurrencyCode
    }

    var body: some View {
        Form {
            if let imageData = receipt.imageData, let uiImage = UIImage(data: imageData) {
                Section {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                }
            }

            Section("Details") {
                TextField("Merchant", text: $receipt.merchant)
                    .focused($focusedField, equals: .merchant)
                HStack {
                    Text("Amount")
                    Spacer()
                    TextField(
                        "Amount",
                        value: $receipt.amount,
                        format: .currency(code: currencyCode)
                    )
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .amount)
                }
                DatePicker("Date", selection: $receipt.date, displayedComponents: .date)
            }

            if receipt.wasConverted,
               let originalAmount = receipt.originalAmount,
               let originalCurrencyCode = receipt.originalCurrencyCode {
                Section("Original Amount") {
                    HStack {
                        Text("Entered as")
                        Spacer()
                        Text(originalAmount.formatted(.currency(code: originalCurrencyCode)))
                            .foregroundStyle(.secondary)
                    }
                    if let rate = receipt.exchangeRate {
                        HStack {
                            Text("Rate used")
                            Spacer()
                            Text("1 \(originalCurrencyCode) ≈ \(rate.formatted()) \(currencyCode)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Notes") {
                TextField(
                    "Optional notes",
                    text: Binding(
                        get: { receipt.notes ?? "" },
                        set: { receipt.notes = $0.isEmpty ? nil : $0 }
                    ),
                    axis: .vertical
                )
                .focused($focusedField, equals: .notes)
            }

            if !receipt.rawOCRText.isEmpty {
                Section("Raw OCR Text") {
                    Text(receipt.rawOCRText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .interactiveKeyboardDismissal { focusedField = nil }
        .navigationTitle(receipt.merchant)
        .navigationBarTitleDisplayMode(.inline)
    }
}
