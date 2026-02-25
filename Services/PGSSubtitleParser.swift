import UIKit

class PGSSubtitleCue {
    let startTime: TimeInterval
    var endTime: TimeInterval
    let imageWidth: Int
    let imageHeight: Int
    let screenX: Int
    let screenY: Int
    let screenWidth: Int
    let screenHeight: Int
    // Lazy decompression: store compact RLE + palette, decompress only on display
    private let renderables: [RenderableObject]
    // Cache decompressed image to avoid re-decompressing every frame
    private var cachedImage: UIImage?

    struct RenderableObject {
        let x: Int
        let y: Int
        let width: Int
        let height: Int
        let rleData: Data
        let palette: [UInt8]  // Flat array: 256 entries × 4 bytes (R,G,B,A premultiplied)
    }

    func makeImage() -> UIImage? {
        if let cachedImage { return cachedImage }
        guard imageWidth > 0, imageHeight > 0, !renderables.isEmpty else { return nil }

        let pixelData: Data
        if renderables.count == 1 {
            let obj = renderables[0]
            guard let pixels = PGSSubtitleParser.decompressRLE(obj.rleData, width: obj.width, height: obj.height, palette: obj.palette) else { return nil }
            pixelData = pixels
        } else {
            // Composite multiple objects into bounding box
            var composited = Data(repeating: 0, count: imageWidth * imageHeight * 4)
            for obj in renderables {
                guard let pixels = PGSSubtitleParser.decompressRLE(obj.rleData, width: obj.width, height: obj.height, palette: obj.palette) else { continue }
                let relX = obj.x - screenX
                let relY = obj.y - screenY
                for row in 0..<obj.height {
                    let srcStart = row * obj.width * 4
                    let dstRow = relY + row
                    guard dstRow < imageHeight else { break }
                    let dstBase = (dstRow * imageWidth + relX) * 4
                    for col in 0..<obj.width {
                        let dstCol = relX + col
                        guard dstCol < imageWidth else { break }
                        let s = srcStart + col * 4
                        let d = dstBase + col * 4
                        guard s + 3 < pixels.count, d + 3 < composited.count,
                              pixels[s + 3] > 0 else { continue }
                        composited[d] = pixels[s]
                        composited[d+1] = pixels[s+1]
                        composited[d+2] = pixels[s+2]
                        composited[d+3] = pixels[s+3]
                    }
                }
            }
            pixelData = composited
        }

        guard pixelData.count == imageWidth * imageHeight * 4 else { return nil }
        let bytesPerRow = imageWidth * 4
        guard let provider = CGDataProvider(data: pixelData as CFData),
              let cgImage = CGImage(
                  width: imageWidth,
                  height: imageHeight,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: bytesPerRow,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent
              )
        else { return nil }
        let image = UIImage(cgImage: cgImage)
        cachedImage = image
        return image
    }

    init(startTime: TimeInterval, endTime: TimeInterval,
         renderables: [RenderableObject],
         imageWidth: Int, imageHeight: Int,
         screenX: Int, screenY: Int, screenWidth: Int, screenHeight: Int) {
        self.startTime = startTime
        self.endTime = endTime
        self.renderables = renderables
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.screenX = screenX
        self.screenY = screenY
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.cachedImage = nil
    }
}

enum PGSSubtitleParser {
    static func parse(_ data: Data) -> [PGSSubtitleCue] {
        let segments = readSegments(data)
        let displaySets = groupDisplaySets(segments)
        let cues = buildCues(displaySets)
        return cues
    }

    // MARK: - Segment types

    private static let segmentTypePCS: UInt8 = 0x16
    private static let segmentTypeWDS: UInt8 = 0x17
    private static let segmentTypePDS: UInt8 = 0x14
    private static let segmentTypeODS: UInt8 = 0x15
    private static let segmentTypeEND: UInt8 = 0x80

    // MARK: - Internal types

    private struct PGSSegment {
        let pts: UInt32
        let type: UInt8
        let payload: Data
    }

    private struct PCSObject {
        let objectId: UInt16
        let windowId: UInt8
        let x: Int
        let y: Int
    }

    private struct PCS {
        let videoWidth: Int
        let videoHeight: Int
        let compositionNumber: UInt16
        let compositionState: UInt8
        let objects: [PCSObject]
    }

    private struct WDSWindow {
        let windowId: UInt8
        let x: Int
        let y: Int
        let width: Int
        let height: Int
    }

    private typealias PaletteEntry = (r: UInt8, g: UInt8, b: UInt8, a: UInt8)

    private struct PGSObject {
        let objectId: UInt16
        let width: Int
        let height: Int
        let rleData: Data
    }

    private struct DisplaySet {
        let pts: UInt32
        var pcs: PCS?
        var windows: [WDSWindow] = []
        var palette: [Int: PaletteEntry] = [:]
        var objects: [UInt16: PGSObject] = [:]
    }

    // MARK: - Read segments

    private static func readSegments(_ data: Data) -> [PGSSegment] {
        var segments: [PGSSegment] = []
        var offset = 0
        let count = data.count

        while offset + 13 <= count {
            // Magic bytes "PG" (0x50 0x47)
            guard data[offset] == 0x50, data[offset + 1] == 0x47 else {
                offset += 1
                continue
            }

            let pts = readUInt32(data, offset: offset + 2)
            // DTS at offset+6, ignored
            let segType = data[offset + 10]
            let payloadSize = Int(readUInt16(data, offset: offset + 11))

            let payloadStart = offset + 13
            guard payloadStart + payloadSize <= count else { break }

            let payload = data[payloadStart..<(payloadStart + payloadSize)]
            segments.append(PGSSegment(pts: pts, type: segType, payload: Data(payload)))
            offset = payloadStart + payloadSize
        }

        return segments
    }

    // MARK: - Group into display sets

    private static func groupDisplaySets(_ segments: [PGSSegment]) -> [DisplaySet] {
        var sets: [DisplaySet] = []
        var current: DisplaySet?

        for seg in segments {
            switch seg.type {
            case segmentTypePCS:
                // PCS starts a new display set
                if let prev = current {
                    sets.append(prev)
                }
                current = DisplaySet(pts: seg.pts)
                current?.pcs = parsePCS(seg.payload)

            case segmentTypeWDS:
                current?.windows = parseWDS(seg.payload)

            case segmentTypePDS:
                let entries = parsePDS(seg.payload)
                for (idx, entry) in entries {
                    current?.palette[idx] = entry
                }

            case segmentTypeODS:
                if let obj = parseODS(seg.payload, existing: current?.objects) {
                    current?.objects[obj.objectId] = obj
                }

            case segmentTypeEND:
                if let set = current {
                    sets.append(set)
                    current = nil
                }

            default:
                break
            }
        }

        if let remaining = current {
            sets.append(remaining)
        }

        return sets
    }

    // MARK: - Parse PCS

    private static func parsePCS(_ data: Data) -> PCS? {
        guard data.count >= 11 else { return nil }

        let videoWidth = Int(readUInt16(data, offset: 0))
        let videoHeight = Int(readUInt16(data, offset: 2))
        // frame rate byte at 4, ignored
        let compositionNumber = readUInt16(data, offset: 5)
        let compositionState = data[7]
        // palette update flag at 8, ignored
        // palette id at 9
        let objectCount = Int(data[10])

        var objects: [PCSObject] = []
        var offset = 11
        for _ in 0..<objectCount {
            guard offset + 8 <= data.count else { break }
            let objectId = readUInt16(data, offset: offset)
            let windowId = data[offset + 2]
            // cropped flag at offset+3
            let x = Int(readUInt16(data, offset: offset + 4))
            let y = Int(readUInt16(data, offset: offset + 6))
            objects.append(PCSObject(objectId: objectId, windowId: windowId, x: x, y: y))
            offset += 8
        }

        return PCS(
            videoWidth: videoWidth,
            videoHeight: videoHeight,
            compositionNumber: compositionNumber,
            compositionState: compositionState,
            objects: objects
        )
    }

    // MARK: - Parse WDS

    private static func parseWDS(_ data: Data) -> [WDSWindow] {
        guard data.count >= 1 else { return [] }
        let windowCount = Int(data[0])
        var windows: [WDSWindow] = []
        var offset = 1

        for _ in 0..<windowCount {
            guard offset + 9 <= data.count else { break }
            let windowId = data[offset]
            let x = Int(readUInt16(data, offset: offset + 1))
            let y = Int(readUInt16(data, offset: offset + 3))
            let width = Int(readUInt16(data, offset: offset + 5))
            let height = Int(readUInt16(data, offset: offset + 7))
            windows.append(WDSWindow(windowId: windowId, x: x, y: y, width: width, height: height))
            offset += 9
        }

        return windows
    }

    // MARK: - Parse PDS (palette)

    private static func parsePDS(_ data: Data) -> [(Int, PaletteEntry)] {
        // palette ID at 0, version at 1
        guard data.count >= 2 else { return [] }
        var entries: [(Int, PaletteEntry)] = []
        var offset = 2

        while offset + 5 <= data.count {
            let idx = Int(data[offset])
            let y = data[offset + 1]
            let cr = data[offset + 2]
            let cb = data[offset + 3]
            let alpha = data[offset + 4]

            let (r, g, b) = ycbcrToRGB(y: y, cb: cb, cr: cr)
            entries.append((idx, (r: r, g: g, b: b, a: alpha)))
            offset += 5
        }

        return entries
    }

    // MARK: - Parse ODS (object)

    private static func parseODS(_ data: Data, existing: [UInt16: PGSObject]?) -> PGSObject? {
        guard data.count >= 7 else { return nil }

        let objectId = readUInt16(data, offset: 0)
        // version at 2
        let sequenceFlag = data[3]

        let isFirst = (sequenceFlag & 0x80) != 0
        let isLast = (sequenceFlag & 0x40) != 0

        if isFirst {
            // First (or only) segment: has width/height after 3-byte data length
            guard data.count >= 11 else { return nil }
            // 3 bytes for total data length at offset 4..6
            let width = Int(readUInt16(data, offset: 7))
            let height = Int(readUInt16(data, offset: 9))
            let rleData = data.count > 11 ? Data(data[11...]) : Data()

            return PGSObject(objectId: objectId, width: width, height: height, rleData: rleData)
        } else {
            // Continuation segment: append RLE data to existing object
            guard var obj = existing?[objectId] else { return nil }
            let appendData = data.count > 4 ? Data(data[4...]) : Data()
            var combined = obj.rleData
            combined.append(appendData)
            obj = PGSObject(objectId: obj.objectId, width: obj.width, height: obj.height, rleData: combined)

            return obj
        }
    }

    // MARK: - Build cues from display sets (lazy — no RLE decompression)

    private static func buildCues(_ displaySets: [DisplaySet]) -> [PGSSubtitleCue] {
        var cues: [PGSSubtitleCue] = []
        var activePalette: [Int: PaletteEntry] = [:]

        for (i, ds) in displaySets.enumerated() {
            guard let pcs = ds.pcs else { continue }

            // Merge palette entries (epoch start resets, normal merges)
            if pcs.compositionState == 0x00 {
                for (idx, entry) in ds.palette {
                    activePalette[idx] = entry
                }
            } else {
                activePalette = ds.palette
            }

            // "Clear" display set — no objects means end of previous cue
            if pcs.objects.isEmpty {
                if !cues.isEmpty {
                    let endTime = ptsToSeconds(ds.pts)
                    cues[cues.count - 1].endTime = endTime
                }
                continue
            }

            // Snapshot the current palette as a flat lookup table (256 × 4 bytes)
            let flatPalette = flattenPalette(activePalette)

            // Collect renderable objects with raw RLE data (no decompression yet)
            var renderables: [PGSSubtitleCue.RenderableObject] = []
            var minX = Int.max, minY = Int.max, maxX = 0, maxY = 0
            for pcsObj in pcs.objects {
                guard let obj = ds.objects[pcsObj.objectId], obj.width > 0, obj.height > 0 else { continue }
                renderables.append(PGSSubtitleCue.RenderableObject(
                    x: pcsObj.x, y: pcsObj.y,
                    width: obj.width, height: obj.height,
                    rleData: obj.rleData,
                    palette: flatPalette
                ))
                minX = min(minX, pcsObj.x)
                minY = min(minY, pcsObj.y)
                maxX = max(maxX, pcsObj.x + obj.width)
                maxY = max(maxY, pcsObj.y + obj.height)
            }
            guard !renderables.isEmpty else { continue }

            // Find the next display set's PTS as a default end time
            var endTime = ptsToSeconds(ds.pts) + 10.0
            for j in (i + 1)..<displaySets.count {
                if displaySets[j].pcs != nil {
                    endTime = ptsToSeconds(displaySets[j].pts)
                    break
                }
            }

            let bbW = maxX - minX, bbH = maxY - minY
            let cue = PGSSubtitleCue(
                startTime: ptsToSeconds(ds.pts),
                endTime: endTime,
                renderables: renderables,
                imageWidth: bbW,
                imageHeight: bbH,
                screenX: minX,
                screenY: minY,
                screenWidth: pcs.videoWidth,
                screenHeight: pcs.videoHeight
            )
            cues.append(cue)
        }

        return cues.sorted { $0.startTime < $1.startTime }
    }

    /// Flatten palette dictionary into a contiguous 256×4 byte array for fast indexed lookup during RLE decompression.
    private static func flattenPalette(_ palette: [Int: PaletteEntry]) -> [UInt8] {
        var flat = [UInt8](repeating: 0, count: 256 * 4)
        for (idx, entry) in palette {
            guard idx >= 0 && idx < 256 else { continue }
            let a = UInt16(entry.a)
            let base = idx * 4
            flat[base]     = UInt8((UInt16(entry.r) * a) / 255)
            flat[base + 1] = UInt8((UInt16(entry.g) * a) / 255)
            flat[base + 2] = UInt8((UInt16(entry.b) * a) / 255)
            flat[base + 3] = entry.a
        }
        return flat
    }

    // MARK: - RLE decompression (called on demand per cue)

    static func decompressRLE(
        _ data: Data, width: Int, height: Int, palette: [UInt8]
    ) -> Data? {
        let pixelCount = width * height
        var output = Data(repeating: 0, count: pixelCount * 4)
        var pixelIndex = 0
        var currentLine = 0
        var offset = 0
        let count = data.count

        while offset < count && pixelIndex < pixelCount {
            let byte = data[offset]
            offset += 1

            if byte != 0x00 {
                let base = Int(byte) * 4
                let byteOffset = pixelIndex * 4
                if byteOffset + 3 < output.count && base + 3 < palette.count {
                    output[byteOffset]     = palette[base]
                    output[byteOffset + 1] = palette[base + 1]
                    output[byteOffset + 2] = palette[base + 2]
                    output[byteOffset + 3] = palette[base + 3]
                }
                pixelIndex += 1
            } else {
                guard offset < count else { break }
                let flag = data[offset]
                offset += 1

                if flag == 0x00 {
                    currentLine += 1
                    pixelIndex = currentLine * width
                } else {
                    let top2 = flag >> 6

                    switch top2 {
                    case 0b00:
                        let length = Int(flag & 0x3F)
                        pixelIndex += length

                    case 0b01:
                        guard offset < count else { break }
                        let length = (Int(flag & 0x3F) << 8) | Int(data[offset])
                        offset += 1
                        pixelIndex += length

                    case 0b10:
                        guard offset < count else { break }
                        let length = Int(flag & 0x3F)
                        let colorIndex = Int(data[offset])
                        offset += 1
                        let base = colorIndex * 4
                        if base + 3 < palette.count {
                            let r = palette[base], g = palette[base+1], b = palette[base+2], a = palette[base+3]
                            for _ in 0..<length {
                                guard pixelIndex < pixelCount else { break }
                                let byteOffset = pixelIndex * 4
                                output[byteOffset] = r
                                output[byteOffset+1] = g
                                output[byteOffset+2] = b
                                output[byteOffset+3] = a
                                pixelIndex += 1
                            }
                        } else {
                            pixelIndex += length
                        }

                    case 0b11:
                        guard offset + 1 < count else { break }
                        let length = (Int(flag & 0x3F) << 8) | Int(data[offset])
                        offset += 1
                        let colorIndex = Int(data[offset])
                        offset += 1
                        let base = colorIndex * 4
                        if base + 3 < palette.count {
                            let r = palette[base], g = palette[base+1], b = palette[base+2], a = palette[base+3]
                            for _ in 0..<length {
                                guard pixelIndex < pixelCount else { break }
                                let byteOffset = pixelIndex * 4
                                output[byteOffset] = r
                                output[byteOffset+1] = g
                                output[byteOffset+2] = b
                                output[byteOffset+3] = a
                                pixelIndex += 1
                            }
                        } else {
                            pixelIndex += length
                        }

                    default:
                        break
                    }
                }
            }
        }

        return output
    }

    // MARK: - YCbCr → RGB conversion

    private static func ycbcrToRGB(y: UInt8, cb: UInt8, cr: UInt8) -> (UInt8, UInt8, UInt8) {
        // BT.709 limited range (Y: 16-235, CbCr: 16-240) as used by PGS/Blu-ray
        let yf = 1.164383 * (Double(y) - 16.0)
        let cbf = Double(cb) - 128.0
        let crf = Double(cr) - 128.0

        let r = yf + 1.792741 * crf
        let g = yf - 0.213249 * cbf - 0.532909 * crf
        let b = yf + 2.112402 * cbf

        return (
            UInt8(clamping: Int(r.rounded())),
            UInt8(clamping: Int(g.rounded())),
            UInt8(clamping: Int(b.rounded()))
        )
    }

    // MARK: - Helpers

    private static func ptsToSeconds(_ pts: UInt32) -> TimeInterval {
        Double(pts) / 90000.0
    }

    private static func readUInt16(_ data: Data, offset: Int) -> UInt16 {
        UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
    }

    private static func readUInt32(_ data: Data, offset: Int) -> UInt32 {
        UInt32(data[offset]) << 24 | UInt32(data[offset + 1]) << 16 |
        UInt32(data[offset + 2]) << 8 | UInt32(data[offset + 3])
    }
}
