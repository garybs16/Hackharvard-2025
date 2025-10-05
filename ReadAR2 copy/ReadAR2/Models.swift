#if os(visionOS)

import Foundation
import CoreGraphics

public struct RecognizedWord: Identifiable, Hashable {
    public let id: UUID
    public let text: String
    public let rect: CGRect // page coordinate space
    public init(id: UUID = UUID(), text: String, rect: CGRect) {
        self.id = id
        self.text = text
        self.rect = rect
    }
}

public struct PageContent: Identifiable, Hashable {
    public let id: UUID
    public let pageIndex: Int
    public let rawText: String
    public let words: [RecognizedWord]
    public init(id: UUID = UUID(), pageIndex: Int, rawText: String, words: [RecognizedWord]) {
        self.id = id
        self.pageIndex = pageIndex
        self.rawText = rawText
        self.words = words
    }
}

public struct ParagraphItem: Identifiable, Hashable {
    public let id: UUID
    public let index: Int
    public let text: String
    public init(id: UUID, index: Int, text: String) {
        self.id = id
        self.index = index
        self.text = text
    }
}

#endif
