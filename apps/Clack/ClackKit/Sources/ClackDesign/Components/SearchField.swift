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
    /// What's already chosen, drawn in the field above the text (Add a train's picked stations).
    private let tokens: AnyView?
    /// False once the tokens say it all (both stations picked, nothing typed): the text line folds away, kept in place
    /// so the field keeps its identity and focus.
    private let showsText: Bool
    /// False when the tokens lead the field (they say what it is), which leaves them its width.
    private let showsIcon: Bool
    @FocusState private var ownFocus: Bool

    public static let height: CGFloat = 48

    public init(text: Binding<String>, prompt: String, overMap: Bool = false, focus: FocusState<Bool>.Binding? = nil) {
        _text = text
        self.prompt = prompt
        self.overMap = overMap
        self.focus = focus
        self.tokens = nil
        self.showsText = true
        self.showsIcon = true
    }

    public init<Tokens: View>(text: Binding<String>, prompt: String, focus: FocusState<Bool>.Binding? = nil, showsText: Bool = true, showsIcon: Bool = true, @ViewBuilder tokens: () -> Tokens) {
        _text = text
        self.prompt = prompt
        self.overMap = false
        self.focus = focus
        self.tokens = AnyView(tokens())
        self.showsText = showsText
        self.showsIcon = showsIcon
    }

    private var focused: Bool { focus?.wrappedValue ?? ownFocus }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
        HStack(spacing: showsIcon ? Space.s : 0) {
            // Folded rather than removed, so the text field after it keeps its identity (and focus).
            LucideIcon(name: "search", size: 18).foregroundStyle(Ink.text2)
                .frame(width: showsIcon ? nil : 0)
                .opacity(showsIcon ? 1 : 0)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                // Always the same structure (the tokens may be empty): adding a row must not rebuild the text field and drop its focus.
                tokens
                field
                    .clack(.searchField)
                    .foregroundStyle(Ink.text)
                    .tint(Ink.accentLine)
                    .noAutocapitalization()
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .accessibilityLabel(prompt)
                    .frame(minHeight: tokens == nil || !showsText ? nil : Self.height - 4)
                    .frame(height: showsText ? nil : 0)
                    .opacity(showsText ? 1 : 0)
                    .allowsHitTesting(showsText)
                    .accessibilityHidden(!showsText)
            }
            .padding(.bottom, showsText ? 0 : Space.xs)
        }
        .padding(.horizontal, Space.m)
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
