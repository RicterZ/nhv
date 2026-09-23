import Foundation

struct SearchTokenScanner {
    let ranges: [Range<String.Index>]
    let lastTokenStart: String.Index

    init(_ input: String) {
        var ranges: [Range<String.Index>] = []
        var start = input.startIndex
        var quoted = false
        var escaped = false

        for index in input.indices {
            let character = input[index]
            if character.isWhitespace && !quoted && !escaped {
                if start < index { ranges.append(start..<index) }
                start = input.index(after: index)
                continue
            }
            if escaped {
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "\"" {
                quoted.toggle()
            }
        }
        if start < input.endIndex { ranges.append(start..<input.endIndex) }
        self.ranges = ranges
        lastTokenStart = start
    }
}
