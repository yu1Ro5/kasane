import XCTest

@testable import KASANE

final class WeightSuggestionProviderTests: XCTestCase {
    func testSecondAndThirdSetsUseImmediatePreviousWeight() {
        let sets = [SetEntryDraft(weight: "29.3"), SetEntryDraft(weight: "22.6")]
        XCTAssertEqual(suggestion(at: 1, sets: sets), "29.3")
        XCTAssertEqual(suggestion(at: 2, sets: sets), "22.6")
    }

    func testFirstSetUsesLastValidPreviousWeight() {
        XCTAssertEqual(suggestion(at: 0, previous: [11.3, 28.1, .nan, -1]), "28.1")
    }

    func testNoCandidateAndInvalidImmediatePreviousWeight() {
        XCTAssertNil(suggestion(at: 0))
        XCTAssertNil(suggestion(at: 0, previous: [.infinity, -1]))
        XCTAssertNil(suggestion(at: 1, sets: [SetEntryDraft()], previous: [29.3]))
        XCTAssertNil(suggestion(at: 2, sets: [SetEntryDraft(weight: "29.3"), SetEntryDraft(weight: "bad")]))
    }

    func testDecimalFormattingAndNoAutomaticInput() {
        for weight in [29.3, 22.6, 11.3, 28.1, 23.0, 0] {
            XCTAssertEqual(
                suggestion(at: 0, previous: [weight]), WorkoutSetDisplayFormatter.editableWeightValue(weight))
        }
        let sets = [SetEntryDraft(weight: "29.3"), SetEntryDraft()]
        _ = suggestion(at: 1, sets: sets)
        XCTAssertTrue(sets[1].isEmpty)
        XCTAssertEqual(
            WeightSuggestionProvider.suggestion(at: 0, currentSets: [], previousWeights: [29.3], decimalSeparator: ","),
            "29,3")
    }

    private func suggestion(at index: Int, sets: [SetEntryDraft] = [], previous: [Double] = []) -> String? {
        WeightSuggestionProvider.suggestion(
            at: index, currentSets: sets, previousWeights: previous, decimalSeparator: ".")
    }
}
