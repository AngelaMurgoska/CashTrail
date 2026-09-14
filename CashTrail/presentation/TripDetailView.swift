import SwiftUI
import SwiftData

struct TripDetailView: View {
    @Bindable var trip: Trip
    @Environment(\.modelContext) private var modelContext
    @State private var showingScanner = false
    @State private var showingEditTrip = false

    private var sortedReceipts: [Receipt] {
        trip.receipts.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Total Spent")
                        .font(.headline)
                    Spacer()
                    Text(trip.formattedAmount(trip.totalAmount))
                        .font(.title2.bold())
                }
            }

            Section("Receipts (\(trip.receipts.count))") {
                ForEach(sortedReceipts) { receipt in
                    NavigationLink(value: receipt) {
                        ReceiptRowView(receipt: receipt, currencyCode: trip.currencyCode)
                    }
                }
                .onDelete(perform: deleteReceipts)
            }
        }
        .navigationTitle(trip.name)
        .navigationDestination(for: Receipt.self) { receipt in
            ReceiptDetailView(receipt: receipt)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingEditTrip = true
                } label: {
                    Label("Edit Trip", systemImage: "slider.horizontal.3")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingScanner = true
                } label: {
                    Label("Scan Receipt", systemImage: "camera.viewfinder")
                }
            }
        }
        .sheet(isPresented: $showingScanner) {
            ScanReceiptView(trip: trip)
        }
        .sheet(isPresented: $showingEditTrip) {
            EditTripView(trip: trip)
        }
        .overlay {
            if trip.receipts.isEmpty {
                ContentUnavailableView(
                    "No Receipts",
                    systemImage: "receipt",
                    description: Text("Tap the camera icon to scan your first receipt.")
                )
            }
        }
    }

    private func deleteReceipts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sortedReceipts[index])
        }
    }
}

struct ReceiptRowView: View {
    let receipt: Receipt
    let currencyCode: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(receipt.merchant)
                    .font(.body)
                Text(receipt.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(receipt.amount.formatted(.currency(code: currencyCode)))
                .fontWeight(.medium)
        }
    }
}
