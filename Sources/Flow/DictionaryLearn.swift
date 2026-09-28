import Foundation

/// Turns a short edit of inserted text into dictionary entries.
enum DictionaryEdits {
    static func learn(from original: String, to edited: String) -> [DictionaryItem] {
        let source = tokens(original)
        let target = tokens(edited)
        guard !source.isEmpty, !target.isEmpty, source != target else { return [] }

        let table = lcsLengths(source, target)
        let hunks = substitutionHunks(source, target, table)
        let matches = table[source.count][target.count]
        let longer = max(source.count, target.count)
        let mostlySame = Double(matches) / Double(longer) >= 0.7
        let singleFix = hunks.count == 1 && longer <= 6
        guard mostlySame || singleFix else { return [] }

        var items: [DictionaryItem] = []
        for hunk in hunks {
            guard let item = item(from: hunk.heard, to: hunk.term), items.count < 3 else { continue }
            items.append(item)
        }
        return items
    }

    private struct Hunk {
        var heard: String
        var term: String
    }

    private static func tokens(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private static func lcsLengths(_ a: [String], _ b: [String]) -> [[Int]] {
        var table = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 1...a.count {
            for j in 1...b.count where a[i - 1] == b[j - 1] {
                table[i][j] = table[i - 1][j - 1] + 1
            }
            for j in 1...b.count where a[i - 1] != b[j - 1] {
                table[i][j] = max(table[i - 1][j], table[i][j - 1])
            }
        }
        return table
    }

    private static func substitutionHunks(_ a: [String], _ b: [String], _ table: [[Int]]) -> [Hunk] {
        var removed: [String] = []
        var added: [String] = []
        var hunks: [Hunk] = []

        func flush() {
            if !removed.isEmpty, !added.isEmpty {
                hunks.append(Hunk(heard: removed.joined(separator: " "), term: added.joined(separator: " ")))
            }
            removed.removeAll()
            added.removeAll()
        }

        var i = a.count
        var j = b.count
        var steps: [(String, String?)] = []
        while i > 0 || j > 0 {
            if i > 0, j > 0, a[i - 1] == b[j - 1] {
                steps.append(("same", nil))
                i -= 1
                j -= 1
            } else if j > 0, i == 0 || table[i][j - 1] >= table[i - 1][j] {
                steps.append(("add", b[j - 1]))
                j -= 1
            } else if i > 0 {
                steps.append(("remove", a[i - 1]))
                i -= 1
            } else {
                break
            }
        }

        for step in steps.reversed() {
            switch step.0 {
            case "same":
                flush()
            case "add":
                if let word = step.1 { added.append(word) }
            default:
                if let word = step.1 { removed.append(word) }
            }
        }
        flush()
        return hunks
    }

    private static func item(from heard: String, to term: String) -> DictionaryItem? {
        let from = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        let to = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !from.isEmpty, !to.isEmpty, from != to else { return nil }
        guard from.count <= 48, to.count <= 48 else { return nil }
        if from.compare(to, options: .caseInsensitive) == .orderedSame {
            return DictionaryItem(term: to, heardAs: from)
        }
        guard from.count >= 3, to.count >= 2 else { return nil }
        let distance = levenshtein(from.lowercased(), to.lowercased())
        let ratio = Double(distance) / Double(max(from.count, to.count))
        let gainedCapitals = from.rangeOfCharacter(from: .uppercaseLetters) == nil
            && to.rangeOfCharacter(from: .uppercaseLetters) != nil
        guard ratio <= 0.45 || (gainedCapitals && ratio <= 0.6) else { return nil }
        return DictionaryItem(term: to, heardAs: from)
    }

    private static func levenshtein(_ a: String, _ b: String) -> Int {
        let left = Array(a)
        let right = Array(b)
        if left.isEmpty { return right.count }
        if right.isEmpty { return left.count }
        var previous = Array(0...right.count)
        var current = Array(repeating: 0, count: right.count + 1)
        for i in 1...left.count {
            current[0] = i
            for j in 1...right.count {
                let cost = left[i - 1] == right[j - 1] ? 0 : 1
                current[j] = min(current[j - 1] + 1, previous[j] + 1, previous[j - 1] + cost)
            }
            previous = current
        }
        return previous[right.count]
    }
}

/// Watches the field after a paste and learns once the edit sits still.
final class DictionaryLearner {
    private let inserter: TextInserter
    private let work = DispatchQueue(label: "de.sinthex.flow.dictionary-learn")
    private var epoch = 0
    private var timer: Timer?
    private var original = ""
    private var anchor: DictationAnchor?
    private var pending: String?
    private var stableSince: Date?
    private var deadline = Date()
    private var onLearn: (([DictionaryItem]) -> Void)?

    init(inserter: TextInserter) {
        self.inserter = inserter
    }

    func watch(inserted: String, onLearn: @escaping ([DictionaryItem]) -> Void) {
        stop()
        let text = inserted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !SnapshotMode.isActive, !text.isEmpty else { return }
        work.sync {
            original = text
            self.onLearn = onLearn
            deadline = Date().addingTimeInterval(40)
        }
        let timer = Timer(timeInterval: 0.45, repeats: true) { [weak self] _ in
            self?.tick()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        work.sync {
            epoch += 1
            anchor = nil
            pending = nil
            stableSince = nil
            onLearn = nil
            original = ""
        }
    }

    private func stillCurrent(_ epoch: Int) -> Bool {
        var current = false
        work.sync { current = self.epoch == epoch }
        return current
    }

    private func tick() {
        work.async { [weak self] in
            self?.evaluate()
        }
    }

    private func evaluate() {
        let seen = self.epoch
        guard Date() < deadline, onLearn != nil else {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.stillCurrent(seen) else { return }
                self.stop()
            }
            return
        }
        if anchor == nil {
            anchor = inserter.locateInsert(original)
            return
        }
        guard let anchor else { return }
        guard let current = inserter.text(at: anchor, original: original)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !current.isEmpty else { return }
        if current == original {
            pending = nil
            stableSince = nil
            return
        }
        if current != pending {
            pending = current
            stableSince = Date()
            return
        }
        guard let stableSince, Date().timeIntervalSince(stableSince) >= 1.2 else { return }
        let learned = DictionaryEdits.learn(from: original, to: current)
        let deliver = onLearn
        onLearn = nil
        DispatchQueue.main.async { [weak self] in
            guard let self, self.stillCurrent(seen) else { return }
            self.stop()
            if !learned.isEmpty {
                deliver?(learned)
            }
        }
    }
}
