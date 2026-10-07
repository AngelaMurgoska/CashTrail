import SwiftUI
import SwiftData

struct TripDetailView: View {
    @Bindable var trip: Trip
    @Environment(\.modelContext) private var modelContext
    @State private var showingScanner = false
    @State private var showingManualEntry = false
    @State private var showingEditJar = false

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
                    showingEditJar = true
                } label: {
                    Label("Edit Jar", systemImage: "slider.horizontal.3")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingScanner = true
                    } label: {
                        Label("Scan Receipt", systemImage: "camera.viewfinder")
                    }
                    Button {
                        showingManualEntry = true
                    } label: {
                        Label("Enter Manually", systemImage: "square.and.pencil")
                    }
                } label: {
                    Label("Add Expense", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingScanner) {
            ScanReceiptView(trip: trip)
        }
        .sheet(isPresented: $showingManualEntry) {
            AddManualExpenseView(trip: trip)
        }
        .sheet(isPresented: $showingEditJar) {
            EditTripView(trip: trip)
        }
        .overlay {
            if trip.receipts.isEmpty {
                ContentUnavailableView(
                    "No Receipts",
                    systemImage: "receipt",
                    description: Text("Tap + to scan or add your first expense.")
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

