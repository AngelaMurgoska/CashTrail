import SwiftUI
import SwiftData

struct EditTripView: View {
    @Bindable var trip: Trip
    @Environment(\.dismiss) private var dismiss
    @State private var showingCurrencyPicker = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case name, notes
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Info") {
                    TextField("Trip Name", text: $trip.name)
                        .focused($focusedField, equals: .name)
                    DatePicker("Start Date", selection: $trip.startDate, displayedComponents: .date)
                }

                Section {
                    Button {
                        showingCurrencyPicker = true
                    } label: {
                        HStack {
                            Text("Currency")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(trip.currencyCode)
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    if !trip.receipts.isEmpty {
                        Text("Changing the currency only changes how amounts are labeled — it won't convert the values of receipts you've already scanned.")
                    }
                }

                Section("Notes") {
                    TextField(
                        "Optional notes",
                        text: Binding(
                            get: { trip.notes ?? "" },
                            set: { trip.notes = $0.isEmpty ? nil : $0 }
                        ),
                        axis: .vertical
                    )
                    .focused($focusedField, equals: .notes)
                }
            }
            .interactiveKeyboardDismissal { focusedField = nil }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCurrencyPicker) {
                CurrencyPickerView(selectedCurrencyCode: $trip.currencyCode)
            }
        }
    }
}
