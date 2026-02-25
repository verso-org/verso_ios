import Foundation

struct SubtitleCue: Identifiable {
    let id: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
}

enum SubtitleParser {
    /// Parses WebVTT/SRT content into an array of subtitle cues sorted by start time.
    static func parseWebVTT(_ content: String) -> [SubtitleCue] {
        // Normalize line endings: \r\n → \n, lone \r → \n
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = normalized.components(separatedBy: "\n")
        var cues: [SubtitleCue] = []
        var index = 0
        var cueId = 0

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)

            // Look for timing lines: "00:01:23.456 --> 00:01:25.789"
            if line.contains("-->") {
                let parts = line.components(separatedBy: "-->")
                guard parts.count == 2,
                      let start = parseTimestamp(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
                      let end = parseTimestamp(
                        // Strip position/alignment metadata after the end time
                        parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                            .components(separatedBy: " ").first ?? ""
                      )
                else {
                    index += 1
                    continue
                }

                // Collect text lines until blank line or end
                index += 1
                var textLines: [String] = []
                while index < lines.count {
                    let textLine = lines[index]
                    if textLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        break
                    }
                    textLines.append(textLine)
                    index += 1
                }

                let raw = textLines.joined(separator: "\n")
                let text = stripTags(raw)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !text.isEmpty {
                    cues.append(SubtitleCue(id: cueId, startTime: start, endTime: end, text: text))
                    cueId += 1
                }
            } else {
                index += 1
            }
        }

        let sorted = cues.sorted { $0.startTime < $1.startTime }
        print("[Subtitle] parsed \(sorted.count) cues from \(content.count) chars")
        if sorted.count >= 3 {
            for i in 0..<min(3, sorted.count) {
                let c = sorted[i]
                print("[Subtitle]   cue \(i): \(String(format: "%.2f", c.startTime))-\(String(format: "%.2f", c.endTime)) \"\(c.text.prefix(60))\"")
            }
        }
        return sorted
    }

    /// Parses a WebVTT timestamp like "00:01:23.456" or "01:23.456" into seconds.
    private static func parseTimestamp(_ string: String) -> TimeInterval? {
        // Remove any trailing metadata (e.g. position:10%)
        let clean = string.components(separatedBy: " ").first ?? string
        let parts = clean.components(separatedBy: ":")
        guard parts.count >= 2 else { return nil }

        if parts.count == 3 {
            // HH:MM:SS.mmm
            guard let hours = Double(parts[0]),
                  let minutes = Double(parts[1]),
                  let seconds = Double(parts[2].replacingOccurrences(of: ",", with: "."))
            else { return nil }
            return hours * 3600 + minutes * 60 + seconds
        } else {
            // MM:SS.mmm
            guard let minutes = Double(parts[0]),
                  let seconds = Double(parts[1].replacingOccurrences(of: ",", with: "."))
            else { return nil }
            return minutes * 60 + seconds
        }
    }

    /// Strips HTML tags and SSA/ASS override tags from subtitle text.
    /// Handles unmatched `<` gracefully (preserves the content instead of eating it).
    private static func stripTags(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        var i = text.startIndex

        while i < text.endIndex {
            let char = text[i]

            if char == "<" {
                // Look for closing `>` — if found, skip the tag; if not, keep the `<`
                if let closeIndex = text[text.index(after: i)...].firstIndex(of: ">") {
                    i = text.index(after: closeIndex)
                } else {
                    // No closing `>` — not a real tag, keep the character
                    result.append(char)
                    i = text.index(after: i)
                }
            } else if char == "{" {
                // Strip SSA/ASS override tags like {\an8}, {\b1}, {\pos(x,y)}
                if let closeIndex = text[text.index(after: i)...].firstIndex(of: "}"),
                   text[text.index(after: i)] == "\\" {
                    i = text.index(after: closeIndex)
                } else {
                    result.append(char)
                    i = text.index(after: i)
                }
            } else {
                result.append(char)
                i = text.index(after: i)
            }
        }

        return result
    }
}
