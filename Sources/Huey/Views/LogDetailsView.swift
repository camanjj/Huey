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

/// One node of a log entry's context. Dictionaries and arrays recurse into indented child
/// rows; scalars print their value. Recursion is erased through `AnyView` so the opaque
/// `body` type stays non-circular.
struct LogValueRowView: View {
    let label: String
    let value: LogValue
    let depth: Int

    @State private var isExpanded: Bool

    private static let maxAutoExpandDepth = 3

    init(label: String, value: LogValue, depth: Int = 0) {
        self.label = label
        self.value = value
        self.depth = depth
        _isExpanded = State(initialValue: !value.isLarge && depth < LogValueRowView.maxAutoExpandDepth)
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
                                LogValueRowView(label: child.label, value: child.value, depth: depth + 1)
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
        .contextMenu {
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
        }
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
