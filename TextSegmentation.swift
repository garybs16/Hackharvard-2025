import Foundation

/// Utilities for turning raw extracted text into display paragraphs.
///
/// Rules:
/// - Normalize all line endings to `\n`.
/// - Paragraphs are separated by two-or-more consecutive newlines.
/// - Single newlines inside a paragraph are treated as soft line breaks and replaced with spaces.
/// - Excess whitespace inside paragraphs is collapsed and trimmed.
public enum TextSegmentation {
    public static func paragraphs(from text: String) -> [String] {
        // 1) Normalize line endings
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        // 2) Turn two-or-more newlines into a delimiter we can safely split on
        let delimiter = "\u{241E}PARA\u{241E}" // Record separator-like marker
        let pattern = "\n[^\\S\n]*\n+"
        let ns = normalized as NSString
        let range = NSRange(location: 0, length: ns.length)
        let regex = try? NSRegularExpression(pattern: pattern)
        let withDelimiters = regex?.stringByReplacingMatches(in: normalized, options: [], range: range, withTemplate: delimiter) ?? normalized

        // 3) Split on the delimiter (not on regex)
        let blocks = withDelimiters.components(separatedBy: delimiter)

        // 4) For each block, replace single newlines with spaces, collapse whitespace, and trim
        let cleaned: [String] = blocks.map { block in
            // Replace remaining single newlines (soft breaks) with spaces
            let joined = block.replacingOccurrences(of: "\n", with: " ")
            // Collapse runs of whitespace to a single space
            let collapsed = joined.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            // Trim surrounding whitespace/newlines
            return collapsed.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }

        return cleaned
    }
}
