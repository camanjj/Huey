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

struct LogDetailsView: View {
    let entry: LogEntry
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                // header
                LogEntryItemView(entry: entry)
                    .padding(.bottom)
                
                // Context
                if let context = entry.context, !context.isEmpty {
                    Text("Context")
                        .font(.title2)
                    ForEach(context.sorted { $0.key < $1.key }, id: \.key) { key, value in
                        GroupBox {
                            LogValueRowView(label: key, value: value)
                        }
                    }
                }
            }
        }
        .padding([.horizontal])
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
                    valueText
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isCollapsible else { return }
            isExpanded.toggle()
        }
        .onChange(of: command) { command in
            if let command = command { apply(command) }
        }
        .contextMenu {
            if value.isContainer {
                Button("Expand All") {
                    apply(ExpansionCommand(expand: true))
                }
                Button("Collapse All") {
                    apply(ExpansionCommand(expand: false))
                }
            }
            Button("Copy Value") {
                copyToPasteboard(value.copyText)
            }
            Button("Copy Key") {
                copyToPasteboard(label)
            }
        }
        .animation(.spring(), value: isExpanded)
    }

    private var header: some View {
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
            if depth == 0, value.isContainer {
                expandAllButton
            }
        }
    }

    /// Top-level containers get a one-tap toggle between Expand All and Collapse All.
    private var expandAllButton: some View {
        let expandsNext = activeCommand?.expand != true
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
}

struct LogDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        LogDetailsView(entry: LogEntry.generate(1)[0])
    }
}
