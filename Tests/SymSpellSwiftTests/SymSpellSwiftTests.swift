@testable import SymSpellSwift
import XCTest

final class SymSpellTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    private func loadFromDictionaryFile() -> SymSpell? {
        let symSpell = SymSpell(maxDictionaryEditDistance: 2, prefixLength: 3)

        guard let path = Bundle.module.url(forResource: "frequency_dictionary_en_82_765", withExtension: "txt") else {
            return nil
        }

        try? symSpell.loadDictionary(from: path, termIndex: 0, countIndex: 1, termCount: 82765)

        return symSpell
    }

    func testWordsWithSharedPrefixShouldRetainCounts() {
        let symSpell = SymSpell(maxDictionaryEditDistance: 1, prefixLength: 3)
        symSpell.createDictionaryEntry(key: "pipe", count: 5)
        symSpell.createDictionaryEntry(key: "pips", count: 10)

        var result = symSpell.lookup("pipe", verbosity: .all, maxEditDistance: 1)
        XCTAssertEqual(2, result.count)
        XCTAssertEqual("pipe", result[0].term)
        XCTAssertEqual(5, result[0].count)
        XCTAssertEqual("pips", result[1].term)
        XCTAssertEqual(10, result[1].count)

        result = symSpell.lookup("pips", verbosity: .all, maxEditDistance: 1)
        XCTAssertEqual(2, result.count)
        XCTAssertEqual("pips", result[0].term)
        XCTAssertEqual(10, result[0].count)
        XCTAssertEqual("pipe", result[1].term)
        XCTAssertEqual(5, result[1].count)

        result = symSpell.lookup("pip", verbosity: .all, maxEditDistance: 1)
        XCTAssertEqual(2, result.count)
        XCTAssertEqual("pips", result[0].term)
        XCTAssertEqual(10, result[0].count)
        XCTAssertEqual("pipe", result[1].term)
        XCTAssertEqual(5, result[1].count)
    }

    func testAddAdditionalCountsShouldNotAddWordAgain() {
        let symSpell = SymSpell()
        let word = "hello"
        symSpell.createDictionaryEntry(key: word, count: 11)
        XCTAssertEqual(1, symSpell.wordCount)
        symSpell.createDictionaryEntry(key: word, count: 3)
        XCTAssertEqual(1, symSpell.wordCount)
    }

    func testAddAdditionalCountsShouldIncreaseCount() {
        let symSpell = SymSpell()
        let word = "hello"
        symSpell.createDictionaryEntry(key: word, count: 11)

        var result = symSpell.lookup(word, verbosity: .top)
        var count = result.first?.count ?? 0
        XCTAssertEqual(11, count)

        symSpell.createDictionaryEntry(key: word, count: 3)
        result = symSpell.lookup(word, verbosity: .top)
        count = result.first?.count ?? 0
        XCTAssertEqual(11 + 3, count)
    }

    func testVerbosityShouldControlLookupResults() {
        let symSpell = SymSpell()
        symSpell.createDictionaryEntry(key: "steam", count: 1)
        symSpell.createDictionaryEntry(key: "steams", count: 2)
        symSpell.createDictionaryEntry(key: "steem", count: 3)

        var result = symSpell.lookup("steems", verbosity: .top, maxEditDistance: 2)
        XCTAssertEqual(1, result.count)

        result = symSpell.lookup("steems", verbosity: .closest, maxEditDistance: 2)
        XCTAssertEqual(2, result.count)

        result = symSpell.lookup("steems", verbosity: .all, maxEditDistance: 2)
        XCTAssertEqual(3, result.count)
    }

    func testLookupShouldReturnMostFrequent() {
        let symSpell = SymSpell()
        symSpell.createDictionaryEntry(key: "steama", count: 4)
        symSpell.createDictionaryEntry(key: "steamb", count: 6)
        symSpell.createDictionaryEntry(key: "steamc", count: 2)

        let result = symSpell.lookup("steam", verbosity: .top, maxEditDistance: 2)
        XCTAssertEqual(1, result.count)
        XCTAssertEqual("steamb", result[0].term)
        XCTAssertEqual(6, result[0].count)
    }

    func testLookupShouldFindExactMatch() {
        let symSpell = SymSpell()
        symSpell.createDictionaryEntry(key: "steama", count: 4)
        symSpell.createDictionaryEntry(key: "steamb", count: 6)
        symSpell.createDictionaryEntry(key: "steamc", count: 2)

        let result = symSpell.lookup("steama", verbosity: .top, maxEditDistance: 2)
        XCTAssertEqual(1, result.count)
        XCTAssertEqual("steama", result[0].term)
    }

    func testLookupShouldNotReturnNonWordDelete() {
        let symSpell = SymSpell(maxDictionaryEditDistance: 2, prefixLength: 7)
        symSpell.createDictionaryEntry(key: "pawn", count: 10)

        var result = symSpell.lookup("paw", verbosity: .top, maxEditDistance: 0)
        XCTAssertEqual(0, result.count)

        result = symSpell.lookup("awn", verbosity: .top, maxEditDistance: 0)
        XCTAssertEqual(0, result.count)
    }
    
    func testComplete() {
        guard let symSpell = loadFromDictionaryFile() else {
            XCTFail()
            return
        }
        
        var result = symSpell.complete("yeste")
        XCTAssert(result.count == 4)
        XCTAssert(result[0].term == "yesterday")
        XCTAssert(result[1].term == "yesterdays")
        
        result = symSpell.complete("yste")
        XCTAssert(result.count == 0)
        
        result = symSpell.complete("ballo")
        XCTAssert(result.count == 10)
        XCTAssert(result[0].term == "balloon")
        XCTAssert(result[1].term == "ballot")
    }

    func testEnglishWordCorrection() {
        guard let symSpell = loadFromDictionaryFile() else {
            XCTFail()
            return
        }

        let sentences = [
            "tke",
            "abolution",
            "intermedaite",
            "usefull",
            "kniow",
        ]

        XCTAssert(symSpell.lookup(sentences[0], verbosity: .closest).first?.term == "the")
        XCTAssert(symSpell.lookup(sentences[1], verbosity: .closest).first?.term == "abolition")
        XCTAssert(symSpell.lookup(sentences[2], verbosity: .closest).first?.term == "intermediate")
        XCTAssert(symSpell.lookup(sentences[3], verbosity: .closest).first?.term == "useful")
        XCTAssert(symSpell.lookup(sentences[4], verbosity: .closest).first?.term == "know")
    }

    func testEnglishCompoundCorrection() {
        guard let symSpell = loadFromDictionaryFile() else {
            XCTFail()
            return
        }

        guard let path = Bundle.module.url(forResource: "frequency_bigramdictionary_en_243_342", withExtension: "txt") else {
            XCTFail()
            return
        }

        try? symSpell.loadBigramDictionary(from: path)

        let sentences = [
            "whereis th elove hehad dated forImuch of thepast who couqdn'tread in sixthgrade and ins pired him",
            "in te dhird qarter oflast jear he hadlearned ofca sekretplan",
            "the bigjest playrs in te strogsommer film slatew ith plety of funn",
            "can yu readthis messa ge despite thehorible sppelingmsitakes",
        ]

        XCTAssertEqual(symSpell.lookupCompound(sentences[0]).first?.term, "where is the love he had dated for much of the past who couldn't read in sixth grade and inspired him")
        XCTAssertEqual(symSpell.lookupCompound(sentences[1]).first?.term, "in the third quarter of last year he had learned of a secret plan")
        XCTAssertEqual(symSpell.lookupCompound(sentences[2]).first?.term, "the biggest players in the strong summer film slate with plenty of fun")
        XCTAssertEqual(symSpell.lookupCompound(sentences[3]).first?.term, "can you read this message despite the horrible spelling mistakes")
    }

    func testSegmenting() {
        guard let symSpell = loadFromDictionaryFile() else {
            XCTFail()
            return
        }

        let sentences = [
            "thequickbrownfoxjumpsoverthelazydog",
            "itwasabrightcolddayinaprilandtheclockswerestrikingthirteen",
            "itwasthebestoftimesitwastheworstoftimesitwastheageofwisdomitwastheageoffoolishness",
        ]

        XCTAssertEqual(symSpell.wordSegmentation(sentences[0], maxEditDistance: 0).segmentedString, "the quick brown fox jumps over the lazy dog")
        XCTAssertEqual(symSpell.wordSegmentation(sentences[1], maxEditDistance: 0).segmentedString, "it was a bright cold day in april and the clocks were striking thirteen")
        XCTAssertEqual(symSpell.wordSegmentation(sentences[2], maxEditDistance: 0).segmentedString, "it was the best of times it was the worst of times it was the age of wisdom it was the age of foolishness")
    }
}

