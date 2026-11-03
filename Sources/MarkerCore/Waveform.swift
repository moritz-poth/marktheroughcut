import AVFoundation

/// Peak levels of the whole audio (all channels mixed), `rate` values per second, 0…1.
public struct Waveform: Sendable {
    public static let rate = 200.0
    public var peaks: [Float]

    public init(peaks: [Float]) { self.peaks = peaks }

    /// Reads the audio once at 8 kHz mono (enough for a picture, fast even for long films).
    public static func load(_ asset: AVAsset) async throws -> Waveform? {
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { return nil }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsBigEndianKey: false,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 8000,
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { return nil }
        reader.add(output)
        guard reader.startReading() else { return nil }
        let perPeak = Int(8000 / rate)
        var peaks: [Float] = []
        var current: Float = 0
        var count = 0
        while let sample = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(sample) else { continue }
            let length = CMBlockBufferGetDataLength(block)
            var data = [Float](repeating: 0, count: length / 4)
            _ = data.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: $0.baseAddress!) }
            for v in data {
                current = max(current, abs(v))
                count += 1
                if count == perPeak {
                    peaks.append(min(1, current))
                    current = 0
                    count = 0
                }
            }
        }
        if count > 0 { peaks.append(min(1, current)) }
        guard reader.status != .failed, !peaks.isEmpty else { return nil }
        return Waveform(peaks: peaks)
    }

    /// Highest peak between two times (seconds) – one value per drawn pixel column.
    public func peak(from a: Double, to b: Double) -> Float {
        let i = max(0, Int(a * Self.rate)), j = min(peaks.count, max(i + 1, Int((b * Self.rate).rounded(.up))))
        guard i < j else { return 0 }
        return peaks[i..<j].max() ?? 0
    }
}
