import SwiftUI
import SwiftData

struct TripDetailView: View {
    @Bindable var trip: Trip
    @Environment(\.modelContext) private var modelContext
    @State private var showingScanner = false
    @State private var showingManualEntry = false
    @State private var showingEditTrip = false

    /// Receipts that happened on the same calendar day.
    private struct DayGroup: Identifiable {
        let day: Date
        let receipts: [Receipt]

        var id: Date { day }
        var total: Decimal { receipts.reduce(Decimal(0)) { $0 + $1.amount } }
    }

    private var dayGroups: [DayGroup] {
        let grouped = Dictionary(grouping: trip.receipts) {
            Calendar.current.startOfDay(for: $0.date)
        }
        return grouped
            .map { DayGroup(day: $0.key, receipts: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        List {
            Section {
                TripHeroView(trip: trip)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            }

            ForEach(dayGroups) { group in
                Section {
                    ForEach(group.receipts) { receipt in
                        NavigationLink(value: receipt) {
                            ReceiptRowView(receipt: receipt, currencyCode: trip.currencyCode)
                        }
                    }
                    .onDelete { offsets in
                        deleteReceipts(offsets, from: group.receipts)
                    }
                } header: {
                    HStack {
                        Text(dayLabel(for: group.day))
                        Spacer()
                        Text(trip.formattedAmount(group.total))
                            .monospacedDigit()
                    }
                    .font(.subheadline.weight(.semibold))
                    .textCase(nil)
                }
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
        .sheet(isPresented: $showingEditTrip) {
            EditTripView(trip: trip)
        }
        .overlay {
            if trip.receipts.isEmpty {
                ContentUnavailableView(
                    "No Receipts",
                    systemImage: "receipt",
                    description: Text("Tap + to scan or add your first expense.")
                )
                .padding(.top, 120)
            }
        }
    }

    private func dayLabel(for day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func deleteReceipts(_ offsets: IndexSet, from receipts: [Receipt]) {
        for index in offsets {
            modelContext.delete(receipts[index])
        }
    }
}

/// The trip's total on a gradient panel with a torn-receipt bottom edge.
private struct TripHeroView: View {
    let trip: Trip

    private let toothHeight: CGFloat = 7

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total spent")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)

            Text(trip.formattedAmount(trip.totalAmount))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.default, value: trip.totalAmount)

            Text("\(trip.receiptCountText), \(trip.dateRangeText)")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 22 + toothHeight)
        .background(.brandGradient, in: ReceiptShape(toothHeight: toothHeight))
    }
}

struct ReceiptRowView: View {
    let receipt: Receipt
    let currencyCode: String

    private var initial: String {
        receipt.merchant
            .trimmingCharacters(in: .whitespaces)
            .first
            .map { String($0).uppercased() } ?? "?"
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(initial)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Color.brandAccent)
                .frame(width: 40, height: 40)
                .background(Color.brandAccent.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(receipt.merchant)
                    .font(.body.weight(.medium))
                Text(receipt.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(receipt.amount.formatted(.currency(code: currencyCode)))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                if let original = receipt.originalAmount,
                   let originalCode = receipt.originalCurrencyCode {
                    Text(original.formatted(.currency(code: originalCode)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
