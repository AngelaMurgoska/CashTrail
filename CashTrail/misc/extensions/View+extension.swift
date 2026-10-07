//
//  View+extension.swift
//  CashTrail
//
//  Created by Angela Murgoska on 05/10/2026.
//

import SwiftUI

public extension View {
    func interactiveKeyboardDismissal(_ closure: @escaping () -> Void) -> some View {
        simultaneousGesture(DragGesture().onChanged({ _ in closure() }))
    }
}
