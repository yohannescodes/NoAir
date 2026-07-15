import SwiftUI

/// Shared helpers for the log forms and editor sheets.
enum FormSupport {
    /// Trims whitespace; returns nil for empty results.
    static func clean(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func clampSpO2(_ value: Int) -> Int {
        min(max(value, 50), 100)
    }

    static func clampPulse(_ value: Int) -> Int {
        min(max(value, 20), 250)
    }
}

/// Adds the "Done" keyboard toolbar button that clears the given focus.
struct KeyboardDoneToolbar<Field: Hashable>: ViewModifier {
    var focus: FocusState<Field?>.Binding

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focus.wrappedValue = nil
                }
            }
        }
    }
}

extension View {
    func keyboardDoneToolbar<Field: Hashable>(focus: FocusState<Field?>.Binding) -> some View {
        modifier(KeyboardDoneToolbar(focus: focus))
    }
}
