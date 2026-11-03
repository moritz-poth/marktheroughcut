import AVFoundation

/// What the app needs to know about a video: frame timing and the timecode stored in the file.
public struct VideoInfo: Sendable {
    /// Duration of one frame in the video's time base (e.g. 1001/24000 s for 23.976).
    public var frameDuration: CMTime
    public var frameCount: Int
    public var format: TimecodeFormat
    /// Timecode of the first frame (frames since 00:00:00:00). 0 if the file has none.
    public var startFrame: Int
    public var hasTimecode: Bool

    public var fpsReal: Double { Double(frameDuration.timescale) / Double(frameDuration.value) }

    public func time(ofIndex i: Int) -> CMTime {
        CMTime(value: CMTimeValue(max(0, i)) * frameDuration.value, timescale: frameDuration.timescale)
    }

    public func index(at time: CMTime) -> Int {
        // a tiny bias so 0.999999 of a frame counts as the frame it really is
        min(max(0, Int((time.seconds * fpsReal + 1e-4).rounded(.down))), max(0, frameCount - 1))
    }

    /// Timecode frame number (as Avid counts) of a frame index in the file.
    public func tcFrame(ofIndex i: Int) -> Int { startFrame + i }
    public func index(ofTcFrame f: Int) -> Int { f - startFrame }

    public static func load(_ asset: AVURLAsset) async throws -> VideoInfo {
        guard let video = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "MarkTheRoughcut", code: 1, userInfo: [NSLocalizedDescriptionKey: "This file has no video."])
        }
        var frameDuration = try await video.load(.minFrameDuration)
        if !frameDuration.isValid || frameDuration.value == 0 {
            let rate = try await video.load(.nominalFrameRate)
            frameDuration = CMTime(value: 1000, timescale: CMTimeScale((Double(rate > 0 ? rate : 25) * 1000).rounded()))
        }
        let duration = try await asset.load(.duration)
        let fps = Double(frameDuration.timescale) / Double(frameDuration.value)
        let frames = max(1, Int((duration.seconds * fps).rounded()))
        var info = VideoInfo(frameDuration: frameDuration, frameCount: frames,
                             format: TimecodeFormat(fps: Int(fps.rounded())), startFrame: 0, hasTimecode: false)
        if let tc = try await readTimecode(asset) {
            info.format = tc.format
            info.startFrame = tc.start
            info.hasTimecode = true
        }
        return info
    }

    /// First sample of the timecode track (tmcd): frame number plus counting (fps, drop frame).
    private static func readTimecode(_ asset: AVURLAsset) async throws -> (format: TimecodeFormat, start: Int)? {
        guard let track = try await asset.loadTracks(withMediaType: .timecode).first,
              let desc = try await track.load(.formatDescriptions).first else { return nil }
        let quanta = Int(CMTimeCodeFormatDescriptionGetFrameQuanta(desc))
        let flags = CMTimeCodeFormatDescriptionGetTimeCodeFlags(desc)
        let format = TimecodeFormat(fps: quanta, dropFrame: flags & kCMTimeCodeFlag_DropFrame != 0)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        guard reader.canAdd(output) else { return nil }
        reader.add(output)
        guard reader.startReading() else { return nil }
        defer { reader.cancelReading() }
        // the first buffers can be empty markers: take the first one that carries data
        var found: CMBlockBuffer?
        for _ in 0..<16 {
            guard let sample = output.copyNextSampleBuffer() else { break }
            if let b = CMSampleBufferGetDataBuffer(sample), CMBlockBufferGetDataLength(b) >= 4 {
                found = b
                break
            }
        }
        guard let block = found else { return nil }
        var value: Int64 = 0
        switch CMFormatDescriptionGetMediaSubType(desc) {
        case kCMTimeCodeFormatType_TimeCode64:
            var be: Int64 = 0
            guard CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: 8, destination: &be) == noErr else { return nil }
            value = Int64(bigEndian: be)
        default: // 'tmcd': 32-bit frame number
            var be: Int32 = 0
            guard CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: 4, destination: &be) == noErr else { return nil }
            value = Int64(Int32(bigEndian: be))
        }
        return (format, Int(value))
    }
}
