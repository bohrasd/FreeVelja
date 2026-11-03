import Foundation

struct Rule: Identifiable, Codable, Equatable {
    var id = UUID()
    var enabled = true
    var pattern = ""
    var browserID: String?
}

/// `|` separates alternatives and `*` matches any run of characters.
/// An alternative may match anywhere in the URL; matching ignores case.
enum URLPattern {
    static func matches(_ pattern: String, url: String) -> Bool {
        let haystack = url.lowercased()
        return pattern.lowercased().split(separator: "|").contains { alt in
            let alt = alt.trimmingCharacters(in: .whitespaces)
            guard !alt.isEmpty else { return false }
            var rest = haystack[...]
            for part in alt.split(separator: "*") {
                guard let r = rest.range(of: part) else { return false }
                rest = rest[r.upperBound...]
            }
            return true
        }
    }
}
