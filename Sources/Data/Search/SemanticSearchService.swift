import Foundation
import NaturalLanguage

struct IndexedDocument: Sendable {
    let name: String
    let context: String
    let icon: String
    let kind: IndexedDocumentKind
    let content: String
    let embeddingFr: [Double]
    let embeddingEn: [Double]
    let sourceURL: URL
    let modificationDate: Date
}

enum IndexedDocumentKind: Sendable {
    case meeting(String)
    case person(String)
    case task
}

@MainActor
final class SemanticSearchService {
    private var documents: [IndexedDocument] = []
    private var isIndexing = false
    nonisolated(unsafe) private let embeddingFr: NLEmbedding?
    nonisolated(unsafe) private let embeddingEn: NLEmbedding?

    private static var indexFileURL: URL {
        AppSettings.searchIndexURL
    }

    init() {
        embeddingFr = NLEmbedding.wordEmbedding(for: .french)
        embeddingEn = NLEmbedding.wordEmbedding(for: .english)
        loadIndexFromDisk()
    }

    var isAvailable: Bool { embeddingFr != nil || embeddingEn != nil }

    func rebuildIndex() {
        guard !isIndexing, isAvailable else { return }
        isIndexing = true

        let existing = documents
        let embFr = embeddingFr
        let embEn = embeddingEn

        Task {
            let docs = await Self.performIndexing(existing: existing, embeddingFr: embFr, embeddingEn: embEn)
            documents = docs
            saveIndexToDisk()
            isIndexing = false
        }
    }

    nonisolated private static func performIndexing(
        existing: [IndexedDocument], embeddingFr: NLEmbedding?, embeddingEn: NLEmbedding?
    ) async -> [IndexedDocument] {
        let existingByURL = Dictionary(
            existing.map { ($0.sourceURL.absoluteString, $0) },
            uniquingKeysWith: { _, new in new }
        )

        var docs: [IndexedDocument] = []
        indexDirectory(
            IndexScope(
                directory: AppSettings.meetingsDirectory,
                label: "Reunion",
                icon: "calendar",
                kind: { .meeting($0) }
            ),
            embeddingFr: embeddingFr, embeddingEn: embeddingEn,
            existing: existingByURL,
            into: &docs
        )
        indexDirectory(
            IndexScope(
                directory: AppSettings.peopleDirectory,
                label: "Personne",
                icon: "person",
                kind: { .person($0) }
            ),
            embeddingFr: embeddingFr, embeddingEn: embeddingEn,
            existing: existingByURL,
            into: &docs
        )
        indexTasks(embeddingFr: embeddingFr, embeddingEn: embeddingEn, existing: existingByURL, into: &docs)
        return docs
    }

    func search(query: String, limit: Int = 20) async -> [SemanticSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        // Pre-compute query vectors on main actor (fast), then score on background
        let docs = documents
        let queryFr = embeddingFr.flatMap { Self.averageVector(for: trimmed, using: $0) }
        let queryEn = embeddingEn.flatMap { Self.averageVector(for: trimmed, using: $0) }
        guard queryFr != nil || queryEn != nil else { return [] }

        return await Self.scoreDocuments(
            query: trimmed, docs: docs, queryFr: queryFr, queryEn: queryEn, limit: limit
        )
    }

    nonisolated private static func scoreDocuments(
        query: String, docs: [IndexedDocument],
        queryFr: [Double]?, queryEn: [Double]?, limit: Int
    ) async -> [SemanticSearchResult] {
        let queryLower = query.lowercased()

        var results: [SemanticSearchResult] = []
        for doc in docs {
            let scoreFr = queryFr.map { cosineSimilarity($0, doc.embeddingFr) } ?? 0
            let scoreEn = queryEn.map { cosineSimilarity($0, doc.embeddingEn) } ?? 0
            let semanticScore = max(scoreFr, scoreEn)
            let hasExactMatch = doc.content.lowercased().contains(queryLower)
            let hasNameMatch = doc.name.lowercased().contains(queryLower)
            let exactBoost: Double = hasExactMatch ? 0.3 : 0
            let nameBoost: Double = hasNameMatch ? 0.2 : 0
            let score = semanticScore + exactBoost + nameBoost

            let threshold: Double = (hasExactMatch || hasNameMatch) ? 0.35 : 0.5
            if score > threshold {
                let snippet = extractSnippet(from: doc.content, query: queryLower)
                results.append(SemanticSearchResult(
                    name: doc.name,
                    context: doc.context,
                    icon: doc.icon,
                    kind: doc.kind,
                    score: score,
                    snippet: snippet,
                    query: query
                ))
            }
        }

        results.sort { $0.score > $1.score }
        return Array(results.prefix(limit))
    }

    // MARK: - Word vector averaging

    nonisolated private static func averageVector(for text: String, using emb: NLEmbedding) -> [Double]? {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var vectors: [[Double]] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range]).lowercased()
            if let vec = emb.vector(for: word) { vectors.append(vec) }
            return true
        }
        guard !vectors.isEmpty else { return nil }
        let dim = vectors[0].count
        var avg = [Double](repeating: 0, count: dim)
        for vec in vectors {
            for idx in 0..<dim { avg[idx] += vec[idx] }
        }
        let count = Double(vectors.count)
        for idx in 0..<dim { avg[idx] /= count }
        return avg
    }

    // MARK: - Indexing

    nonisolated private static func dualVectors(
        for text: String, embeddingFr: NLEmbedding?, embeddingEn: NLEmbedding?
    ) -> (fr: [Double], en: [Double])? {
        let vecFr = embeddingFr.flatMap { averageVector(for: text, using: $0) } ?? []
        let vecEn = embeddingEn.flatMap { averageVector(for: text, using: $0) } ?? []
        guard !vecFr.isEmpty || !vecEn.isEmpty else { return nil }
        let dimFr = embeddingFr?.dimension ?? 0
        let dimEn = embeddingEn?.dimension ?? 0
        return (
            fr: vecFr.isEmpty ? [Double](repeating: 0, count: dimFr) : vecFr,
            en: vecEn.isEmpty ? [Double](repeating: 0, count: dimEn) : vecEn
        )
    }

    nonisolated private static func indexDirectory(
        _ scope: IndexScope,
        embeddingFr: NLEmbedding?, embeddingEn: NLEmbedding?,
        existing: [String: IndexedDocument],
        into docs: inout [IndexedDocument]
    ) {
        let contents = DirectoryScanner.scan(at: scope.directory)
        for folder in contents.folders {
            let folderURL = folder.url
            let folderDate = modificationDate(for: folderURL)
            if let cached = existing[folderURL.absoluteString], cached.modificationDate >= folderDate {
                docs.append(cached)
            } else if let vecs = dualVectors(for: folder.name, embeddingFr: embeddingFr, embeddingEn: embeddingEn) {
                docs.append(IndexedDocument(
                    name: folder.name,
                    context: scope.label,
                    icon: scope.icon,
                    kind: scope.kind(folder.name),
                    content: folder.name,
                    embeddingFr: vecs.fr,
                    embeddingEn: vecs.en,
                    sourceURL: folderURL,
                    modificationDate: folderDate
                ))
            }

            let files = DirectoryScanner.scanRecursiveFiles(at: folder.url, fileExtension: "md")
            for file in files {
                let fileDate = file.date
                if let cached = existing[file.url.absoluteString], cached.modificationDate >= fileDate {
                    docs.append(cached)
                    continue
                }
                let fileName = file.url.deletingPathExtension().lastPathComponent
                guard let content = try? String(contentsOf: file.url, encoding: .utf8) else { continue }
                let text = "\(fileName) \(content)"
                let truncated = String(text.prefix(500))
                guard let vecs = dualVectors(for: truncated, embeddingFr: embeddingFr, embeddingEn: embeddingEn) else {
                    continue
                }
                docs.append(IndexedDocument(
                    name: fileName,
                    context: "\(scope.label) — \(folder.name)",
                    icon: "doc.text",
                    kind: scope.kind(folder.name),
                    content: text,
                    embeddingFr: vecs.fr,
                    embeddingEn: vecs.en,
                    sourceURL: file.url,
                    modificationDate: fileDate
                ))
            }
        }
    }

    nonisolated private static func indexTasks(
        embeddingFr: NLEmbedding?, embeddingEn: NLEmbedding?,
        existing: [String: IndexedDocument],
        into docs: inout [IndexedDocument]
    ) {
        let url = AppSettings.tasksFileURL
        let date = modificationDate(for: url)
        if let cached = existing[url.absoluteString], cached.modificationDate >= date {
            docs.append(cached)
            return
        }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        let truncated = String(content.prefix(500))
        guard let vecs = dualVectors(for: truncated, embeddingFr: embeddingFr, embeddingEn: embeddingEn) else { return }
        docs.append(IndexedDocument(
            name: "Taches",
            context: "Fichier de taches",
            icon: "checklist",
            kind: .task,
            content: content,
            embeddingFr: vecs.fr,
            embeddingEn: vecs.en,
            sourceURL: url,
            modificationDate: date
        ))
    }

    nonisolated private static func modificationDate(for url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
    }

    // MARK: - Persistence

    private func saveIndexToDisk() {
        let docs = documents
        let url = Self.indexFileURL
        Task.detached {
            let entries = docs.map { doc in
                StoredEntry(
                    name: doc.name,
                    context: doc.context,
                    icon: doc.icon,
                    kindType: doc.kind.typeString,
                    kindValue: doc.kind.valueString,
                    content: String(doc.content.prefix(500)),
                    embeddingFr: doc.embeddingFr,
                    embeddingEn: doc.embeddingEn,
                    sourceURL: doc.sourceURL.absoluteString,
                    modificationDate: doc.modificationDate
                )
            }
            guard let data = try? JSONEncoder().encode(entries) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    private func loadIndexFromDisk() {
        let dimFr = embeddingFr?.dimension ?? 0
        let dimEn = embeddingEn?.dimension ?? 0
        let url = Self.indexFileURL
        Task {
            let docs = await Task.detached {
                guard let data = try? Data(contentsOf: url),
                      let entries = try? JSONDecoder().decode([StoredEntry].self, from: data) else { return [IndexedDocument]() }
                return entries.compactMap { entry -> IndexedDocument? in
                    guard let kind = IndexedDocumentKind(typeString: entry.kindType, value: entry.kindValue),
                          let sourceURL = URL(string: entry.sourceURL),
                          entry.embeddingFr.count == dimFr,
                          entry.embeddingEn.count == dimEn else { return nil }
                    return IndexedDocument(
                        name: entry.name,
                        context: entry.context,
                        icon: entry.icon,
                        kind: kind,
                        content: entry.content,
                        embeddingFr: entry.embeddingFr,
                        embeddingEn: entry.embeddingEn,
                        sourceURL: sourceURL,
                        modificationDate: entry.modificationDate
                    )
                }
            }.value
            documents = docs
        }
    }
}

// MARK: - Snippet & Math helpers

extension SemanticSearchService {
    nonisolated static func extractSnippet(from content: String, query: String, radius: Int = 60) -> String {
        let lower = content.lowercased()
        let words = query.split(separator: " ").map(String.init)

        var bestIndex: String.Index?
        for word in words {
            if let range = lower.range(of: word) {
                bestIndex = range.lowerBound
                break
            }
        }

        guard let matchIndex = bestIndex else {
            let clean = content.replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return String(clean.prefix(120))
        }

        let matchOffset = content.distance(from: content.startIndex, to: matchIndex)
        let startOffset = max(0, matchOffset - radius)
        let endOffset = min(content.count, matchOffset + radius)

        let startIdx = content.index(content.startIndex, offsetBy: startOffset)
        let endIdx = content.index(content.startIndex, offsetBy: endOffset)
        var snippet = String(content[startIdx..<endIdx])
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if startOffset > 0 { snippet = "…" + snippet }
        if endOffset < content.count { snippet += "…" }

        return snippet
    }

    nonisolated static func cosineSimilarity(_ vectorA: [Double], _ vectorB: [Double]) -> Double {
        guard vectorA.count == vectorB.count, !vectorA.isEmpty else { return 0 }
        var dot = 0.0
        var normA = 0.0
        var normB = 0.0
        for idx in vectorA.indices {
            dot += vectorA[idx] * vectorB[idx]
            normA += vectorA[idx] * vectorA[idx]
            normB += vectorB[idx] * vectorB[idx]
        }
        let denom = sqrt(normA) * sqrt(normB)
        guard denom > 0 else { return 0 }
        return dot / denom
    }
}

// MARK: - Index scope

private struct IndexScope {
    let directory: URL
    let label: String
    let icon: String
    let kind: (String) -> IndexedDocumentKind
}

// MARK: - Persistence models

private struct StoredEntry: Codable {
    let name: String
    let context: String
    let icon: String
    let kindType: String
    let kindValue: String
    let content: String
    let embeddingFr: [Double]
    let embeddingEn: [Double]
    let sourceURL: String
    let modificationDate: Date
}

private extension IndexedDocumentKind {
    var typeString: String {
        switch self {
        case .meeting: "meeting"
        case .person: "person"
        case .task: "task"
        }
    }

    var valueString: String {
        switch self {
        case .meeting(let name): name
        case .person(let name): name
        case .task: ""
        }
    }

    init?(typeString: String, value: String) {
        switch typeString {
        case "meeting": self = .meeting(value)
        case "person": self = .person(value)
        case "task": self = .task
        default: return nil
        }
    }
}

struct SemanticSearchResult: Sendable {
    let name: String
    let context: String
    let icon: String
    let kind: IndexedDocumentKind
    let score: Double
    let snippet: String
    let query: String
}
