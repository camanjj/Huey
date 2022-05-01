//
//  FilterView.swift
//  
//
//  Created by Cameron Jackson on 4/29/22.
//

import SwiftUI

final class FilterVM: ObservableObject {
    
    @Published var logLevels: Set<LogData.Level> = LogData.Level.storedLogLevels

    enum Action {
        case toggle(LogData.Level)
    }
    
    func perform(_ action: Action) {
        switch action {
        case .toggle(let level):
            if logLevels.contains(level) {
                logLevels.remove(level)
            } else {
                logLevels.insert(level)
            }
            LogData.Level.store(logLevels)
        }
    }
}

struct FilterView: View {
    
    @StateObject var viewModel = FilterVM()
    
    var body: some View {
        List(LogData.Level.allCases) { level in
            Button(action: { viewModel.perform(.toggle(level)) }) {
                HStack {
                    Text(level.string.capitalized)
                    if viewModel.logLevels.contains(level) {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }
}

struct FilterView_Previews: PreviewProvider {
    static var previews: some View {
        FilterView()
    }
}
