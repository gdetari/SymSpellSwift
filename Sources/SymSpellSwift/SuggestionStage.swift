//
// SuggestionStage.swift
// SymSpellSwift
//
// Created by Gabor Detari gabor@detari.dev
// Copyright (c) 2024 Gabor Detari. All rights reserved.
//

import Foundation

extension SymSpell {
    class SuggestionStage {
        private struct Node: Equatable {
            var suggestion: String
            var next: Int
        }

        private struct Entry {
            var count: Int
            var first: Int
        }

        private var deletes: [Int: Entry]
        private var nodes = [Node]()

        init(initialCapacity: Int? = nil) {
            deletes = Dictionary(minimumCapacity: initialCapacity ?? 16000)
            nodes.reserveCapacity((initialCapacity ?? 16000) * 2)
        }

        var deleteCount: Int { deletes.count }
        var nodeCount: Int { nodes.count }

        func clear() {
            deletes.removeAll()
            nodes.removeAll()
        }

        func add(_ deleteHash: Int, suggestion: String) {
            var entry = deletes[deleteHash, default: Entry(count: 0, first: -1)]
            let next = entry.first
            entry.count += 1
            entry.first = nodes.count
            deletes[deleteHash] = entry
            nodes.append(Node(suggestion: suggestion, next: next))
        }

        func commitTo(_ permanentDeletes: inout [Int: [String]]) {
            permanentDeletes.reserveCapacity(deletes.count)
            
            for (key, value) in deletes {
                var suggestions: [String]
                var i = 0
                if let existingSuggestions = permanentDeletes[key] {
                    i = existingSuggestions.count
                    suggestions = existingSuggestions + Array(repeating: "", count: value.count)
                } else {
                    suggestions = Array(repeating: "", count: value.count)
                }

                var next = value.first
                while next >= 0 {
                    let node = nodes[next]
                    suggestions[i] = node.suggestion
                    next = node.next
                    i += 1
                }

                permanentDeletes[key] = suggestions
            }
        }
    }
}
