import XCTest
@testable import Algorand

final class MicroAlgosTests: XCTestCase {
    func testMicroAlgosCreation() {
        let amount = MicroAlgos(1_000_000)
        XCTAssertEqual(amount.value, 1_000_000)
        XCTAssertEqual(amount.algos, 1.0)
    }

    func testAlgosConversion() {
        let amount = MicroAlgos(algos: 5.5)
        XCTAssertEqual(amount.value, 5_500_000)
        XCTAssertEqual(amount.algos, 5.5)
    }

    func testArithmetic() {
        let amount1 = MicroAlgos(algos: 1.0)
        let amount2 = MicroAlgos(algos: 2.0)

        let sum = amount1 + amount2
        XCTAssertEqual(sum.algos, 3.0)

        let diff = amount2 - amount1
        XCTAssertEqual(diff.algos, 1.0)

        let doubled = amount1 * 2
        XCTAssertEqual(doubled.algos, 2.0)

        let halved = amount2 / 2
        XCTAssertEqual(halved.algos, 1.0)
    }

    func testComparison() {
        let amount1 = MicroAlgos(algos: 1.0)
        let amount2 = MicroAlgos(algos: 2.0)

        XCTAssertLessThan(amount1, amount2)
        XCTAssertGreaterThan(amount2, amount1)
    }

    func testIntegerLiteral() {
        let amount: MicroAlgos = 1_000_000
        XCTAssertEqual(amount.value, 1_000_000)
        XCTAssertEqual(amount.algos, 1.0)
    }
}
