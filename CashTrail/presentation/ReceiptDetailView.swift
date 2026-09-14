import SwiftUI
import SwiftData

struct ReceiptDetailView: View {
    @Bindable var receipt: Receipt

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
                }
                DatePicker("Date", selection: $receipt.date, displayedComponents: .date)
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
            }

            if !receipt.rawOCRText.isEmpty {
                Section("Raw OCR Text") {
                    Text(receipt.rawOCRText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(receipt.merchant)
        .navigationBarTitleDisplayMode(.inline)
    }
}
