#if !os(watchOS)
//
//  File.swift
//  
//
//  Created by Cameron Jackson on 11/5/21.
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

private func copyToPasteboard(_ string: String) {
    #if canImport(UIKit)
    UIPasteboard.general.string = string
    #elseif canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(string, forType: .string)
    #endif
}

/// How context rows copy text. `LogDetailsView` swaps in a version that also shows the
/// "Copied" toast; rows used elsewhere fall back to a plain pasteboard write.
private struct CopyActionKey: EnvironmentKey {
    static let defaultValue: (String) -> Void = copyToPasteboard
}

extension EnvironmentValues {
    var copyAction: (String) -> Void {
        get { self[CopyActionKey.self] }
        set { self[CopyActionKey.self] = newValue }
    }
}

struct LogDetailsView: View {
    let entry: LogEntry

    @State private var showsCopied = false
    @State private var hideCopied: DispatchWorkItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                // header
                LogEntryItemView(entry: entry)
                    .padding(.bottom)

                // Context
                if let context = entry.context, !context.isEmpty {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Context")
                            .font(.title2)
                        Spacer()
                        Button {
                            copy(LogValue.dictionary(context).copyText)
                        } label: {
                            Label("Copy All", systemImage: "doc.on.doc")
                                .font(.subheadline)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    ForEach(context.sorted { $0.key < $1.key }, id: \.key) { key, value in
                        GroupBox {
                            LogValueRowView(label: key, value: value)
                        }
                    }
                }
            }
        }
        .padding([.horizontal])
        .environment(\.copyAction, copy)
        .overlay(copiedToast, alignment: .bottom)
    }

    private func copy(_ string: String) {
        copyToPasteboard(string)
        hideCopied?.cancel()
        withAnimation { showsCopied = true }
        let hide = DispatchWorkItem { withAnimation { showsCopied = false } }
        hideCopied = hide
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: hide)
    }

    @ViewBuilder private var copiedToast: some View {
        if showsCopied {
            Label("Copied", systemImage: "checkmark")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.black.opacity(0.8)))
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// A request to open or close a context row and every row beneath it. Each request gets a
/// fresh `id`, so issuing the same direction twice still reaches rows changed by hand since.
struct ExpansionCommand: Equatable {
    let expand: Bool
    let id = UUID()
}

/// One node of a log entry's context. Dictionaries and arrays recurse into indented child
/// rows; scalars print their value. Recursion is erased through `AnyView` so the opaque
/// `body` type stays non-circular.
struct LogValueRowView: View {
    let label: String
    let value: LogValue
    let depth: Int
    /// The latest Expand All / Collapse All issued by an ancestor, if any.
    let command: ExpansionCommand?

    @State private var isExpanded: Bool
    /// The command this row hands to its children: the latest of its own and its ancestors'.
    @State private var activeCommand: ExpansionCommand?

    private static let maxAutoExpandDepth = 3

    init(label: String, value: LogValue, depth: Int = 0, command: ExpansionCommand? = nil) {
        self.label = label
        self.value = value
        self.depth = depth
        self.command = command
        // Rows created while a command is in force (children of a row it just opened) adopt it.
        let defaultExpanded = !value.isLarge && depth < LogValueRowView.maxAutoExpandDepth
        _isExpanded = State(initialValue: command?.expand ?? defaultExpanded)
        _activeCommand = State(initialValue: command)
    }

    private func apply(_ command: ExpansionCommand) {
        activeCommand = command
        if isCollapsible { isExpanded = command.expand }
    }

    @Environment(\.copyAction) private var copy

    private let monospaced = Font.system(size: 14, design: .monospaced)

    /// Short scalars sit on the same line as their key; only containers and big blobs expand.
    private var isCollapsible: Bool { value.isContainer || value.isLarge }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if isCollapsible, isExpanded {
                if let children = value.children {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                            AnyView(
                                LogValueRowView(
                                    label: child.label,
                                    value: child.value,
                                    depth: depth + 1,
                                    command: activeCommand
                                )
                            )
                        }
                    }
                    .padding(.leading, 12)
                } else {
                    expandedValueText
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onChange(of: command) { command in
            if let command = command { apply(command) }
        }
        .animation(.spring(), value: isExpanded)
    }

    /// Sits on the header rather than the whole row, so long-pressing an opened value selects
    /// text instead; child rows carry their own menus.
    @ViewBuilder private var menuItems: some View {
        if value.isContainer {
            Button("Expand All") {
                apply(ExpansionCommand(expand: true))
            }
            Button("Collapse All") {
                apply(ExpansionCommand(expand: false))
            }
        }
        Button("Copy Value") {
            copy(value.copyText)
        }
        Button("Copy Key") {
            copy(label)
        }
    }

    /// The tap-to-toggle area covers the key and its summary but not the Expand All or Copy
    /// buttons, so tapping a button never also toggles the row.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            headerContent
                .contentShape(Rectangle())
                .onTapGesture {
                    guard isCollapsible else { return }
                    isExpanded.toggle()
                }
            if depth == 0, value.isContainer {
                expandAllButton
            }
            if depth == 0 {
                copyButton
            }
        }
        .contentShape(Rectangle())
        .contextMenu { menuItems }
    }

    private var copyButton: some View {
        Button {
            copy(value.copyText)
        } label: {
            Image(systemName: "doc.on.doc")
                .foregroundColor(.secondary)
        }
        .buttonStyle(BorderlessButtonStyle())
        .accessibilityLabel("Copy Value")
    }

    private var headerContent: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if value.isContainer {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            Text(label)
                .bold()
                .italic()
            if value.isContainer {
                Text(value.summaryLabel)
                    .font(monospaced)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else if !isCollapsible {
                valueText
            } else if !isExpanded {
                Text(value.previewText)
                    .font(monospaced)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
    }

    /// Top-level containers get a one-tap toggle between Expand All and Collapse All. It offers
    /// Collapse All only while the row is open and the last bulk command was Expand All, so a
    /// row collapsed by hand offers Expand All again.
    private var expandAllButton: some View {
        let expandsNext = !isExpanded || activeCommand?.expand != true
        return Button {
            apply(ExpansionCommand(expand: expandsNext))
        } label: {
            Image(systemName: expandsNext ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                .foregroundColor(.secondary)
        }
        .buttonStyle(BorderlessButtonStyle())
        .accessibilityLabel(expandsNext ? "Expand All" : "Collapse All")
    }

    @ViewBuilder private var valueText: some View {
        if case .null = value {
            Text("nil")
                .font(monospaced)
                .italic()
                .foregroundColor(.secondary)
        } else {
            Text(value.stringValue)
                .font(monospaced)
        }
    }

    /// An opened big value. SwiftUI's `textSelection` on iOS can only copy a whole `Text`, so
    /// iOS 16+ uses a read-only `UITextView` to allow selecting part of it.
    @ViewBuilder private var expandedValueText: some View {
        #if canImport(UIKit)
        if #available(iOS 16, *) {
            SelectableText(text: value.stringValue)
        } else {
            valueText.textSelectionIfAvailable()
        }
        #else
        valueText.textSelectionIfAvailable()
        #endif
    }
}

private extension View {
    @ViewBuilder func textSelectionIfAvailable() -> some View {
        if #available(iOS 15, macOS 12, *) {
            textSelection(.enabled)
        } else {
            self
        }
    }
}

#if canImport(UIKit)
/// Read-only, non-scrolling text that supports selecting and copying any part of it.
@available(iOS 16, *)
private struct SelectableText: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        view.textColor = .label
        view.adjustsFontForContentSizeCategory = true
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        if view.text != text { view.text = text }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite else { return nil }
        let height = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        return CGSize(width: width, height: ceil(height))
    }
}
#endif

struct LogDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        LogDetailsView(entry: LogEntry.generate(1)[0])
    }
}
#endif
