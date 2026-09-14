//
//  CashTrailApp.swift
//  CashTrailApp
//
//  Created by Angela Murgoska on 23.6.26.
//

import SwiftUI
import SwiftData

@main
struct CashTrailApp: App {
    var body: some Scene {
        WindowGroup {
            TripListView()
        }
        .modelContainer(for: [Trip.self, Receipt.self])
    }
}
