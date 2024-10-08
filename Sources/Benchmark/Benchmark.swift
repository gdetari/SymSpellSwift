//
// Created by Gabor Detari gabor@detari.dev
// Copyright 2024 Gabor Detari. All rights reserved.
//
        

import Foundation
import SymSpellSwift

class Stopwatch {
    private var startTime: DispatchTime?
    private var stopTime: DispatchTime?

    // Start the stopwatch
    func start() {
        startTime = DispatchTime.now()
        stopTime = nil
    }

    // Stop the stopwatch
    func stop() {
        stopTime = DispatchTime.now()
    }

    // Get the elapsed time in milliseconds
    var elapsedTime: Double {
        if let start = startTime {
            let end = stopTime ?? DispatchTime.now() // If stopwatch is still running, calculate till now
            let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
            let milliSeconds = Double(nanoTime) / 1_000_000_000
            return milliSeconds
        } else {
            return 0
        }
    }
}

@main
class Benchmark {
    private static func fileURL(_ filename: String) -> URL {
        let currentFileURL = URL(fileURLWithPath: #file)
        let directoryURL = currentFileURL.deletingLastPathComponent()
        return directoryURL.appendingPathComponent(filename)
    }
    
    static let path = FileManager.default.currentDirectoryPath
    static let query1k = fileURL("noisy_query_en_1000.txt")

    static let dictionaryPath: [URL] = [
        fileURL("frequency_dictionary_en_30_000.txt"),
        fileURL("frequency_dictionary_en_82_765.txt"),
        fileURL("frequency_dictionary_en_500_000.txt")
    ]

    static let dictionaryName: [String] = [
        "30k",
        "82k",
        "500k"
    ]

    static let dictionarySize: [Int] = [
        29159,
        82765,
        500_000
    ]

    static func buildQuery1K() -> [String] {
        var testList: [String] = Array(repeating: "", count: 1000)
        var i = 0

        if let fileReader = try? String(contentsOf: query1k) {
            let lines = fileReader.split(separator: "\n")
            for line in lines {
                let lineParts = line.split(separator: " ")
                if lineParts.count >= 2 {
                    testList[i] = String(lineParts[0])
                    i += 1
                }
            }
        }
        return testList
    }

    static func warmUp() {
        let dict = SymSpell(maxDictionaryEditDistance: 2, prefixLength: 7)
        try? dict.loadDictionary(from: dictionaryPath[0], termIndex: 0, countIndex: 1)
        _ = dict.lookup("hockie", verbosity: .all, maxEditDistance: 1)
    }

    static func benchmarkPrecalculationLookup() {
        var resultNumber = 0
        let repetitions = 1000
        var totalLoopCount = 0
        var totalMatches: Int64 = 0
        var totalLoadTime = 0.0
        var totalLookupTime = 0.0
        var totalRepetitions: Int64 = 0

        let stopWatch = Stopwatch()

        for maxEditDistance in 1 ... 3 {
            for prefixLength in 5 ... 7 {
                for i in 0 ..< dictionaryPath.count {
                    totalLoopCount += 1

                    stopWatch.start()
                    let dict = SymSpell(maxDictionaryEditDistance: maxEditDistance, prefixLength: prefixLength)
                    try? dict.loadDictionary(from: dictionaryPath[i], termIndex: 0, countIndex: 1, termCount: dictionarySize[i])
                    stopWatch.stop()
                    totalLoadTime += stopWatch.elapsedTime
                    print("Precalculation instance \(String(format: "%.3f", stopWatch.elapsedTime))s \(dict.wordCount) words \(dict.entryCount) entries MaxEditDistance=\(maxEditDistance) prefixLength=\(prefixLength) dict=\(dictionaryName[i])")

                    // Benchmark lookup
                    for verbosity in SymSpell.Verbosity.allCases {
                        // Instantiated exact
                        stopWatch.start()
                        for _ in 0 ..< repetitions {
                            resultNumber = dict.lookup("different", verbosity: verbosity, maxEditDistance: maxEditDistance).count
                        }
                        stopWatch.stop()
                        totalLookupTime += stopWatch.elapsedTime
                        totalMatches += Int64(resultNumber)
//                        print("Lookup instance \(resultNumber) results \(String(format: "%.6f", stopWatch.elapsedTime / Double(repetitions)))ms/op verbosity=\(verbosity) query=exact")

                        totalRepetitions += Int64(repetitions)
                    }
                }
            }
        }

        print("Average Precalculation time instance \(String(format: "%.3f", totalLoadTime / Double(totalLoopCount)))s")
        print("Average Lookup time instance \(String(format: "%.3f", totalLookupTime / Double(totalRepetitions)))ms")
        print("Total Lookup results instance \(totalMatches)")
    }
    
    static func main() {
        warmUp()
        benchmarkPrecalculationLookup()
    }
}
