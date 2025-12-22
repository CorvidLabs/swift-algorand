@preconcurrency import Foundation
import XCTest
@testable import Algorand

final class PaymentTransactionTests: XCTestCase {

    // MARK: - Zero Value Encoding Tests

    func testZeroAmountIsOmittedFromEncoding() throws {
        // Algorand canonical encoding requires zero-value fields to be omitted
        let tx = PaymentTransaction(
            sender: try Address(string: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAY5HFKQ"),
            receiver: try Address(string: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAY5HFKQ"),
            amount: MicroAlgos(0),  // Zero amount
            fee: MicroAlgos(1000),
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: Data(repeating: 0, count: 32)
        )

        let encoded = try tx.encode()

        // The encoded data should NOT contain "amt" key when amount is 0
        // "amt" in MessagePack would be encoded as: 0xA3 'a' 'm' 't' = 0xA3 0x61 0x6D 0x74
        let amtBytes = Data([0xA3, 0x61, 0x6D, 0x74])
        XCTAssertFalse(encoded.contains(amtBytes), "Zero amount should be omitted from encoding")
    }

    func testNonZeroAmountIsIncludedInEncoding() throws {
        let tx = PaymentTransaction(
            sender: try Address(string: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAY5HFKQ"),
            receiver: try Address(string: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAY5HFKQ"),
            amount: MicroAlgos(1000),  // Non-zero amount
            fee: MicroAlgos(1000),
            firstValid: 1000,
            lastValid: 2000,
            genesisID: "testnet-v1.0",
            genesisHash: Data(repeating: 0, count: 32)
        )

        let encoded = try tx.encode()

        // The encoded data SHOULD contain "amt" key when amount is non-zero
        let amtBytes = Data([0xA3, 0x61, 0x6D, 0x74])
        XCTAssertTrue(encoded.contains(amtBytes), "Non-zero amount should be included in encoding")
    }
}

// Helper extension to check if Data contains a subsequence
extension Data {
    fileprivate func contains(_ subsequence: Data) -> Bool {
        guard subsequence.count <= self.count else { return false }
        for i in 0...(self.count - subsequence.count) {
            if self[i..<(i + subsequence.count)] == subsequence {
                return true
            }
        }
        return false
    }
}
