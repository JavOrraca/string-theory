import AVFoundation

/// The single place that sets the shared audio session category. `.playback`
/// for output only; `.playAndRecord` while the tuner needs the mic (and still
/// wants reference tones). Never throws to the caller; failures are logged so a
/// session hiccup leaves playback working.
enum AudioSessionController {
    static func activate(_ category: AVAudioSession.Category) {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            let options: AVAudioSession.CategoryOptions =
                category == .playAndRecord ? [.defaultToSpeaker, .allowBluetoothHFP] : []
            try session.setCategory(category, mode: .default, options: options)
            try session.setActive(true)
        } catch {
            print("AudioSessionController failed to set \(category): \(error)")
        }
        #endif
    }
}
