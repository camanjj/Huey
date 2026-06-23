import Foundation
import SwiftUI

final class DestinationsVM: ObservableObject {

    struct Row: Identifiable {
        let id: ObjectIdentifier
        let identifier: String
        let title: String
        let destination: JSONFormattedLogDestination
    }

    @Published var rows: [Row] = []

    init() {
        reload()
    }

    func reload() {
        rows = Log.destinationsSnapshot().compactMap { dest in
            guard let configurable = dest as? JSONFormattedLogDestination else { return nil }
            let id = DestinationPreferences.identifier(for: dest)
            return Row(
                id: ObjectIdentifier(dest),
                identifier: id,
                title: id,
                destination: configurable
            )
        }
    }

    func setPrettyPrint(_ value: Bool, for row: Row) {
        row.destination.prettyPrint = value
        DestinationPreferences.setPrettyPrint(value, for: row.identifier)
        objectWillChange.send()
    }

    func setEscapeStrings(_ value: Bool, for row: Row) {
        row.destination.escapeStrings = value
        DestinationPreferences.setEscapeStrings(value, for: row.identifier)
        objectWillChange.send()
    }
}

struct DestinationsView: View {

    @StateObject var viewModel = DestinationsVM()

    var body: some View {
        List {
            ForEach(viewModel.rows) { row in
                Section(header: Text(row.title)) {
                    Toggle("Pretty print JSON", isOn: Binding(
                        get: { row.destination.prettyPrint },
                        set: { viewModel.setPrettyPrint($0, for: row) }
                    ))
                    Toggle("Escape strings", isOn: Binding(
                        get: { row.destination.escapeStrings },
                        set: { viewModel.setEscapeStrings($0, for: row) }
                    ))
                }
            }
        }
    }
}

struct DestinationsView_Previews: PreviewProvider {
    static var previews: some View {
        DestinationsView()
    }
}
