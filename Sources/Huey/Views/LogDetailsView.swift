//
//  File.swift
//  
//
//  Created by Cameron Jackson on 11/5/21.
//

import Foundation
import SwiftUI

struct LogDetailsView: View {
    let entry: LogEntry
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                // header
                LogEntryItemView(entry: entry)
                    .padding(.bottom)
                
                // Context
                if let context = entry.context {
                    Text("Context")
                        .font(.title2)
                    ForEach(Array(context.keys), id: \.self) { key in
                        ContextView(key: key, value: context[key])
                    }
                }
            }
        }
        .padding([.horizontal])
    }
}

struct ContextView: View {
    let key: String
    let value: AnyObject?

    private let rendered: String
    @State private var isExpanded: Bool

    init(key: String, value: AnyObject?) {
        self.key = key
        self.value = value
        let rendered = String(describing: value)
        self.rendered = rendered
        _isExpanded = State(initialValue: !ContextView.isLarge(rendered))
    }

    private static func isLarge(_ rendered: String) -> Bool {
        rendered.count > 200 || rendered.contains("\n")
    }

    private var preview: String {
        let collapsed = rendered.replacingOccurrences(of: "\n", with: " ")
        if collapsed.count <= 80 { return collapsed }
        return String(collapsed.prefix(80)) + "…"
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Text(key)
                    .bold()
                    .italic()
                if isExpanded {
                    Text(rendered)
                        .font(.system(size: 14, design: .monospaced))
                } else {
                    Text(preview)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .onTapGesture {
            isExpanded.toggle()
        }
        .animation(.spring(), value: isExpanded)
    }
}

struct LogDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        LogDetailsView(entry: LogEntry.generate(1)[0])
    }
}
