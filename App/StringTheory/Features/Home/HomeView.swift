import SwiftUI

/// The "Signal Path" home. Phase 2 establishes the header, tab placement, and
/// the push into a lesson; the 5-stage vertical path itself lands in Phase 4.
struct HomeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("STANDARD TUNING · 440Hz").sectionLabel()
                        Text("Your Path").font(Typography.display(32))
                        Text("Signal Path — the 5-stage learning climb — lands in Phase 4.")
                            .font(Typography.body(14))
                            .foregroundStyle(Theme.Palette.textDim)

                        NavigationLink {
                            LessonView()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("STAGE 02 · TABS").sectionLabel()
                                    Text("Lesson 2.3 · Read the riff")
                                        .font(Typography.display(17, weight: .semibold))
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Theme.Palette.phosphor)
                            }
                            .panel()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.Palette.text)
                    }
                    .padding(22)
                }
            }
        }
    }
}
