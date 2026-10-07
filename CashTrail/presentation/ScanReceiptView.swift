import SwiftUI
import SwiftData

struct ScanReceiptView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var stage: Stage = .scanning
    @State private var capturedImage: UIImage?
    @State private var merchant = ""
    @State private var amountText = ""
    @State private var currencyCode = ""
    @State private var convertedAmountText = ""
    @State private var exchangeRate: Decimal?
    @State private var date = Date()
    @State private var rawText = ""
    @State private var errorMessage: String?
    @FocusState private var focusedField: EntryField?

    enum Stage {
        case scanning, processing, review
    }

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .scanning:
                    DocumentScannerView(
                        onScanComplete: handleScan,
                        onCancel: { dismiss() }
                    )
                case .processing:
                    ProgressView("Reading receipt…")
                        .padding()
                case .review:
                    reviewForm
                }
            }
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if stage == .review {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveReceipt() }
                            .disabled(
                                merchant.trimmingCharacters(in: .whitespaces).isEmpty
                                || finalAmount == nil
                            )
                    }
                }
            }
        }
    }

    private var needsConversion: Bool {
        currencyCode.uppercased() != trip.currencyCode.uppercased()
    }

    private var enteredAmount: Decimal? {
        Decimal(string: amountText, locale: .current)
    }

    /// The amount that will actually be saved, always in the trip's currency.
    private var finalAmount: Decimal? {
        needsConversion ? Decimal(string: convertedAmountText, locale: .current) : enteredAmount
    }

    private var reviewForm: some View {
        Form {
            if let capturedImage {
                Section {
                    Image(uiImage: capturedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                }
            }
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
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }
        }
        .interactiveKeyboardDismissal { focusedField = nil }
    }

    private func handleScan(_ image: UIImage) {
        capturedImage = image
        stage = .processing

        ReceiptScanner.recognizeText(in: image) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let ocrResult):
                    merchant = ocrResult.merchant
                    amountText = ocrResult.amount.map { "\($0)" } ?? ""
                    date = ocrResult.date ?? Date()
                    rawText = ocrResult.rawText
                    if ocrResult.amount == nil {
                        errorMessage = "Couldn't detect an amount automatically — please enter it manually."
                    }
                case .failure:
                    errorMessage = "Couldn't read the receipt. Please enter details manually."
                    merchant = ""
                    amountText = ""
                }
                // OCR has no way to know the receipt's currency, so this assumes
                // it matches the trip's — change the currency in the review
                // screen below if the receipt was actually in a different one.
                currencyCode = trip.currencyCode
                convertedAmountText = amountText
                stage = .review
            }
        }
    }

    private func saveReceipt() {
        guard let amount = finalAmount else { return }
        let imageData = capturedImage?.jpegData(compressionQuality: 0.7)
        let receipt = Receipt(
            merchant: merchant.trimmingCharacters(in: .whitespaces),
            amount: amount,
            date: date,
            rawOCRText: rawText,
            imageData: imageData,
            originalAmount: needsConversion ? enteredAmount : nil,
            originalCurrencyCode: needsConversion ? currencyCode : nil,
            exchangeRate: needsConversion ? exchangeRate : nil,
            trip: trip
        )
        modelContext.insert(receipt)
        dismiss()
    }
}
