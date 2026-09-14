import SwiftUI

/// A searchable list of ISO 4217 currencies, used to set a Trip's currency.
struct CurrencyPickerView: View {
    @Binding var selectedCurrencyCode: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private static let allCurrencies: [(code: String, name: String)] = {
        Locale.Currency.isoCurrencies
            .compactMap { currency -> (code: String, name: String)? in
                let code = currency.identifier
                guard let name = Locale.current.localizedString(forCurrencyCode: code) else { return nil }
                return (code, name)
            }
            .sorted { $0.name < $1.name }
    }()

    private var filteredCurrencies: [(code: String, name: String)] {
        guard !searchText.isEmpty else { return Self.allCurrencies }
        return Self.allCurrencies.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.code.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredCurrencies, id: \.code) { currency in
                Button {
                    selectedCurrencyCode = currency.code
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(currency.code)
                                .font(.body.weight(.medium))
                            Text(currency.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if currency.code == selectedCurrencyCode {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
            .searchable(text: $searchText, prompt: "Search currency")
            .navigationTitle("Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
