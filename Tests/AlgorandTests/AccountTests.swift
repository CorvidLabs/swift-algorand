import XCTest
@testable import Algorand

final class AccountTests: XCTestCase {
    func testAccountCreation() throws {
        let account = try Account()

        XCTAssertEqual(account.publicKey.count, 32)
        XCTAssertFalse(try account.mnemonic().isEmpty)

        // Mnemonic should be 25 words
        let words = try account.mnemonic().components(separatedBy: " ")
        XCTAssertEqual(words.count, 25)
    }

    func testAccountFromMnemonic() throws {
        let account1 = try Account()
        let mnemonic = try account1.mnemonic()

        let account2 = try Account(mnemonic: mnemonic)

        XCTAssertEqual(account1.address, account2.address)
        XCTAssertEqual(account1.publicKey, account2.publicKey)
        XCTAssertEqual(try account1.mnemonic(), try account2.mnemonic())
    }

    func testSignature() throws {
        let account = try Account()
        let data = Data("Hello, Algorand!".utf8)

        let signature = try account.sign(data)

        XCTAssertEqual(signature.count, 64)
        XCTAssertTrue(account.verify(signature: signature, for: data))
    }

    func testInvalidMnemonic() {
        XCTAssertThrowsError(try Account(mnemonic: "invalid mnemonic")) { error in
            guard case AlgorandError.invalidMnemonic = error else {
                XCTFail("Expected invalidMnemonic error")
                return
            }
        }
    }
}
