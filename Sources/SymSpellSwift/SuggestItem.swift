//
// SuggestItem.swift
// SymSpellSwift
//
// Created by Gabor Detari gabor@detari.dev
// Copyright (c) 2024 Gabor Detari. All rights reserved.
//

import Foundation

public struct SuggestItem: Comparable, Hashable {
    var term = ""
    var distance = 0
    var count = 0

    public static func < (lhs: SuggestItem, rhs: SuggestItem) -> Bool {
        lhs.distance == rhs.distance ? lhs.count > rhs.count: lhs.distance < rhs.distance
    }

    public static func == (lhs: SuggestItem, rhs: SuggestItem) -> Bool {
        lhs.term == rhs.term
    }
}
