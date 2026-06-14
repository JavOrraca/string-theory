import SwiftUI
import StringTheoryCore

/// Post-onboarding setup sheet — change instrument and handedness, which drive
/// every diagram in the app (the prototype's global control bar).
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(alignment: .leading, spacing: 28) {
                    group("INSTRUMENT") {
                        HStack(spacing: 4) {
                            seg("Guitar", selected: model.instrument == .guitar) { model.instrument = .guitar }
                            seg("Bass", selected: model.instrument == .bass) { model.instrument = .bass }
                        }
                    }
                    group("HANDEDNESS") {
                        HStack(spacing: 4) {
                            seg("Right", selected: !model.isLeftHanded) { model.isLeftHanded = false }
                            seg("Left", selected: model.isLeftHanded) { model.isLeftHanded = true }
                        }
                    }
                    Text("Instrument and handedness drive every diagram in the app.")
                        .font(Typography.body(13))
                        .foregroundStyle(Theme.Palette.textDim)
                    Spacer()
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.Palette.phosphor)
                }
            }
        }
    }

    @ViewBuilder
    private func group(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).sectionLabel()
            content()
                .padding(4)
                .background(Theme.Palette.panelDeep, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.Palette.hairline, lineWidth: 1))
        }
    }

    @ViewBuilder
    private func seg(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Typography.display(14, weight: .semibold))
                .foregroundStyle(selected ? Color(oklchL: 0.16, c: 0.03, h: 150) : Theme.Palette.textDim)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(selected ? Theme.Palette.phosphor : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                .glow(selected ? Theme.Palette.phosphor : .clear, radius: selected ? 10 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

#Preview {
    SettingsView().environment(AppModel())
}
