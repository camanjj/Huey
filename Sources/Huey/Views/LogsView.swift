//
//  File.swift
//  
//
//  Created by Cameron Jackson on 11/5/21.
//

import Foundation
import SwiftUI

struct LogsView: View { // container view
    
    @StateObject var viewModel = LogsVM()
    
    var body: some View {
        LogsListView(entries: viewModel.entries)
    }
}

struct LogsListView: View {
    let entries: [LogEntry]
    
    var body: some View {
        List {
            ForEach(entries, id: \.id) { entry in
                NavigationLink() {
                    LogDetailsView(entry: entry)
                } label: {
                    LogEntryItemView(entry: entry)
                }
            }
        }
        .animation(.default)
    }
}

struct LogEntryItemView: View {
    let message: String
    let date: String
    let level: LogData.Level
    let file: String
    let line: Int
    let function: String
    
    var body: some View {
        HStack {
        VStack(alignment: .leading) {
            HStack {
                Text(date)
            }
            .font(.caption)
            Text(message)
                .lineLimit(2)
            HStack {
                Text(level.emoji)
                    .font(.caption2)
                Text("\(file):\(function):\(line)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
            Spacer()
            
        }
    }
}

extension LogEntryItemView {
    init(entry: LogEntry) {
        self.message = entry.data.message
        self.date = String(describing: Date(timeIntervalSince1970: entry.data.timestamp))
        self.level = entry.data.level
        self.file = entry.data.file
        self.line = entry.data.line
        self.function = entry.data.function
    }
}

struct LogsView_Previews: PreviewProvider {
    static var previews: some View {
        LogsListView(entries: LogEntry.generate(20))
    }
}
