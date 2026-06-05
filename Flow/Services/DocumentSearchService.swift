import Foundation

struct DocumentSearchOptions: Equatable {
    var caseSensitive: Bool
    var regex: Bool
    var allowRegexInLargeFile: Bool
    var maxResults: Int
}

struct DocumentSearchResult: Identifiable, Equatable {
    let id: Int
    let range: NSRange
    let line: Int
    let column: Int
    let prefix: String
    let match: String
    let suffix: String
}

struct DocumentSearchResponse: Equatable {
    var results: [DocumentSearchResult] = []
    var isTruncated = false
    var skippedRegexForLargeFile = false
    var errorMessage: String?

    var ranges: [NSRange] {
        results.map(\.range)
    }
}

enum DocumentSearchService {
    static func search(query rawQuery: String, in text: String, options: DocumentSearchOptions, largeFileMode: Bool) -> DocumentSearchResponse {
        let query = rawQuery.trimmingCharacters(in: .newlines)
        guard !query.isEmpty else { return DocumentSearchResponse() }

        if largeFileMode, options.regex, !options.allowRegexInLargeFile {
            return DocumentSearchResponse(skippedRegexForLargeFile: true)
        }

        let nsText = text as NSString
        let maxResults = max(1, options.maxResults)
        let lineStarts = TextLocationService.lineStarts(in: nsText)

        if options.regex {
            return regexSearch(
                query: query,
                text: text,
                nsText: nsText,
                lineStarts: lineStarts,
                caseSensitive: options.caseSensitive,
                maxResults: maxResults
            )
        }

        return literalSearch(
            query: query,
            nsText: nsText,
            lineStarts: lineStarts,
            caseSensitive: options.caseSensitive,
            maxResults: maxResults
        )
    }

    static func ranges(query rawQuery: String, in text: String, options: DocumentSearchOptions, largeFileMode: Bool) -> DocumentSearchResponse {
        let query = rawQuery.trimmingCharacters(in: .newlines)
        guard !query.isEmpty else { return DocumentSearchResponse() }

        if largeFileMode, options.regex, !options.allowRegexInLargeFile {
            return DocumentSearchResponse(skippedRegexForLargeFile: true)
        }

        let nsText = text as NSString
        let maxResults = max(1, options.maxResults)
        if options.regex {
            return regexRanges(
                query: query,
                text: text,
                nsText: nsText,
                caseSensitive: options.caseSensitive,
                maxResults: maxResults
            )
        }

        return literalRanges(
            query: query,
            nsText: nsText,
            caseSensitive: options.caseSensitive,
            maxResults: maxResults
        )
    }

    private static func literalRanges(
        query: String,
        nsText: NSString,
        caseSensitive: Bool,
        maxResults: Int
    ) -> DocumentSearchResponse {
        let compareOptions: NSString.CompareOptions = caseSensitive ? [] : [.caseInsensitive]
        var response = DocumentSearchResponse()
        var searchRange = NSRange(location: 0, length: nsText.length)

        while searchRange.length > 0 {
            let range = nsText.range(of: query, options: compareOptions, range: searchRange)
            guard range.location != NSNotFound else { break }

            response.results.append(emptyResult(id: response.results.count, range: range))
            if response.results.count >= maxResults {
                response.isTruncated = true
                break
            }

            let nextLocation = range.location + max(range.length, 1)
            guard nextLocation <= nsText.length else { break }
            searchRange = NSRange(location: nextLocation, length: nsText.length - nextLocation)
        }

        return response
    }

    private static func regexRanges(
        query: String,
        text: String,
        nsText: NSString,
        caseSensitive: Bool,
        maxResults: Int
    ) -> DocumentSearchResponse {
        let regexOptions: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
        let regex: NSRegularExpression

        do {
            regex = try NSRegularExpression(pattern: query, options: regexOptions)
        } catch {
            return DocumentSearchResponse(errorMessage: "Invalid regex")
        }

        var response = DocumentSearchResponse()
        regex.enumerateMatches(in: text, range: NSRange(location: 0, length: nsText.length)) { match, _, stop in
            guard let match, match.range.location != NSNotFound, match.range.length > 0 else { return }
            response.results.append(emptyResult(id: response.results.count, range: match.range))
            if response.results.count >= maxResults {
                response.isTruncated = true
                stop.pointee = true
            }
        }
        return response
    }

    private static func literalSearch(
        query: String,
        nsText: NSString,
        lineStarts: [Int],
        caseSensitive: Bool,
        maxResults: Int
    ) -> DocumentSearchResponse {
        let compareOptions: NSString.CompareOptions = caseSensitive ? [] : [.caseInsensitive]
        var response = DocumentSearchResponse()
        var searchRange = NSRange(location: 0, length: nsText.length)

        while searchRange.length > 0 {
            let range = nsText.range(of: query, options: compareOptions, range: searchRange)
            guard range.location != NSNotFound else { break }

            response.results.append(makeResult(id: response.results.count, range: range, nsText: nsText, lineStarts: lineStarts))
            if response.results.count >= maxResults {
                response.isTruncated = true
                break
            }

            let nextLocation = range.location + max(range.length, 1)
            guard nextLocation <= nsText.length else { break }
            searchRange = NSRange(location: nextLocation, length: nsText.length - nextLocation)
        }

        return response
    }

    private static func regexSearch(
        query: String,
        text: String,
        nsText: NSString,
        lineStarts: [Int],
        caseSensitive: Bool,
        maxResults: Int
    ) -> DocumentSearchResponse {
        let regexOptions: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
        let regex: NSRegularExpression

        do {
            regex = try NSRegularExpression(pattern: query, options: regexOptions)
        } catch {
            return DocumentSearchResponse(errorMessage: "Invalid regex")
        }

        var response = DocumentSearchResponse()
        regex.enumerateMatches(in: text, range: NSRange(location: 0, length: nsText.length)) { match, _, stop in
            guard let match, match.range.location != NSNotFound, match.range.length > 0 else { return }

            response.results.append(makeResult(id: response.results.count, range: match.range, nsText: nsText, lineStarts: lineStarts))
            if response.results.count >= maxResults {
                response.isTruncated = true
                stop.pointee = true
            }
        }

        return response
    }

    private static func makeResult(id: Int, range: NSRange, nsText: NSString, lineStarts: [Int]) -> DocumentSearchResult {
        let location = TextLocationService.lineColumn(for: range.location, lineStarts: lineStarts)
        let lineRange = nsText.lineRange(for: NSRange(location: min(range.location, max(0, nsText.length - 1)), length: 0))
        let lineEnd = max(lineRange.location, NSMaxRange(lineRange) - lineEndingLength(in: nsText, lineRange: lineRange))

        let prefixStart = max(lineRange.location, range.location - 54)
        let suffixEnd = min(lineEnd, NSMaxRange(range) + 78)

        let prefixRange = NSRange(location: prefixStart, length: max(0, range.location - prefixStart))
        let matchRange = NSRange(location: range.location, length: min(range.length, max(0, nsText.length - range.location)))
        let suffixRange = NSRange(location: NSMaxRange(matchRange), length: max(0, suffixEnd - NSMaxRange(matchRange)))

        let prefix = (prefixStart > lineRange.location ? "..." : "") + sanitized(nsText.substring(with: prefixRange))
        let match = sanitized(nsText.substring(with: matchRange))
        let suffix = sanitized(nsText.substring(with: suffixRange)) + (suffixEnd < lineEnd ? "..." : "")

        return DocumentSearchResult(
            id: id,
            range: range,
            line: location.line,
            column: location.column,
            prefix: prefix,
            match: match,
            suffix: suffix
        )
    }

    private static func lineEndingLength(in text: NSString, lineRange: NSRange) -> Int {
        guard lineRange.length > 0 else { return 0 }
        let lastIndex = NSMaxRange(lineRange) - 1
        guard lastIndex >= 0, lastIndex < text.length else { return 0 }
        return text.character(at: lastIndex) == 10 ? 1 : 0
    }

    private static func sanitized(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\t", with: "    ")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
    }

    private static func emptyResult(id: Int, range: NSRange) -> DocumentSearchResult {
        DocumentSearchResult(id: id, range: range, line: 0, column: 0, prefix: "", match: "", suffix: "")
    }
}
