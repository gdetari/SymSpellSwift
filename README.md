# SymSpellSwift
Swift implementation of SymSpell: Spelling correction &amp; Fuzzy search: 1 million times faster through Symmetric Delete spelling correction algorithm

_Description from https://github.com/wolfgarbe/SymSpell/_

The Symmetric Delete spelling correction algorithm reduces the complexity of edit candidate generation and dictionary lookup for a given Damerau-Levenshtein distance. It is six orders of magnitude faster (than the standard approach with deletes + transposes + replaces + inserts) and language independent.

Opposite to other algorithms only deletes are required, no transposes + replaces + inserts. Transposes + replaces + inserts of the input term are transformed into deletes of the dictionary term. Replaces and inserts are expensive and language dependent: e.g. Chinese has 70,000 Unicode Han characters!

The speed comes from the inexpensive delete-only edit candidate generation and the pre-calculation.
An average 5 letter word has about 3 million possible spelling errors within a maximum edit distance of 3,
but SymSpell needs to generate only 25 deletes to cover them all, both at pre-calculation and at lookup time. Magic!

## Single word spelling correction
Lookup provides a very fast spelling correction of single words.

- A Verbosity parameter allows to control the number of returned results:
Top: Top suggestion with the highest term frequency of the suggestions of smallest edit distance found.
Closest: All suggestions of smallest edit distance found, suggestions ordered by term frequency.
All: All suggestions within maxEditDistance, suggestions ordered by edit distance, then by term frequency.
- The Maximum edit distance parameter controls up to which edit distance words from the dictionary should be treated as suggestions.
- The required Word frequency dictionary can either be directly loaded from text files (LoadDictionary) or generated from a large text corpus (CreateDictionary).

### Applications

- Spelling correction,
- Query correction (10–15% of queries contain misspelled terms),
- Chatbots,
- OCR post-processing,
- Automated proofreading.
- Fuzzy search & approximate string matching

## Compound aware multi-word spelling correction
Supports compound aware automatic spelling correction of multi-word input strings.

### Compound splitting & decompounding
`lookup()` assumes every input string as single term. `lookupCompound()` also supports compound splitting / decompounding with three cases:

1. mistakenly inserted space within a correct word led to two incorrect terms
2. mistakenly omitted space between two correct words led to one incorrect combined term
3. multiple input terms with/without spelling errors

Splitting errors, concatenation errors, substitution errors, transposition errors, deletion errors and insertion errors can by mixed within the same word.

2. Automatic spelling correction

Large document collections make manual correction infeasible and require unsupervised, fully-automatic spelling correction.
In conventional spelling correction of a single token, the user is presented with multiple spelling correction suggestions.
For automatic spelling correction of long multi-word text the algorithm itself has to make an educated choice.

### Examples:
```diff
- whereis th elove hehad dated forImuch of thepast who couqdn'tread in sixthgrade and ins pired him
+ where is the love he had dated for much of the past who couldn't read in sixth grade and inspired him  (9 edits)

- in te dhird qarter oflast jear he hadlearned ofca sekretplan
+ in the third quarter of last year he had learned of a secret plan  (9 edits)

- the bigjest playrs in te strogsommer film slatew ith plety of funn
+ the biggest players in the strong summer film slate with plenty of fun  (9 edits)

- Can yu readthis messa ge despite thehorible sppelingmsitakes
+ can you read this message despite the horrible spelling mistakes  (9 edits)
```

## Word Segmentation of noisy text
WordSegmentation divides a string into words by inserting missing spaces at appropriate positions.

- Misspelled words are corrected and do not prevent segmentation.
- Existing spaces are allowed and considered for optimum segmentation.
- SymSpell.WordSegmentation uses a Triangular Matrix approach instead of the conventional Dynamic Programming: It uses an array instead of a dictionary for memoization, loops instead of recursion and incrementally optimizes prefix strings instead of remainder strings.
- The Triangular Matrix approach is faster than the Dynamic Programming approach. It has a lower memory consumption, better scaling (constant O(1) memory consumption vs. linear O(n)) and is GC friendly.
- While each string of length n can be segmented into 2^n−1 possible compositions,
SymSpell.WordSegmentation has a linear runtime O(n) to find the optimum composition.

### Examples:
```diff
- thequickbrownfoxjumpsoverthelazydog
+ the quick brown fox jumps over the lazy dog

- itwasabrightcolddayinaprilandtheclockswerestrikingthirteen
+ it was a bright cold day in april and the clocks were striking thirteen

- itwasthebestoftimesitwastheworstoftimesitwastheageofwisdomitwastheageoffoolishness
+ it was the best of times it was the worst of times it was the age of wisdom it was the age of foolishness
```

### Applications:

- Word Segmentation for CJK languages for Indexing Spelling correction, Machine translation, Language understanding, Sentiment analysis
- Normalizing English compound nouns for search & indexing (e.g. ice box = ice-box = icebox; pig sty = pig-sty = pigsty)
- Word segmentation for compounds if both original word and split word parts should be indexed.
- Correction of missing spaces caused by Typing errors.
- Correction of Conversion errors: spaces between word may get lost e.g. when removing line breaks.
- Correction of OCR errors: inferior quality of original documents or handwritten text may prevent that all spaces are recognized.
- Correction of Transmission errors: during the transmission over noisy channels spaces can get lost or spelling errors introduced.
- Keyword extraction from URL addresses, domain names, #hashtags, table column descriptions or programming variables written without spaces.
- For password analysis, the extraction of terms from passwords can be required.
- For Speech recognition, if spaces between words are not properly recognized in spoken language.
- Automatic CamelCasing of programming variables.
- Applications beyond Natural Language processing, e.g. segmenting DNA sequence into words

## Swift implementation
Current implementation builds on the original SymSpell, but uses Swift best practices and modern paradigms to achieve the same results with even better performance.

## Usage

```swift
let symSpell = SymSpell(maxDictionaryEditDistance: 2, prefixLength: 3)
if let path = Bundle.main.url(forResource: "frequency_dictionary_en_82_765", withExtension: "txt") {
  try? symSpell.loadDictionary(from: path, termIndex: 0, countIndex: 1, termCount: 82765)
}

let results = symSpell.lookup("intermedaite")

print(results.first?.term)
```

