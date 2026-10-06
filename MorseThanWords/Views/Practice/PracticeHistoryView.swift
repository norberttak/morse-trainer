import SwiftData
import SwiftUI

struct PracticeHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PracticeSession.date, order: .reverse) private var sessions: [PracticeSession]
    @State private var isConfirmingDeleteAll = false

    var body: some View {
        List {
            ForEach(sessions) { session in
                NavigationLink {
                    PracticeSessionDetailView(session: session)
                } label: {
                    PracticeSessionRow(session: session)
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    modelContext.delete(sessions[index])
                }
            }
        }
        .overlay {
            if sessions.isEmpty {
                ContentUnavailableView {
                    Label("No Sessions Yet", systemImage: "clock")
                } description: {
                    // The default description gray is just below 4.5:1.
                    Text("Completed practice sessions appear here.")
                        .foregroundStyle(.footnoteText)
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            if !sessions.isEmpty {
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        isConfirmingDeleteAll = true
                    } label: {
                        Text("Delete All").foregroundStyle(.destructiveText)
                    }
                    .accessibilityIdentifier("deleteAllButton")
                }
            }
        }
        .confirmationDialog("Delete all practice sessions?", isPresented: $isConfirmingDeleteAll, titleVisibility: .visible) {
            Button("Delete All", role: .destructive) {
                for session in sessions {
                    modelContext.delete(session)
                }
            }
            .accessibilityIdentifier("confirmDeleteAllButton")
        }
    }
}

private struct PracticeSessionRow: View {
    let session: PracticeSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.date, format: .dateTime.day().month().year().hour().minute())
                .font(.headline)
            Text("\(session.count) characters · \(Int(session.characterWPM)) WPM")
                .font(.subheadline)
            Text(session.characterSet)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("historyRow")
    }
}

private struct PracticeSessionDetailView: View {
    let session: PracticeSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LabeledContent("Characters", value: "\(session.count) in groups of \(session.groupSize)")
                LabeledContent("Speed", value: Self.speedText(session))
                LabeledContent("Character set") {
                    Text(session.characterSet).monospaced()
                }
                Divider()
                RevealView(groups: session.groups)
            }
            .padding()
        }
        .navigationTitle(Text(session.date, format: .dateTime.day().month().hour().minute()))
        .navigationBarTitleDisplayMode(.inline)
    }

    private static func speedText(_ session: PracticeSession) -> String {
        let character = Int(session.characterWPM)
        let effective = Int(session.effectiveWPM)
        return character == effective ? "\(character) WPM" : "\(character) WPM (Farnsworth \(effective) WPM)"
    }
}
