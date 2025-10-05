#if os(visionOS)

import SwiftUI

// Assume PageContent and RecognizedWord exist elsewhere, do not redefine them
// struct PageContent { ... }
// struct RecognizedWord { ... }

/// Segments paragraphs from a given page content.
/// - Parameter page: The page content to segment.
/// - Returns: An array of ParagraphItem representing the paragraphs.
public func segmentParagraphs(from page: PageContent) -> [ParagraphItem] {
    // Constants for thresholds
    let lineGapThreshold: CGFloat = 6.0
    let paragraphGapThreshold: CGFloat = 18.0

    // Helper: Normalize line endings to \n
    func normalizeLineEndings(_ text: String) -> String {
        // Replace \r\n and \r with \n
        return text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    // Helper: Collapse internal whitespace (including newlines) to single spaces and trim
    func collapseWhitespace(_ text: String) -> String {
        let components = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return components.joined(separator: " ")
    }

    // Helper: Split by blank lines (two or more \n)
    func splitByBlankLines(_ text: String) -> [String] {
        // Split by regex for two or more \n, but since no regex, split manually:
        var paragraphs: [String] = []
        var currentParagraphLines: [String] = []

        let lines = text.components(separatedBy: "\n")
        var blankLineCount = 0

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                blankLineCount += 1
            } else {
                if blankLineCount >= 1 && !currentParagraphLines.isEmpty {
                    let paragraph = currentParagraphLines.joined(separator: "\n")
                    paragraphs.append(paragraph)
                    currentParagraphLines.removeAll()
                }
                blankLineCount = 0
                currentParagraphLines.append(line)
            }
        }
        if !currentParagraphLines.isEmpty {
            paragraphs.append(currentParagraphLines.joined(separator: "\n"))
        }
        return paragraphs
    }

    // If rawText available and non-empty after trimming, use that to split
    let rawNormalized = normalizeLineEndings(page.rawText)
    let rawTrimmed = rawNormalized.trimmingCharacters(in: .whitespacesAndNewlines)
    if !rawTrimmed.isEmpty {
        let rawParagraphs = splitByBlankLines(rawNormalized)
            .map { collapseWhitespace($0) }
            .filter { !$0.isEmpty }

        return rawParagraphs.enumerated().map { index, paragraphText in
            ParagraphItem(
                id: deterministicUUID(from: page.id.uuidString + "-para-\(index)"),
                index: index,
                text: paragraphText
            )
        }
    }

    // Otherwise, reconstruct from words

    // Sort words by rect.minY, then rect.minX
    let sortedWords = page.words.sorted { (lhs, rhs) -> Bool in
        if lhs.rect.minY != rhs.rect.minY {
            return lhs.rect.minY < rhs.rect.minY
        }
        return lhs.rect.minX < rhs.rect.minX
    }

    // Group words into lines
    struct Line {
        var words: [RecognizedWord]
        var baselineY: CGFloat { words.first?.rect.minY ?? 0 }
    }

    var lines: [Line] = []
    for word in sortedWords {
        if let lastLine = lines.last {
            let verticalGap = word.rect.minY - lastLine.baselineY
            if verticalGap > lineGapThreshold {
                // Start new line
                lines.append(Line(words: [word]))
            } else {
                // Same line
                lines[lines.count - 1].words.append(word)
            }
        } else {
            lines.append(Line(words: [word]))
        }
    }

    // Group lines into paragraphs
    struct Paragraph {
        var lines: [Line]
    }

    var paragraphs: [Paragraph] = []
    for line in lines {
        if let lastParagraph = paragraphs.last {
            if let lastLine = lastParagraph.lines.last {
                let verticalGap = line.baselineY - lastLine.baselineY
                if verticalGap > paragraphGapThreshold {
                    // Start new paragraph
                    paragraphs.append(Paragraph(lines: [line]))
                } else {
                    // Same paragraph
                    paragraphs[paragraphs.count - 1].lines.append(line)
                }
            } else {
                paragraphs[paragraphs.count - 1].lines.append(line)
            }
        } else {
            paragraphs.append(Paragraph(lines: [line]))
        }
    }

    // Join words in lines by space, join lines in paragraph by spaces
    let paragraphTexts = paragraphs.map { paragraph in
        paragraph.lines.map { line in
            line.words.map { $0.text }.joined(separator: " ")
        }.joined(separator: " ")
    }.filter { !$0.isEmpty }

    return paragraphTexts.enumerated().map { index, text in
        ParagraphItem(
            id: deterministicUUID(from: page.id.uuidString + "-para-\(index)"),
            index: index,
            text: text
        )
    }
}

// Lightweight deterministic UUID generator from a string using Swift's Hasher and seeding bytes
// Note: This is not cryptographically secure but suitable for stable UUID generation during a session.
private func deterministicUUID(from string: String) -> UUID {
    var hasher = Hasher()
    hasher.combine(string)
    let h1 = UInt64(bitPattern: Int64(hasher.finalize()))
    var hasher2 = Hasher()
    hasher2.combine(string + "::2")
    let h2 = UInt64(bitPattern: Int64(hasher2.finalize()))

    var bytes = [UInt8](repeating: 0, count: 16)
    withUnsafeBytes(of: h1.bigEndian) { raw in
        for i in 0..<8 { bytes[i] = raw[i] }
    }
    withUnsafeBytes(of: h2.bigEndian) { raw in
        for i in 0..<8 { bytes[8 + i] = raw[i] }
    }
    // Set UUID version 4 bits (0100) in byte 6
    bytes[6] = (bytes[6] & 0x0F) | 0x40
    // Set variant bits (10xx) in byte 8
    bytes[8] = (bytes[8] & 0x3F) | 0x80

    return UUID(uuid: (
        bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
        bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
    ))
}

#Preview {
    let words: [RecognizedWord] = []
    let page = PageContent(pageIndex: 0, rawText: (
        [
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
            "Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
            "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
            "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.",
            "Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
        ].joined(separator: "\n\n")
    ), words: words)
    let paragraphs = segmentParagraphs(from: page)
    List(paragraphs) { p in
        VStack(alignment: .leading) {
            Text("Paragraph \((p.index + 1))").font(.headline)
            Text(p.text).font(.subheadline)
        }
    }
}

#endif
