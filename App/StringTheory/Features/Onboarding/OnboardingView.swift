import SwiftUI
import StringTheoryCore

/// Two-step setup (instrument → handedness). Choices write straight to the
/// shared `AppModel`, exactly as in the prototype.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var step = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(step == 0 ? "STEP 1 / 2 · SETUP" : "STEP 2 / 2 · SETUP")
                .sectionLabel()
                .foregroundStyle(Theme.Palette.phosphor)

            Text(step == 0 ? "Pick your instrument" : "Which hand frets?")
                .font(Typography.display(30))

            Text(step == 0
                 ? "This sets your tuning and how many strings every diagram shows."
                 : "Diagrams mirror so the neck reads exactly how you hold it.")
                .font(Typography.body(15))
                .foregroundStyle(Theme.Palette.textDim)

            VStack(spacing: 14) {
                if step == 0 {
                    choiceCard("Guitar", "6 strings · E A D G B E", selected: model.instrument == .guitar) {
                        model.instrument = .guitar
                    }
                    choiceCard("Bass", "4 strings · E A D G", selected: model.instrument == .bass) {
                        model.instrument = .bass
                    }
                } else {
                    choiceCard("Right-handed", "Nut on the left · low string at bottom", selected: !model.isLeftHanded) {
                        model.isLeftHanded = false
                    }
                    choiceCard("Left-handed", "Nut on the right · fully mirrored", selected: model.isLeftHanded) {
                        model.isLeftHanded = true
                    }
                }
            }
            .padding(.top, 4)

            Spacer()

            Button(step == 0 ? "Continue" : "Enter the path") {
                withAnimation { step == 0 ? (step = 1) : (model.hasOnboarded = true) }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .safeAreaPadding(.top, 40)
    }

    @ViewBuilder
    private func choiceCard(_ title: String, _ subtitle: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(Typography.display(19, weight: .semibold))
                    Text(subtitle).font(Typography.mono(12)).foregroundStyle(Theme.Palette.textDim)
                }
                Spacer()
                Circle()
                    .strokeBorder(selected ? Theme.Palette.phosphor : Theme.Palette.hairline,
                                  lineWidth: selected ? 7 : 2)
                    .frame(width: 24, height: 24)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.panel, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(selected ? Theme.Palette.phosphor : Theme.Palette.hairline,
                                  lineWidth: 1.5)
            )
            .foregroundStyle(Theme.Palette.text)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
