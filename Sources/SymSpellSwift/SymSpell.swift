//
// SymSpell.swift
// SymSpellSwift
//
// Created by Gabor Detari gabor@detari.dev
// Copyright (c) 2024 Gabor Detari. All rights reserved.
//

import Foundation

public final class SymSpell {
    public enum Verbosity: CaseIterable {
        case top, closest, all
    }

    public struct Segmentation {
        var segmentedString = ""
        var correctedString = ""
        var distanceSum = 0
        var probabilityLogSum = 0.0
    }

    public var wordCount: Int { words.count }
    public var entryCount: Int { deletes.count }

    private(set) var maxDictionaryEditDistance = 2
    private(set) var prefixLength = 7
    private(set) var countThreshold = 1

    private var deletes = [Int: [String]]()
    private var words = [String: Int]()
    private var belowThresholdWords = [String: Int]()

    private var bigrams = [String: Int]()
    private var bigramCountMin = Int.max

    private let separator: Character = " "

    private var maxDictionaryWordLength: Int = 0
    private var totalCorpusWords = 0

    public init(maxDictionaryEditDistance: Int = 2, prefixLength: Int = 7, countThreshold: Int = 1) {
        precondition(maxDictionaryEditDistance >= 0, "maxDictionaryEditDistance must be non-negative")
        precondition(prefixLength > 1 && prefixLength > maxDictionaryEditDistance, "Invalid prefixLength")
        precondition(countThreshold >= 0, "countThreshold must be non-negative")

        self.maxDictionaryEditDistance = maxDictionaryEditDistance
        self.prefixLength = prefixLength
        self.countThreshold = countThreshold
    }

    public func loadBigramDictionary(from url: URL, termIndex: Int = 0, countIndex: Int = 2) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        loadBigramDictionary(from: content, termIndex: termIndex, countIndex: countIndex)
    }

    public func loadBigramDictionary(from string: String, termIndex: Int = 0, countIndex: Int = 2) {
        string.enumerateLines { line, _ in
            let components = line.split(separator: self.separator)
            if components.count >= max(termIndex + 2, countIndex + 1), let count = Int(components[countIndex]) {
                let key = components[termIndex] + " " + components[termIndex + 1]
                self.bigrams[String(key)] = count
                self.bigramCountMin = min(self.bigramCountMin, count)
            }
        }
    }

    public func loadDictionary(from url: URL, termIndex: Int = 0, countIndex: Int = 1, termCount: Int? = nil) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        loadDictionary(from: content, termIndex: termIndex, countIndex: countIndex, termCount: termCount)
    }

    public func loadDictionary(from string: String, termIndex: Int = 0, countIndex: Int = 1, termCount: Int? = nil) {
        totalCorpusWords = 0
        maxDictionaryWordLength = 0
        let staging = SuggestionStage(initialCapacity: termCount)

        string.enumerateLines { line, _ in
            let components = line.split(separator: self.separator)
            if components.count >= max(termIndex, countIndex) + 1, let count = Int(components[countIndex]) {
                let key = components[termIndex]

                self.createDictionaryEntry(key: String(key), count: count, staging: staging)
            }
        }

        staging.commitTo(&deletes)
    }

    public func createDictionary(from url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        try createDictionary(from: content)
    }

    public func createDictionary(from string: String) throws {
        let staging = SuggestionStage()

        string.enumerateLines { line, _ in
            for word in self.parseWords(line) {
                self.createDictionaryEntry(key: word, count: 1, staging: staging)
            }
        }

        staging.commitTo(&deletes)
    }

    public func lookup(_ input: String, verbosity: Verbosity, maxEditDistance: Int? = nil, includeUnknown: Bool = false) -> [SuggestItem] {
        let maxEditDistance = min(maxEditDistance ?? maxDictionaryEditDistance, maxDictionaryEditDistance)
        var suggestions = [SuggestItem]()
        let inputLen = input.count

        guard inputLen - maxEditDistance <= maxDictionaryWordLength else { return [] }

        if let count = words[input] {
            suggestions.append(SuggestItem(term: input, distance: 0, count: count))
            if verbosity != .all { return suggestions }
        }

        guard maxEditDistance > 0 else { return suggestions }

        var consideredDeletes = Set<Substring>()
        var consideredSuggestions = Set<String>([input])

        var maxEditDistance2 = maxEditDistance
        var candidatePointer = 0
        var candidates = [Substring]()

        let inputPrefixLen = min(inputLen, prefixLength)
        candidates.append(input.prefix(inputPrefixLen))

        while candidatePointer < candidates.count {
            let candidate = candidates[candidatePointer]
            candidatePointer += 1
            let candidateLen = candidate.count
            let lengthDiff = inputPrefixLen - candidateLen

            if lengthDiff > maxEditDistance2 {
                if verbosity == .all { continue }
                break
            }

            if let dictSuggestions = deletes[candidate.hashValue] {
                for suggestion in dictSuggestions {
                    let suggestionLen = suggestion.count
                    if suggestion == input { continue }
                    if abs(suggestionLen - inputLen) > maxEditDistance2 || suggestionLen < candidateLen ||
                        (suggestionLen == candidateLen && suggestion != candidate) { continue }

                    let suggPrefixLen = min(suggestionLen, prefixLength)
                    if suggPrefixLen > inputPrefixLen, (suggPrefixLen - candidateLen) > maxEditDistance2 { continue }

                    var distance = 0
                    let minLength = min(inputLen, suggestionLen)

                    if candidateLen == 0 {
                        distance = max(inputLen, suggestionLen)
                        if distance > maxEditDistance2 || !consideredSuggestions.insert(suggestion).inserted { continue }
                    } else if suggestionLen == 1 {
                        if !input.contains(suggestion) {
                            distance = inputLen
                        } else {
                            distance = inputLen - 1
                        }
                        if distance > maxEditDistance2 || !consideredSuggestions.insert(suggestion).inserted { continue }
                    } else if prefixLength - maxEditDistance == candidateLen,
                              (minLength - prefixLength > 1 && !input.hasSuffix(suggestion.suffix(minLength - prefixLength))) ||
                              (minLength - prefixLength > 0 && input[prefixLength - minLength] != suggestion[prefixLength - minLength] &&
                                  ((input[prefixLength - minLength - 1] != suggestion[prefixLength - minLength]) || (input[prefixLength - minLength] != suggestion[prefixLength - minLength - 1]))) {
                        continue
                    } else {
                        if verbosity != .all && !deleteInSuggestionPrefix(candidate, candidateLen, suggestion, suggestionLen) ||
                            !consideredSuggestions.insert(suggestion).inserted { continue }
                        distance = input.distanceDamerauLevenshtein(between: suggestion)
                        if distance < 0 { continue }
                    }

                    if distance <= maxEditDistance2 {
                        let count = words[suggestion, default: 0]
                        let si = SuggestItem(term: suggestion, distance: distance, count: count)
                        if !suggestions.isEmpty {
                            switch verbosity {
                            case .closest:
                                if distance < maxEditDistance2 { suggestions.removeAll() }
                            case .top:
                                if distance < maxEditDistance2 || count > suggestions[0].count {
                                    maxEditDistance2 = distance
                                    suggestions[0] = si
                                }
                                continue
                            case .all:
                                break
                            }
                        }
                        if verbosity != .all { maxEditDistance2 = distance }
                        suggestions.append(si)
                    }
                }
            }

            if lengthDiff < maxEditDistance, candidateLen <= prefixLength {
                if verbosity != .all, lengthDiff >= maxEditDistance2 { continue }
                for i in 0 ..< candidateLen {
                    let delete = candidate.removingCharacter(at: i)

                    if consideredDeletes.insert(delete).inserted {
                        candidates.append(delete)
                    }
                }
            }
        }

        if suggestions.count > 1 { suggestions.sort() }
        if includeUnknown, suggestions.isEmpty {
            suggestions.append(SuggestItem(term: input, distance: maxEditDistance + 1, count: 0))
        }
        return suggestions
    }

    public func lookupCompound(_ input: String, maxEditDistance: Int? = nil) -> [SuggestItem] {
        let maxEditDistance = min(maxEditDistance ?? maxDictionaryEditDistance, maxDictionaryEditDistance)
        let termList = parseWords(input)
        var suggestions = [SuggestItem]()
        var suggestionParts = [SuggestItem]()

        var lastCombi = false

        for i in 0 ..< termList.count {
            suggestions = lookup(termList[i], verbosity: .top, maxEditDistance: maxEditDistance)

            if i > 0, !lastCombi {
                var suggestionsCombi = lookup(termList[i - 1] + termList[i], verbosity: .top, maxEditDistance: maxEditDistance)
                if !suggestionsCombi.isEmpty {
                    let best1 = suggestionParts[suggestionParts.count - 1]
                    let best2: SuggestItem = if !suggestions.isEmpty {
                        suggestions[0]
                    } else {
                        SuggestItem(term: termList[i], distance: maxEditDistance + 1, count: Int(10 / pow(10.0, Double(termList[i].count))))
                    }

                    let distance1 = best1.distance + best2.distance

                    if distance1 >= 0, suggestionsCombi[0].distance + 1 < distance1 ||
                        (suggestionsCombi[0].distance + 1 == distance1 && Double(suggestionsCombi[0].count) > Double(best1.count) / Double(totalCorpusWords) * Double(best2.count)) {
                        suggestionsCombi[0].distance += 1
                        suggestionParts[suggestionParts.count - 1] = suggestionsCombi[0]
                        lastCombi = true
                        continue
                    }
                }
            }

            lastCombi = false

            if !suggestions.isEmpty, suggestions[0].distance == 0 || termList[i].count == 1 {
                suggestionParts.append(suggestions[0])
            } else {
                var suggestionSplitBest: SuggestItem?

                if !suggestions.isEmpty {
                    suggestionSplitBest = suggestions[0]
                }

                if termList[i].count > 1 {
                    for j in 1 ..< termList[i].count {
                        let part1 = String(termList[i].prefix(j))
                        let part2 = String(termList[i].suffix(termList[i].count - j))

                        var suggestionSplit = SuggestItem(term: "", distance: 0, count: 0)
                        let suggestions1 = lookup(part1, verbosity: .top, maxEditDistance: maxEditDistance)

                        if !suggestions1.isEmpty {
                            let suggestions2 = lookup(part2, verbosity: .top, maxEditDistance: maxEditDistance)

                            if !suggestions2.isEmpty {
                                suggestionSplit.term = suggestions1[0].term + " " + suggestions2[0].term
                                var distance2 = termList[i].distanceDamerauLevenshtein(between: suggestionSplit.term)
                                if distance2 < 0 { distance2 = maxEditDistance + 1 }

                                if let best = suggestionSplitBest {
                                    if distance2 > best.distance { continue }
                                    if distance2 < best.distance { suggestionSplitBest = nil }
                                }

                                suggestionSplit.distance = distance2
                                if let bigramCount = bigrams[suggestionSplit.term] {
                                    suggestionSplit.count = bigramCount

                                    if !suggestions.isEmpty {
                                        if suggestions1[0].term + suggestions2[0].term == termList[i] {
                                            suggestionSplit.count = max(suggestionSplit.count, suggestions[0].count + 2)
                                        } else if suggestions1[0].term == suggestions[0].term || suggestions2[0].term == suggestions[0].term {
                                            suggestionSplit.count = max(suggestionSplit.count, suggestions[0].count + 1)
                                        }
                                    } else if suggestions1[0].term + suggestions2[0].term == termList[i] {
                                        suggestionSplit.count = max(suggestionSplit.count, max(suggestions1[0].count, suggestions2[0].count) + 2)
                                    }
                                } else {
                                    suggestionSplit.count = min(bigramCountMin, Int(Double(suggestions1[0].count) / Double(totalCorpusWords) * Double(suggestions2[0].count)))
                                }

                                if suggestionSplitBest == nil || suggestionSplit.count > suggestionSplitBest!.count {
                                    suggestionSplitBest = suggestionSplit
                                }
                            }
                        }
                    }

                    if let bestSplit = suggestionSplitBest {
                        suggestionParts.append(bestSplit)
                    } else {
                        let si = SuggestItem(term: termList[i], distance: maxEditDistance + 1, count: Int(10 / pow(10.0, Double(termList[i].count))))
                        suggestionParts.append(si)
                    }
                } else {
                    let si = SuggestItem(term: termList[i], distance: maxEditDistance + 1, count: Int(10 / pow(10.0, Double(termList[i].count))))
                    suggestionParts.append(si)
                }
            }
        }

        var suggestion = SuggestItem(term: "", distance: 0, count: 0)
        var count = Double(totalCorpusWords)
        var s = ""

        for si in suggestionParts {
            s += si.term + " "
            count *= Double(si.count) / Double(totalCorpusWords)
        }

        suggestion.count = Int(count)
        suggestion.term = s.trimmingCharacters(in: .whitespaces)
        suggestion.distance = input.distanceDamerauLevenshtein(between: suggestion.term)

        return [suggestion]
    }

//
//    /// Find suggested spellings for a multi-word input string (supports word splitting/merging).
//    /// - Parameters:
//    ///   - input: The string being spell checked.
//    ///   - maxEditDistance: The maximum edit distance between input and corrected words (0 = no correction).
//    ///   - maxSegmentationWordLength: The maximum word length that should be considered.
//    /// - Returns: A tuple with the word segmented string, corrected string, edit distance sum, and the log of the word occurrence probabilities.
    public func wordSegmentation(input: String, maxEditDistance: Int = 0) -> Segmentation {
        // Normalize ligatures and replace hyphens
        let input = input.precomposedStringWithCompatibilityMapping.replacingOccurrences(of: "\u{002D}", with: "")

        let arraySize = min(maxDictionaryWordLength, input.count)
        var compositions: [Segmentation] = Array(repeating: Segmentation(), count: arraySize)
        var circularIndex = -1

        // Outer loop (columns): all possible part start positions
        for j in 0 ..< input.count {
            // Inner loop (rows): all possible part lengths (from start position)

            for i in 1 ... min(input.count - j, maxDictionaryWordLength) {
                guard var partSubstr = input[j ..< j + i] else { continue }

                var separatorLength = 0
                var topEd = 0
                var topProbabilityLog = 0.0
                var topResult = ""

                if partSubstr.first?.isWhitespace == true {
                    // Remove leading space for edit distance calculation
                    partSubstr.removeFirst()
                } else {
                    // Space had to be inserted
                    separatorLength = 1
                }

                var part = String(partSubstr)

                // Calculate edit distance
                topEd += part.count
                part = part.replacingOccurrences(of: " ", with: "")
                topEd -= part.count

                let results = lookup(part.lowercased(), verbosity: .top, maxEditDistance: maxEditDistance)

                if let result = results.first {
                    topResult = result.term
                    if part.first?.isUppercase == true {
                        topResult = topResult.prefix(1).uppercased() + topResult.dropFirst()
                    }
                    topEd += result.distance
                    topProbabilityLog = log10(Double(result.count) / Double(totalCorpusWords))
                } else {
                    topResult = String(part)
                    topEd += part.count
                    topProbabilityLog = log10(10.0 / (Double(totalCorpusWords) * pow(10.0, Double(part.count))))
                }

                let destinationIndex = (i + circularIndex) % arraySize

                if j == 0 {
                    compositions[destinationIndex] = Segmentation(segmentedString: part, correctedString: topResult, distanceSum: topEd, probabilityLogSum: topProbabilityLog)
                } else if i == maxDictionaryWordLength
                    || ((compositions[circularIndex].distanceSum + topEd == compositions[destinationIndex].distanceSum) || (compositions[circularIndex].distanceSum + separatorLength + topEd == compositions[destinationIndex].distanceSum)) && (compositions[destinationIndex].probabilityLogSum < compositions[circularIndex].probabilityLogSum + topProbabilityLog)
                    || compositions[circularIndex].distanceSum + separatorLength + topEd < compositions[destinationIndex].distanceSum {
                    if topResult.count == 1, topResult.first?.isPunctuation == true {
                        compositions[destinationIndex] = Segmentation(
                            segmentedString: compositions[circularIndex].segmentedString + part,
                            correctedString: compositions[circularIndex].correctedString + topResult,
                            distanceSum: compositions[circularIndex].distanceSum + topEd,
                            probabilityLogSum: compositions[circularIndex].probabilityLogSum + topProbabilityLog
                        )
                    } else {
                        compositions[destinationIndex] = Segmentation(
                            segmentedString: compositions[circularIndex].segmentedString + " " + part,
                            correctedString: compositions[circularIndex].correctedString + " " + topResult,
                            distanceSum: compositions[circularIndex].distanceSum + separatorLength + topEd,
                            probabilityLogSum: compositions[circularIndex].probabilityLogSum + topProbabilityLog
                        )
                    }
                }
            }
            circularIndex += 1
            if circularIndex == arraySize { circularIndex = 0 }
        }

        return compositions[circularIndex]
    }

    internal func createDictionaryEntry(key: String, count: Int, staging: SuggestionStage? = nil) {
        guard count >= 0 else { return }

        var count = count
        totalCorpusWords += count

        if countThreshold > 1, let previousCount = belowThresholdWords[key] {
            count += previousCount
            if count >= countThreshold {
                belowThresholdWords.removeValue(forKey: key)
            } else {
                belowThresholdWords[key] = count
                return
            }
        } else if let previousCount = words[key] {
            count += previousCount
            words[key] = count
            return
        } else if count < countThreshold {
            belowThresholdWords[key] = count
            return
        }

        words[key] = count
        maxDictionaryWordLength = max(maxDictionaryWordLength, key.count)

        let edits = editsPrefix(key)
        if let staging {
            for delete in edits {
                staging.add(delete.hashValue, suggestion: key)
            }
        } else {
            for delete in edits {
                deletes[delete.hashValue, default: []].append(key)
            }
        }
    }

    private func deleteInSuggestionPrefix(_ delete: Substring, _ deleteLen: Int, _ suggestion: String, _ suggestionLen: Int) -> Bool {
        guard deleteLen != 0 else { return true }

        let suggestionLen = min(prefixLength, suggestionLen)
        
        return !delete.prefix(deleteLen).contains { !suggestion.prefix(suggestionLen).contains($0) }
    }

    private func parseWords(_ text: String) -> [String] {
        var words = [String]()
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { substring, _, _, _ in
            if let substring {
                words.append(substring)
            }
        }
        return words
    }

    private func editsPrefix(_ key: String) -> Set<String> {
        var hashSet = Set<String>()
        if key.count <= maxDictionaryEditDistance { hashSet.insert("") }
        let prefixKey = key.prefix(prefixLength)
        hashSet.insert(String(prefixKey))
        edits(prefixKey, 0, &hashSet)

        return hashSet
    }

    private func edits(_ word: Substring, _ editDistance: Int, _ deleteWords: inout Set<String>) {
        guard word.count > 1 else { return }

        let editDistance = editDistance + 1
        for i in 0 ..< word.count {
            let delete = word.removingCharacter(at: i)
            if deleteWords.insert(String(delete)).inserted, editDistance < maxDictionaryEditDistance {
                edits(delete, editDistance, &deleteWords)
            }
        }
    }
}
