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
    
    @State var isExpanded = true
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Text(key)
                    .bold()
                    .italic()
                if isExpanded {
                    Text(String(describing: value))
                        .font(.system(size: 14, design: .monospaced))
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
