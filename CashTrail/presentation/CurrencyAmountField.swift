import SwiftUI

/// Focusable fields shared by the entry forms, so a form's single `@FocusState`
/// can cover its own fields (merchant, notes) and the ones inside
/// `CurrencyAmountField`, and dismiss the keyboard for all of them at once.
enum EntryField: Hashable {
    case merchant, amount, convertedAmount, notes
}

/// An amount field that can be entered in any currency, not just the trip's.
///
/// If the chosen currency differs from `tripCurrencyCode`, this shows a second
/// row with the converted amount (auto-fetched from ExchangeRateService), which
/// the person can still edit by hand — important for when there's no signal to
/// fetch a live rate, or when they want to match what their card actually charged.
///
/// `amountText` / `currencyCode` are the amount as entered and its currency.
/// `convertedAmountText` is always in the trip's currency — when no conversion
/// is needed, it's kept equal to `amountText`. `exchangeRate` records the rate
/// actually used, or nil if the amount was entered/edited manually.
struct CurrencyAmountField: View {
    let tripCurrencyCode: String

    @Binding var amountText: String
    @Binding var currencyCode: String
    @Binding var convertedAmountText: String
    @Binding var exchangeRate: Decimal?
    var focusedField: FocusState<EntryField?>.Binding

    @State private var showingCurrencyPicker = false
    @State private var isFetchingRate = false
    @State private var rateFetchError: String?
    @State private var convertedAmountEditedByUser = false

    private var needsConversion: Bool {
        currencyCode.uppercased() != tripCurrencyCode.uppercased()
    }

    var body: some View {
        Group {
            HStack {
                Text("Amount")
                Spacer()
                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused(focusedField, equals: .amount)
                    .onChange(of: amountText) { _, _ in recomputeConvertedAmount() }
                Button(currencyCode) {
                    showingCurrencyPicker = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if needsConversion {
                HStack {
                    Text("In \(tripCurrencyCode)")
                    Spacer()
                    if isFetchingRate {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        // Only a binding's setter runs for actual typing. Using
                        // .onChange here would also fire when the code itself
                        // writes the computed value, wrongly flagging it as a
                        // manual edit and freezing the auto-conversion.
                        TextField(
                            "0.00",
                            text: Binding(
                                get: { convertedAmountText },
                                set: { newValue in
                                    convertedAmountEditedByUser = true
                                    convertedAmountText = newValue
                                }
                            )
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused(focusedField, equals: .convertedAmount)
                    }
                }

                if let rateFetchError {
                    Text(rateFetchError)
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if let exchangeRate, !convertedAmountEditedByUser {
                    Text("1 \(currencyCode) ≈ \(exchangeRate.formatted()) \(tripCurrencyCode)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showingCurrencyPicker) {
            CurrencyPickerView(selectedCurrencyCode: $currencyCode)
        }
        .onChange(of: currencyCode) { _, _ in
            convertedAmountEditedByUser = false
            rateFetchError = nil
            if needsConversion {
                fetchRate()
            } else {
                exchangeRate = nil
                convertedAmountText = amountText
            }
        }
        .task {
            if needsConversion {
                fetchRate()
            }
        }
    }

    private func fetchRate() {
        isFetchingRate = true
        rateFetchError = nil
        let base = currencyCode
        let quote = tripCurrencyCode

        Task {
            do {
                let rate = try await ExchangeRateService.fetchRate(from: base, to: quote)
                await MainActor.run {
                    isFetchingRate = false
                    // Only apply if the currency hasn't changed again while we were fetching.
                    guard currencyCode == base else { return }
                    exchangeRate = rate
                    recomputeConvertedAmount()
                }
            } catch {
                await MainActor.run {
                    isFetchingRate = false
                    guard currencyCode == base else { return }
                    rateFetchError = "Couldn't fetch a rate — enter the converted amount yourself."
                }
            }
        }
    }

    private func recomputeConvertedAmount() {
        guard needsConversion, !convertedAmountEditedByUser,
              let rate = exchangeRate,
              let entered = Decimal(string: amountText, locale: .current) else { return }

        var converted = entered * rate
        var rounded = Decimal()
        NSDecimalRound(&rounded, &converted, 2, .plain)
        convertedAmountText = "\(rounded)"
    }
}
