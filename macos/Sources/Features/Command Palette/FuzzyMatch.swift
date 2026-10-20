import Foundation

/// fzf-style fuzzy matching for the tab switcher.
///
/// A query is split on whitespace into terms, and every term must match.
/// A term matches when its characters appear in order in one of the
/// candidate's fields, with gaps allowed, ignoring case and diacritics.
/// Terms match independently, so their order in the query doesn't matter.
enum FuzzyMatch {
    struct TermMatch {
        let score: Int
        let indices: [String.Index]
    }

    struct QueryMatch {
        let score: Int
        /// The characters to highlight in each field, parallel to the fields
        /// passed in. Each term highlights only the field it matched best.
        let highlights: [[String.Index]]
    }

    // Scoring loosely follows fzf: every matched character scores, matches
    // at word starts and runs of consecutive matches score extra, and gaps
    // between matches cost a little per skipped character.
    private static let matchScore = 16
    private static let boundaryBonus = 8
    private static let camelCaseBonus = 7
    private static let consecutiveBonus = 6
    private static let gapStartPenalty = 3
    private static let gapExtensionPenalty = 1

    static func query(_ query: String, fields: [String?]) -> QueryMatch? {
        let terms = query.split(whereSeparator: \.isWhitespace)
        guard !terms.isEmpty else { return nil }

        var score = 0
        var highlights = fields.map { _ in Set<String.Index>() }
        for term in terms {
            var best: (field: Int, match: TermMatch)?
            for (i, field) in fields.enumerated() {
                guard let field, let match = Self.term(String(term), in: field) else { continue }
                if best == nil || match.score > best!.match.score {
                    best = (i, match)
                }
            }

            guard let best else { return nil }
            score += best.match.score
            highlights[best.field].formUnion(best.match.indices)
        }

        return QueryMatch(score: score, highlights: highlights.map { $0.sorted() })
    }

    static func term(_ term: String, in text: String) -> TermMatch? {
        let needle = term.map(fold)
        let indices = Array(text.indices)
        let chars = indices.map { text[$0] }
        let haystack = chars.map(fold)
        let n = haystack.count
        let m = needle.count
        guard m > 0, m <= n else { return nil }

        let bonuses = (0..<n).map { bonus(at: $0, in: chars) }

        // best[j][i] is the top score for matching needle[0...j] with
        // needle[j] at haystack[i]; from[j][i] is where needle[j-1] went.
        var best = [[Int?]](repeating: .init(repeating: nil, count: n), count: m)
        var from = [[Int]](repeating: .init(repeating: -1, count: n), count: m)

        for j in 0..<m {
            // The best predecessor at least one character back, adjusted so
            // the gap penalty can be applied in constant time.
            var gapped: (score: Int, index: Int)?

            for i in 0..<n {
                if j > 0, i >= 2, let prev = best[j - 1][i - 2] {
                    let candidate = prev + (i - 2) * gapExtensionPenalty
                    if gapped == nil || candidate > gapped!.score {
                        gapped = (candidate, i - 2)
                    }
                }

                guard haystack[i] == needle[j] else { continue }
                let base = matchScore + bonuses[i]
                if j == 0 {
                    best[j][i] = base
                    continue
                }

                var score: Int?
                var source = -1
                if i >= 1, let prev = best[j - 1][i - 1] {
                    score = prev + consecutiveBonus
                    source = i - 1
                }
                if let gapped {
                    let gap = i - gapped.index - 1
                    let prev = gapped.score - gapped.index * gapExtensionPenalty
                    let candidate = prev - gapStartPenalty - (gap - 1) * gapExtensionPenalty
                    if score == nil || candidate > score! {
                        score = candidate
                        source = gapped.index
                    }
                }

                if let score {
                    best[j][i] = score + base
                    from[j][i] = source
                }
            }
        }

        var end: (score: Int, index: Int)?
        for i in 0..<n {
            if let score = best[m - 1][i], end == nil || score > end!.score {
                end = (score, i)
            }
        }
        guard let end else { return nil }

        var matched = [Int](repeating: 0, count: m)
        var i = end.index
        for j in stride(from: m - 1, through: 0, by: -1) {
            matched[j] = i
            i = from[j][i]
        }

        return TermMatch(score: end.score, indices: matched.map { indices[$0] })
    }

    private static func fold(_ c: Character) -> String {
        String(c).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func bonus(at i: Int, in chars: [Character]) -> Int {
        let c = chars[i]
        guard c.isLetter || c.isNumber else { return 0 }
        guard i > 0 else { return boundaryBonus }
        let prev = chars[i - 1]
        if !(prev.isLetter || prev.isNumber) { return boundaryBonus }
        if prev.isLowercase && c.isUppercase { return camelCaseBonus }
        return 0
    }
}

extension Collection where Element == CommandOption {
    /// Best first; ties keep their order.
    func fuzzyFilteredAndSorted(query: String) -> [Element] {
        guard !query.allSatisfy(\.isWhitespace) else { return Array(self) }
        return enumerated()
            .compactMap { offset, option in
                FuzzyMatch.query(query, fields: option.fuzzyFields)
                    .map { (offset: offset, score: $0.score, option: option) }
            }
            .sorted { ($0.score, $1.offset) > ($1.score, $0.offset) }
            .map(\.option)
    }
}

extension CommandOption {
    /// Parallel to `QueryMatch.highlights`, title first.
    var fuzzyFields: [String?] { [title, subtitle ?? description] }
}
