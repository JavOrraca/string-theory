import SwiftUI
import StringTheoryCore

/// Scale Explorer — pick a key + scale, the neck redraws. Phase 2 shows a live
/// degree readout from the core; key/scale chips + the 12-fret neck arrive in Phase 4.
struct ScaleExplorerView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            AppBackground()
            VStack(alignment: .leading, spacing: 14) {
                Text("STAGE 04 · SCALES & KEYS").sectionLabel()
                Text("Scale Explorer").font(Typography.display(28))

                FretboardPlaceholder()

                let degrees = scaleMap(key: model.scaleKey, scale: model.scaleType)
                    .sorted { $0.value.interval < $1.value.interval }

                Text("\(model.scaleKey.name) \(model.scaleType.label)")
                    .font(Typography.mono(13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.signalCyan)
                Text(degrees.map(\.key.name).joined(separator: " · "))
                    .font(Typography.display(22))
                Text("Key + scale selectors and the live neck land in Phase 4.")
                    .font(Typography.body(13))
                    .foregroundStyle(Theme.Palette.textDim)
                Spacer()
            }
            .padding(22)
        }
    }
}
