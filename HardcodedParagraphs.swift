import Foundation

/// A demo-only collection of hardcoded paragraph splits for a specific PDF.
/// This mapping is intended for demonstration purposes and provides paragraphs
/// for given page indices (0-based). If no entry exists for a requested page,
/// `nil` is returned.
///
/// To extend this for more pages, add entries to the `_paragraphsByPage` dictionary
/// with the page index as the key and an array of paragraph strings as the value.
public enum HardcodedParagraphs {
    /// Returns the paragraphs for a given page index, or `nil` if none exist.
    /// - Parameter pageIndex: The zero-based index of the page.
    /// - Returns: An array of paragraph strings or `nil` if no paragraphs are hardcoded for that page.
    public static func paragraphs(for pageIndex: Int) -> [String]? {
        return _paragraphsByPage[pageIndex]
    }

    private static let _paragraphsByPage: [Int: [String]] = [
        0: [
            """
            Created for testing PDFObject, this PDF contains overlapping text that
            is not easily extractable by other means.
            """,
            """
            The first text on the page is a string of characters with specific
            cryptographic and computer science terms.
            """,
            """
            It includes words like blockchain, hash, proof-of-work, and zero-knowledge
            proof, among others, arranged to test text extraction.
            """,
            """
            The text also contains many repetitions of the term 'Lorem ipsum dolor sit
            amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut
            labore et dolore magna aliqua.'
            """,
            """
            This is followed by a series of paragraphs with typical placeholder text
            used in publishing and graphic design.
            """,
            """
            The goal is to ensure that each paragraph is correctly identified and
            separated when the PDF content is parsed.
            """,
            """
            Despite the complex layering and overlapping, the text should be
            programmatically accessible in discrete paragraphs as shown here.
            """,
            """
            Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
            """
        ],
        1: [
            """
            This is page 2. It continues with more sample paragraphs to demonstrate
            paragraph splitting.
            """,
            """
            Paragraph two starts with a brief introduction to the demo content, intended
            to test the hardcoded paragraph functionality.
            """,
            """
            The content includes a mix of short and longer paragraphs to cover various
            edge cases in text extraction.
            """,
            """
            Some paragraphs contain punctuation, special characters, and line breaks
            to ensure robustness.
            """,
            """
            For example, the use of commas, periods, and even question marks? All must
            be handled correctly.
            """,
            """
            Additionally, some paragraphs are intentionally short.
            """,
            """
            Others span multiple lines to simulate real-world document formatting.
            """,
            """
            The final paragraph contains a conclusion to this demo set of paragraphs,
            wrapping up the example content.
            """,
            """
            Thank you for reviewing this sample data for paragraph extraction.
            """
        ]
    ]
}
