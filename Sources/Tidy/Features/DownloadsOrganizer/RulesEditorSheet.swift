import SwiftUI

@MainActor
public class RulesEditorViewModel: ObservableObject {
    @Published public var name: String = ""
    @Published public var matchType: RuleMatchType = .extensions
    @Published public var matchValue: String = ""
    @Published public var destinationFolder: String = ""
    public init() {}
}

public struct RulesEditorSheet: View {
    @Binding public var isPresented: Bool
    public var onAddRule: (OrganizerRule) -> Void
    
    @StateObject private var model = RulesEditorViewModel()
    
    public init(isPresented: Binding<Bool>, onAddRule: @escaping (OrganizerRule) -> Void) {
        self._isPresented = isPresented
        self.onAddRule = onAddRule
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add Organizer Rule")
                .font(.system(size: 18, weight: .bold))
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rule Name:")
                        .font(.system(size: 12, weight: .medium))
                    TextField("e.g. Design Assets", text: $model.name)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Match by:")
                        .font(.system(size: 12, weight: .medium))
                    Picker("", selection: $model.matchType) {
                        ForEach(RuleMatchType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
                
                if model.matchType != .everythingElse {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(matchValueLabel)
                            .font(.system(size: 12, weight: .medium))
                        TextField(matchValuePlaceholder, text: $model.matchValue)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Destination Subfolder:")
                        .font(.system(size: 12, weight: .medium))
                    TextField("e.g. Design", text: $model.destinationFolder)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Add Rule") {
                    let newRule = OrganizerRule(
                        name: model.name.trimmingCharacters(in: .whitespaces),
                        isEnabled: true,
                        matchType: model.matchType,
                        matchValue: model.matchValue.trimmingCharacters(in: .whitespaces),
                        destinationSubfolder: model.destinationFolder.trimmingCharacters(in: .whitespaces),
                        order: 1
                    )
                    onAddRule(newRule)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(TidyTheme.accentColor)
                .disabled(model.name.isEmpty || model.destinationFolder.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
    
    private var matchValueLabel: String {
        switch model.matchType {
        case .extensions: return "Extensions (space separated):"
        case .nameContains: return "Filename contains keyword:"
        case .minSizeMB: return "Minimum size (MB):"
        case .olderThanDays: return "Minimum age (Days):"
        case .everythingElse: return ""
        }
    }
    
    private var matchValuePlaceholder: String {
        switch model.matchType {
        case .extensions: return "e.g. figma sketch psd ai"
        case .nameContains: return "e.g. Invoice"
        case .minSizeMB: return "e.g. 100"
        case .olderThanDays: return "e.g. 14"
        case .everythingElse: return ""
        }
    }
}
