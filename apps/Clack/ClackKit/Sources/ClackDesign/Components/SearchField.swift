//
//  SearchField.swift
//  ClackDesign
//

import SwiftUI

/// The one search field: 48 pt high, the input radius, a search icon, the placeholder in text-3, the caret and the
/// focused border in the accent line. Over a map it sits on glass instead of the raised surface.
public struct SearchField: View {
    @Binding public var text: String
    public let prompt: String
    public var overMap = false
    private let focus: FocusState<Bool>.Binding?
    @FocusState private var ownFocus: Bool

    public static let height: CGFloat = 48

    public init(text: Binding<String>, prompt: String, overMap: Bool = false, focus: FocusState<Bool>.Binding? = nil) {
        _text = text
        self.prompt = prompt
        self.overMap = overMap
        self.focus = focus
    }

    private var focused: Bool { focus?.wrappedValue ?? ownFocus }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
        HStack(spacing: 8) {
            LucideIcon(name: "search", size: 18).foregroundStyle(Ink.text2)
            field
                .clack(.searchField)
                .foregroundStyle(Ink.text)
                .tint(Ink.accentLine)
                .noAutocapitalization()
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityLabel(prompt)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: Self.height)
        .background {
            if overMap {
                #if os(iOS)
                if #available(iOS 26.0, *) {
                    // Liquid Glass; the system draws its own edge.
                    Color.clear.glassEffect(.regular, in: shape)
                } else {
                    shape.fill(Ink.glass)
                    shape.fill(.ultraThinMaterial)
                }
                #else
                shape.fill(Ink.glass)
                shape.fill(.ultraThinMaterial)
                #endif
            } else {
                shape.fill(Ink.surfaceRaised)
            }
        }
        .modifier(SearchBorder(shape: shape, show: !overMap || !Self.hasLiquidGlass || focused, color: focused ? Ink.accentLine : Ink.hairline))
        .contentShape(shape)
    }

    private static var hasLiquidGlass: Bool {
        #if os(iOS)
        if #available(iOS 26.0, *) { return true }
        #endif
        return false
    }

    @ViewBuilder
    private var field: some View {
        let input = TextField("", text: $text, prompt: Text(prompt).foregroundStyle(Ink.text3))
        if let focus {
            input.focused(focus)
        } else {
            input.focused($ownFocus)
        }
    }
}

/// The hairline border, left off glass (which has its edge) until the field is focused.
private struct SearchBorder: ViewModifier {
    let shape: RoundedRectangle
    let show: Bool
    let color: Color

    func body(content: Content) -> some View {
        // Always the same view (only the line's colour changes): swapping between two shapes would rebuild the field and drop its focus.
        content.hairlineBorder(radius: Radius.input, color: show ? color : .clear)
    }
}

private extension View {
    /// Names and numbers, not sentences: no capital letter forced at the start (iOS only; the Mac builds run the tests).
    @ViewBuilder
    func noAutocapitalization() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.never)
        #else
        self
        #endif
    }
}
