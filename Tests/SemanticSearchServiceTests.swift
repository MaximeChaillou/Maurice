import XCTest
@testable import Maurice

final class SemanticSearchServiceTests: XCTestCase {

    // MARK: - cosineSimilarity

    func testCosineSimilarityIdenticalVectors() {
        let vec = [1.0, 2.0, 3.0]
        let similarity = SemanticSearchService.cosineSimilarity(vec, vec)
        XCTAssertEqual(similarity, 1.0, accuracy: 1e-10)
    }

    func testCosineSimilarityOrthogonalVectors() {
        let vecA = [1.0, 0.0, 0.0]
        let vecB = [0.0, 1.0, 0.0]
        let similarity = SemanticSearchService.cosineSimilarity(vecA, vecB)
        XCTAssertEqual(similarity, 0.0, accuracy: 1e-10)
    }

    func testCosineSimilarityOppositeVectors() {
        let vecA = [1.0, 2.0, 3.0]
        let vecB = [-1.0, -2.0, -3.0]
        let similarity = SemanticSearchService.cosineSimilarity(vecA, vecB)
        XCTAssertEqual(similarity, -1.0, accuracy: 1e-10)
    }

    func testCosineSimilarityEmptyVectors() {
        let similarity = SemanticSearchService.cosineSimilarity([], [])
        XCTAssertEqual(similarity, 0.0)
    }

    func testCosineSimilarityDifferentLengthsReturnsZero() {
        let vecA = [1.0, 2.0]
        let vecB = [1.0, 2.0, 3.0]
        let similarity = SemanticSearchService.cosineSimilarity(vecA, vecB)
        XCTAssertEqual(similarity, 0.0)
    }

    func testCosineSimilarityZeroVectorReturnsZero() {
        let vecA = [0.0, 0.0, 0.0]
        let vecB = [1.0, 2.0, 3.0]
        let similarity = SemanticSearchService.cosineSimilarity(vecA, vecB)
        XCTAssertEqual(similarity, 0.0)
    }

    func testCosineSimilaritySymmetric() {
        let vecA = [1.0, 3.0, 5.0]
        let vecB = [2.0, 4.0, 1.0]
        let simAB = SemanticSearchService.cosineSimilarity(vecA, vecB)
        let simBA = SemanticSearchService.cosineSimilarity(vecB, vecA)
        XCTAssertEqual(simAB, simBA, accuracy: 1e-10)
    }

    func testCosineSimilarityScaledVectorsAreSimilar() {
        let vecA = [1.0, 2.0, 3.0]
        let vecB = [2.0, 4.0, 6.0] // Same direction, scaled by 2
        let similarity = SemanticSearchService.cosineSimilarity(vecA, vecB)
        XCTAssertEqual(similarity, 1.0, accuracy: 1e-10)
    }

    func testCosineSimilarityKnownValue() {
        // vec = [3, 4], magnitude = 5
        // vec = [4, 3], magnitude = 5
        // dot = 24, sim = 24/25 = 0.96
        let similarity = SemanticSearchService.cosineSimilarity([3.0, 4.0], [4.0, 3.0])
        XCTAssertEqual(similarity, 0.96, accuracy: 1e-10)
    }

    // MARK: - extractSnippet

    func testExtractSnippetFindsQueryWord() {
        let content = "This is a long document about Swift programming and testing frameworks."
        let snippet = SemanticSearchService.extractSnippet(from: content, query: "swift")
        XCTAssertTrue(snippet.contains("Swift"))
    }

    func testExtractSnippetReturnsBeginningWhenNoMatch() {
        let content = "This is a document with no matching words at all."
        let snippet = SemanticSearchService.extractSnippet(
            from: content, query: "xyznonexistent"
        )
        // Should return beginning of content up to 120 chars
        XCTAssertTrue(snippet.hasPrefix("This is a document"))
    }

    func testExtractSnippetAddsEllipsisForMiddleMatch() {
        let prefix = String(repeating: "word ", count: 30)
        let content = prefix + "TARGET rest of text"
        let snippet = SemanticSearchService.extractSnippet(from: content, query: "target")
        XCTAssertTrue(snippet.contains("TARGET"))
    }

    func testExtractSnippetAddsLeadingEllipsisWhenTruncated() {
        let prefix = String(repeating: "a ", count: 100)
        let content = prefix + "needle end"
        let snippet = SemanticSearchService.extractSnippet(
            from: content, query: "needle", radius: 20
        )
        XCTAssertTrue(snippet.hasPrefix("…"))
    }

    func testExtractSnippetAddsTrailingEllipsisWhenTruncated() {
        let suffix = String(repeating: " b", count: 100)
        let content = "start needle" + suffix
        let snippet = SemanticSearchService.extractSnippet(
            from: content, query: "needle", radius: 20
        )
        XCTAssertTrue(snippet.hasSuffix("…"))
    }

    func testExtractSnippetReplacesNewlinesWithSpaces() {
        let content = "Line one\nLine two\nLine three with keyword"
        let snippet = SemanticSearchService.extractSnippet(from: content, query: "keyword")
        XCTAssertFalse(snippet.contains("\n"))
    }

    func testExtractSnippetMultiWordQueryMatchesFirstWord() {
        let content = "The cat sat on the mat while the dog ran in the park."
        let snippet = SemanticSearchService.extractSnippet(from: content, query: "dog ran")
        XCTAssertTrue(snippet.contains("dog"))
    }

    func testExtractSnippetWithEmptyContent() {
        let snippet = SemanticSearchService.extractSnippet(from: "", query: "test")
        XCTAssertTrue(snippet.isEmpty)
    }

    func testExtractSnippetCaseInsensitive() {
        let content = "This document contains Important Data here."
        let snippet = SemanticSearchService.extractSnippet(from: content, query: "important data")
        XCTAssertTrue(snippet.contains("Important Data"))
    }

    func testExtractSnippetAtBeginningNoLeadingEllipsis() {
        let content = "needle at the start of a reasonably long document content"
        let snippet = SemanticSearchService.extractSnippet(
            from: content, query: "needle", radius: 60
        )
        XCTAssertFalse(snippet.hasPrefix("…"))
    }

    func testExtractSnippetShortContentNoEllipsis() {
        let content = "short needle text"
        let snippet = SemanticSearchService.extractSnippet(
            from: content, query: "needle", radius: 60
        )
        XCTAssertFalse(snippet.hasPrefix("…"))
        XCTAssertFalse(snippet.hasSuffix("…"))
    }

    // MARK: - SemanticSearchResult construction

    func testSemanticSearchResultHoldsAllFields() {
        let result = SemanticSearchResult(
            name: "TestDoc",
            context: "Meeting",
            icon: "calendar",
            kind: .meeting("ProjectX"),
            score: 0.85,
            snippet: "Some snippet",
            query: "test query"
        )
        XCTAssertEqual(result.name, "TestDoc")
        XCTAssertEqual(result.context, "Meeting")
        XCTAssertEqual(result.icon, "calendar")
        XCTAssertEqual(result.score, 0.85)
        XCTAssertEqual(result.snippet, "Some snippet")
        XCTAssertEqual(result.query, "test query")
    }

    func testSemanticSearchResultMemoryKindHoldsIcon() {
        let result = SemanticSearchResult(
            name: "Company",
            context: "Memory",
            icon: "brain.head.profile",
            kind: .memory("Company"),
            score: 0.9,
            snippet: "Enterprise context",
            query: "company"
        )
        XCTAssertEqual(result.icon, "brain.head.profile")
        XCTAssertEqual(result.context, "Memory")
        if case .memory(let name) = result.kind {
            XCTAssertEqual(name, "Company")
        } else {
            XCTFail("Expected memory kind")
        }
    }

    // MARK: - Category icons

    func testIndexedDocumentMeetingPreservesIcon() {
        let doc = IndexedDocument(
            name: "2026-04-10", context: "Reunion — EL", icon: "calendar",
            kind: .meeting("EL"), content: "notes",
            embeddingFr: [], embeddingEn: [],
            sourceURL: URL(fileURLWithPath: "/tmp/test.md"), modificationDate: Date()
        )
        XCTAssertEqual(doc.icon, "calendar")
    }

    func testIndexedDocumentPersonPreservesIcon() {
        let doc = IndexedDocument(
            name: "erwan", context: "Personne", icon: "person",
            kind: .person("ML/Erwan"), content: "notes",
            embeddingFr: [], embeddingEn: [],
            sourceURL: URL(fileURLWithPath: "/tmp/test.md"), modificationDate: Date()
        )
        XCTAssertEqual(doc.icon, "person")
    }

    func testIndexedDocumentMemoryPreservesIcon() {
        let doc = IndexedDocument(
            name: "Company", context: "Memory", icon: "brain.head.profile",
            kind: .memory("Company"), content: "notes",
            embeddingFr: [], embeddingEn: [],
            sourceURL: URL(fileURLWithPath: "/tmp/test.md"), modificationDate: Date()
        )
        XCTAssertEqual(doc.icon, "brain.head.profile")
    }

    func testIndexedDocumentTaskPreservesIcon() {
        let doc = IndexedDocument(
            name: "Taches", context: "Fichier de taches", icon: "checklist",
            kind: .task, content: "tasks",
            embeddingFr: [], embeddingEn: [],
            sourceURL: URL(fileURLWithPath: "/tmp/test.md"), modificationDate: Date()
        )
        XCTAssertEqual(doc.icon, "checklist")
    }

    // MARK: - IndexedDocumentKind

    func testIndexedDocumentKindMeetingAssociatedValue() {
        let kind = IndexedDocumentKind.meeting("Standup")
        if case .meeting(let name) = kind {
            XCTAssertEqual(name, "Standup")
        } else {
            XCTFail("Expected meeting kind")
        }
    }

    func testIndexedDocumentKindPersonAssociatedValue() {
        let kind = IndexedDocumentKind.person("Alice")
        if case .person(let name) = kind {
            XCTAssertEqual(name, "Alice")
        } else {
            XCTFail("Expected person kind")
        }
    }

    func testIndexedDocumentKindTaskHasNoAssociatedValue() {
        let kind = IndexedDocumentKind.task
        if case .task = kind {
            // expected
        } else {
            XCTFail("Expected task kind")
        }
    }

    func testIndexedDocumentKindMemoryAssociatedValue() {
        let kind = IndexedDocumentKind.memory("Company")
        if case .memory(let name) = kind {
            XCTAssertEqual(name, "Company")
        } else {
            XCTFail("Expected memory kind")
        }
    }

    func testIndexedDocumentKindMemoryEquality() {
        let kind1 = IndexedDocumentKind.memory("Company")
        let kind2 = IndexedDocumentKind.memory("Company")
        let kind3 = IndexedDocumentKind.memory("Projects")
        if case .memory(let n1) = kind1, case .memory(let n2) = kind2 {
            XCTAssertEqual(n1, n2)
        } else {
            XCTFail("Expected memory kinds")
        }
        if case .memory(let n1) = kind1, case .memory(let n3) = kind3 {
            XCTAssertNotEqual(n1, n3)
        } else {
            XCTFail("Expected memory kinds")
        }
    }

    func testIndexedDocumentKindMemoryIsDistinctFromOtherKinds() {
        let memory = IndexedDocumentKind.memory("Test")
        let meeting = IndexedDocumentKind.meeting("Test")
        if case .memory = meeting {
            XCTFail("Meeting should not match memory")
        }
        if case .meeting = memory {
            XCTFail("Memory should not match meeting")
        }
    }

    // MARK: - Search with short query

    @MainActor
    func testSearchWithTooShortQueryReturnsEmpty() async {
        let service = SemanticSearchService()
        let results = await service.search(query: "a")
        XCTAssertTrue(results.isEmpty)
    }

    @MainActor
    func testSearchWithWhitespaceOnlyReturnsEmpty() async {
        let service = SemanticSearchService()
        let results = await service.search(query: "   ")
        XCTAssertTrue(results.isEmpty)
    }

    @MainActor
    func testSearchWithEmptyQueryReturnsEmpty() async {
        let service = SemanticSearchService()
        let results = await service.search(query: "")
        XCTAssertTrue(results.isEmpty)
    }
}
