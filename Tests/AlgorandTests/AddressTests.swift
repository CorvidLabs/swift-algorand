import XCTest
@testable import Algorand

final class AddressTests: XCTestCase {
    func testAddressFromBytes() throws {
        let bytes = Data(repeating: 1, count: 32)
        let address = try Address(bytes: bytes)

        XCTAssertEqual(address.bytes, bytes)
        XCTAssertEqual(address.description.count, 58)
    }

    func testAddressRoundTrip() throws {
        let bytes = Data(repeating: 42, count: 32)
        let address1 = try Address(bytes: bytes)
        let address2 = try Address(string: address1.description)

        XCTAssertEqual(address1, address2)
        XCTAssertEqual(address1.bytes, address2.bytes)
    }

    func testInvalidAddressLength() {
        XCTAssertThrowsError(try Address(bytes: Data(repeating: 0, count: 16))) { error in
            guard case AlgorandError.invalidAddress = error else {
                XCTFail("Expected invalidAddress error")
                return
            }
        }
    }

    func testAddressEquality() throws {
        let bytes = Data(repeating: 7, count: 32)
        let address1 = try Address(bytes: bytes)
        let address2 = try Address(bytes: bytes)

        XCTAssertEqual(address1, address2)
        XCTAssertEqual(address1.hashValue, address2.hashValue)
    }
}
