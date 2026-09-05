@preconcurrency import Foundation
import Testing
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import Algorand

/**
 The 1.0 safety and API-surface work: canonical addresses, strict mnemonics, checked amounts, the
 internalised encoder and hash, the client fixes, and key storage.

 Every behavioural test here fails on the 4665470 tree - by aborting the process, by accepting
 input go-algorand rejects, or by building a request algod cannot answer. Throwing calls are
 hoisted out of `#expect` because the Swift 6.0 toolchain's macro does not accept them inside its
 expression. No predecessor test file is edited; the legacy XCTest suites keep exercising the
 deprecated operators and `toBaseUnits`, and this suite uses only their replacements.
 */

/// Requirement evidence: REQ-algorand-029, REQ-algorand-030, REQ-algorand-031, REQ-algorand-032, REQ-algorand-033, REQ-algorand-034.
@Suite
internal struct SafetyAndSurfaceTests {

    // MARK: - Fixtures

    /// A real TestNet address, canonical: its final character `I` has index 8, a multiple of 4.
    internal static let canonicalAddress = "QRW7KYDELRKXLM2JJPCFFHG4RGGJQCURSE7QM4NVS7OKQWCVTFTVBWBFHI"

    internal static let base32Alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

    /// The two py-algorand-sdk vectors the legacy suite pins, repeated here so the strict decoder
    /// is shown to keep them.
    internal static let zerosMnemonic = Array(repeating: "abandon", count: 24).joined(separator: " ") + " invest"
    internal static let key42sMnemonic =
        "earn post bench pencil february melody eyebrow clay earn post bench pencil february melody "
        + "eyebrow clay earn post bench pencil february melody eyebrow ability tired"

    internal static let nodeStatusJSON = Data(
        #"""
        {"last-round":100,"last-version":"v42","next-version":"v42","next-version-round":101,
         "next-version-supported":true,"time-since-last-round":0,"catchup-time":0}
        """#.utf8
    )

    internal static func stubClient() throws -> AlgodClient {
        guard let base = URL(string: "https://algod.example.com") else {
            throw AlgorandError.invalidURL("fixture")
        }
        return AlgodClient(baseURL: base, configuration: StubProtocol.configuration())
    }

    internal static func expectInvalidAddress(_ string: String, _ comment: Comment) {
        do {
            _ = try Address(string: string)
            Issue.record("Accepted \(comment): \(string)")
        } catch AlgorandError.invalidAddress {
            // expected
        } catch {
            Issue.record("Unexpected error for \(comment): \(error)")
        }
    }

    internal static func expectInvalidMnemonic(_ phrase: String, _ comment: Comment) {
        do {
            _ = try Mnemonic.decode(phrase)
            Issue.record("Accepted \(comment)")
        } catch AlgorandError.invalidMnemonic {
            // expected
        } catch {
            Issue.record("Unexpected error for \(comment): \(error)")
        }
    }

    // MARK: - Canonical addresses (REQ-algorand-029)

    @Test("A canonical address round-trips and its description is the input")
    internal func canonicalAddressRoundTrips() throws {
        let address = try Address(string: Self.canonicalAddress)
        #expect(address.description == Self.canonicalAddress)
        #expect(address.bytes.count == 32)

        let fromBytes = try Address(bytes: address.bytes)
        #expect(fromBytes.description == Self.canonicalAddress)
        #expect(fromBytes == address)

        // Every address built from bytes is accepted back, because bytes encode canonically.
        let arbitrary = try Address(bytes: Data((0..<32).map { UInt8(truncatingIfNeeded: $0 * 37 + 11) }))
        let reparsed = try Address(string: arbitrary.description)
        #expect(reparsed == arbitrary)
    }

    @Test("Lowercase and mixed-case addresses are rejected")
    internal func lowercaseAddressesAreRejected() {
        Self.expectInvalidAddress(Self.canonicalAddress.lowercased(), "lowercase address")

        var mixed = Array(Self.canonicalAddress)
        mixed[0] = Character(String(mixed[0]).lowercased())
        Self.expectInvalidAddress(String(mixed), "mixed-case address")
    }

    /// The final character of a 58-character address carries two bits beyond the 288 the 36
    /// decoded bytes use. Four characters therefore decode to the same bytes and pass the same
    /// checksum; only the one leaving those bits zero re-encodes to the input, and go-algorand's
    /// `UnmarshalChecksumAddress` rejects the other three as non-canonical.
    @Test("Non-canonical trailing bits are rejected even though the checksum passes")
    internal func nonCanonicalTrailingBitsAreRejected() throws {
        var characters = Array(Self.canonicalAddress)
        let finalIndex = try #require(Self.base32Alphabet.firstIndex(of: characters[57]))
        #expect(finalIndex % 4 == 0, "The fixture's final character is not canonical")

        for offset in 1...3 {
            characters[57] = Self.base32Alphabet[finalIndex + offset]
            let variant = String(characters)
            #expect(variant.count == 58)
            // Same 36 bytes, so the checksum still passes: only the canonical-form check rejects.
            let decoded = try #require(Data(base32Encoded: variant))
            let canonicalBytes = try #require(Data(base32Encoded: Self.canonicalAddress))
            #expect(decoded == canonicalBytes)
            Self.expectInvalidAddress(variant, "trailing-bit variant \(offset)")
        }
    }

    @Test("Malformed addresses are rejected with invalidAddress")
    internal func malformedAddressesAreRejected() {
        Self.expectInvalidAddress(String(repeating: "=", count: 58), "padding characters")
        Self.expectInvalidAddress(String(repeating: "1", count: 58), "digit outside the alphabet")
        Self.expectInvalidAddress(String(repeating: "0", count: 58), "zero outside the alphabet")
        Self.expectInvalidAddress(String(Self.canonicalAddress.dropLast()), "57 characters")
        Self.expectInvalidAddress(Self.canonicalAddress + "A", "59 characters")

        var wrongChecksum = Array(Self.canonicalAddress)
        wrongChecksum[52] = wrongChecksum[52] == "A" ? "B" : "A"
        Self.expectInvalidAddress(String(wrongChecksum), "corrupted checksum")
    }

    @Test("Address decodes from JSON only in canonical form")
    internal func addressDecodesFromJSONCanonicallyOnly() throws {
        let canonical = try JSONDecoder().decode(Address.self, from: Data("\"\(Self.canonicalAddress)\"".utf8))
        #expect(canonical.description == Self.canonicalAddress)

        let lowercase = Data("\"\(Self.canonicalAddress.lowercased())\"".utf8)
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(Address.self, from: lowercase)
        }
    }

    // MARK: - Strict mnemonics (REQ-algorand-030)

    @Test("The py-algorand-sdk vectors decode and re-encode unchanged")
    internal func crossSDKMnemonicVectorsStillDecode() throws {
        let zeros = try Mnemonic.decode(Self.zerosMnemonic)
        #expect(zeros == Data(repeating: 0, count: 32))
        let zerosEncoded = try Mnemonic.encode(zeros)
        #expect(zerosEncoded == Self.zerosMnemonic)

        let key42s = try Mnemonic.decode(Self.key42sMnemonic)
        #expect(key42s == Data(repeating: 42, count: 32))
        let key42sEncoded = try Mnemonic.encode(key42s)
        #expect(key42sEncoded == Self.key42sMnemonic)

        #expect(Mnemonic.isValid(Self.zerosMnemonic))
        #expect(Mnemonic.isValid(Self.key42sMnemonic))
    }

    /// The 24 key words carry 264 bits for a 256-bit key. Perturbing the top eight bits of the
    /// 24th word yields 255 further phrases that unpack to the same key and pass the same
    /// checksum - accepted by the lenient decoder, rejected by py-algorand-sdk's 33rd-byte check.
    @Test("All 255 non-canonical spellings of a key are rejected")
    internal func nonCanonicalMnemonicsAreRejected() throws {
        let seed = Data((0..<32).map { UInt8(truncatingIfNeeded: $0 * 7 + 3) })
        let canonical = try Mnemonic.encode(seed)
        var words = canonical.components(separatedBy: " ")
        #expect(words.count == 25)

        let wordlist = BIP39Wordlist.english
        let lastKeyWord = try #require(wordlist.firstIndex(of: words[23]))
        // The 24th word supplies bits 253..263; bits 256..263 are the spare byte, so the canonical
        // index has only its low three bits set.
        #expect(lastKeyWord & ~0x7 == 0, "The 24th word is not canonical for this seed")

        var rejected = 0
        for high in 1..<256 {
            words[23] = wordlist[(high << 3) | (lastKeyWord & 0x7)]
            let variant = words.joined(separator: " ")
            #expect(!Mnemonic.isValid(variant))
            do {
                _ = try Mnemonic.decode(variant)
            } catch AlgorandError.invalidMnemonic(let message) {
                #expect(message.contains("Non-canonical"))
                rejected += 1
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
        #expect(rejected == 255)

        let decoded = try Mnemonic.decode(canonical)
        #expect(decoded == seed)
    }

    @Test("Wrong word counts, unknown words, and a wrong checksum stay invalidMnemonic")
    internal func malformedMnemonicsAreRejected() throws {
        let phrase = try Mnemonic.encode(Data(repeating: 1, count: 32))
        var words = phrase.components(separatedBy: " ")

        words.removeLast()
        Self.expectInvalidMnemonic(words.joined(separator: " "), "24 words")

        words = phrase.components(separatedBy: " ")
        words[5] = "notaword"
        Self.expectInvalidMnemonic(words.joined(separator: " "), "unknown word")

        words = phrase.components(separatedBy: " ")
        words[24] = words[24] == "abandon" ? "ability" : "abandon"
        Self.expectInvalidMnemonic(words.joined(separator: " "), "wrong checksum word")
    }

    @Test("Generated mnemonics are canonical and restore the same account")
    internal func generatedMnemonicsRoundTrip() throws {
        for _ in 0..<8 {
            let account = try Account()
            let phrase = try account.mnemonic()
            let restored = try Account(mnemonic: phrase)
            #expect(restored.address == account.address)
            #expect(restored.publicKey == account.publicKey)
            let reencoded = try restored.mnemonic()
            #expect(reencoded == phrase)
        }
    }

    // MARK: - Checked amounts (REQ-algorand-031)

    @Test("Checked MicroAlgos arithmetic agrees with the operators on their happy path")
    internal func checkedArithmeticHappyPath() throws {
        let one = MicroAlgos(1_000_000)
        let two = MicroAlgos(2_000_000)

        let sum = try one.adding(two)
        #expect(sum.value == 3_000_000)
        let difference = try two.subtracting(one)
        #expect(difference.value == 1_000_000)
        let doubled = try one.multiplied(by: 2)
        #expect(doubled.value == 2_000_000)
        let halved = try two.divided(by: 2)
        #expect(halved.value == 1_000_000)
        let truncated = try MicroAlgos(7).divided(by: 2)
        #expect(truncated.value == 3)
        let zero = try one.subtracting(one)
        #expect(zero.value == 0)
    }

    @Test("Checked MicroAlgos arithmetic throws where the operators trap")
    internal func checkedArithmeticThrowsInsteadOfTrapping() {
        let max = MicroAlgos(UInt64.max)

        #expect(throws: AmountError.self) { try max.adding(MicroAlgos(1)) }
        #expect(throws: AmountError.self) { try MicroAlgos(1).subtracting(MicroAlgos(2)) }
        #expect(throws: AmountError.self) { try max.multiplied(by: 2) }
        #expect(throws: AmountError.divisionByZero) { try MicroAlgos(1).divided(by: 0) }

        do {
            _ = try max.adding(max)
            Issue.record("Overflow was not thrown")
        } catch AmountError.overflow(let detail) {
            #expect(detail.contains("exceeds UInt64"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        // The boundary itself is fine.
        let exact = try? MicroAlgos(UInt64.max - 1).adding(MicroAlgos(1))
        #expect(exact?.value == UInt64.max)
    }

    @Test("init(checkedAlgos:) converts, rounds to the nearest microAlgo, and rejects the unrepresentable")
    internal func checkedAlgosInitializer() throws {
        let one = try MicroAlgos(checkedAlgos: 1.0)
        #expect(one.value == 1_000_000)
        let fiveAndAHalf = try MicroAlgos(checkedAlgos: 5.5)
        #expect(fiveAndAHalf.value == 5_500_000)
        let zero = try MicroAlgos(checkedAlgos: 0)
        #expect(zero.value == 0)
        let negativeZero = try MicroAlgos(checkedAlgos: -0.0)
        #expect(negativeZero.value == 0)
        let tenTrillion = try MicroAlgos(checkedAlgos: 1e13)
        #expect(tenTrillion.value == 10_000_000_000_000_000_000)

        // 0.7 microAlgo rounds up to 1; truncation would have given 0.
        let fraction = try MicroAlgos(checkedAlgos: 0.000_000_7)
        #expect(fraction.value == 1)
        let smaller = try MicroAlgos(checkedAlgos: 0.000_000_3)
        #expect(smaller.value == 0)

        #expect(throws: AmountError.self) { try MicroAlgos(checkedAlgos: .nan) }
        #expect(throws: AmountError.self) { try MicroAlgos(checkedAlgos: .infinity) }
        #expect(throws: AmountError.self) { try MicroAlgos(checkedAlgos: -.infinity) }
        #expect(throws: AmountError.self) { try MicroAlgos(checkedAlgos: -1) }
        #expect(throws: AmountError.self) { try MicroAlgos(checkedAlgos: -0.000_001) }
        #expect(throws: AmountError.self) { try MicroAlgos(checkedAlgos: 1e30) }
        // 2^64 microAlgos exactly: `UInt64.max` rounds up to this as a Double, so a naive
        // `<= Double(UInt64.max)` bound would still admit it.
        #expect(throws: AmountError.self) { try MicroAlgos(checkedAlgos: 0x1p64 / 1_000_000) }
        #expect(throws: AmountError.self) { try MicroAlgos(checkedAlgos: 2e13) }
    }

    @Test("AssetParams.baseUnits(for:) converts, rounds to the nearest base unit, and rejects the unrepresentable")
    internal func assetBaseUnits() throws {
        let twoDecimals = AssetParams(total: 1_000_000, decimals: 2, unitName: "DEMO")
        let tenAndAHalf = try twoDecimals.baseUnits(for: 10.5)
        #expect(tenAndAHalf == 1050)
        let hundred = try twoDecimals.baseUnits(for: 100.0)
        #expect(hundred == 10_000)
        let cent = try twoDecimals.baseUnits(for: 0.01)
        #expect(cent == 1)
        let zero = try twoDecimals.baseUnits(for: 0)
        #expect(zero == 0)
        // 0.29 * 100 is 28.999999999999996 in binary; the nearest base unit is 29.
        let twentyNine = try twoDecimals.baseUnits(for: 0.29)
        #expect(twentyNine == 29)

        let sixDecimals = AssetParams(total: 1, decimals: 6)
        let oneAndAHalf = try sixDecimals.baseUnits(for: 1.5)
        #expect(oneAndAHalf == 1_500_000)
        let noDecimals = AssetParams(total: 1, decimals: 0)
        let five = try noDecimals.baseUnits(for: 5.0)
        #expect(five == 5)

        #expect(throws: AmountError.self) { try twoDecimals.baseUnits(for: -1) }
        #expect(throws: AmountError.self) { try twoDecimals.baseUnits(for: -0.001) }
        #expect(throws: AmountError.self) { try twoDecimals.baseUnits(for: .nan) }
        #expect(throws: AmountError.self) { try twoDecimals.baseUnits(for: .infinity) }
        #expect(throws: AmountError.self) { try twoDecimals.baseUnits(for: -.infinity) }
        #expect(throws: AmountError.self) { try twoDecimals.baseUnits(for: 1e30) }
        #expect(throws: AmountError.self) { try noDecimals.baseUnits(for: 0x1p64) }
        #expect(throws: AmountError.self) { try noDecimals.baseUnits(for: Double(UInt64.max)) }
        #expect(throws: AmountError.self) { try AssetParams(total: 1, decimals: 19).baseUnits(for: 2.0) }
    }

    @Test("Amount errors describe themselves")
    internal func amountErrorsDescribeThemselves() {
        #expect(AmountError.overflow("x").errorDescription == "Amount overflow: x")
        #expect(AmountError.divisionByZero.errorDescription == "Amount division by zero")
        #expect(AmountError.notRepresentable("y").errorDescription == "Amount not representable: y")
    }

    // MARK: - Internal encoder and hash (REQ-algorand-032)

    @Test("A raw MessagePack value is spliced verbatim and the writer is unchanged otherwise")
    internal func rawValuesAreSplicedVerbatim() throws {
        let payload = Data([0x81, 0xA1, 0x61, 0x01])
        var writer = MessagePackWriter()
        let encoded = try writer.write(map: ["b": .raw(payload), "a": .uint(7)])
        #expect(encoded == Data([0x82, 0xA1, 0x61, 0x07, 0xA1, 0x62]) + payload)

        // The hash the encoder's callers depend on is the FIPS 180-4 SHA-512/256 of the empty
        // string, so internalising it changed nothing.
        let empty = SHA512_256.hash(data: Data())
        #expect(empty.map { String(format: "%02x", $0) }.joined().hasPrefix("c672b8d1ef56ed28"))
    }

    // MARK: - Client fixes (REQ-algorand-033)

    @Test("A base URL that is not an absolute http(s) URL is reported as invalidURL")
    internal func invalidBaseURLsAreInvalidURL() {
        for candidate in ["not a url", "ftp://node.example.com", "node.example.com", "https://", ""] {
            do {
                _ = try AlgodClient(baseURL: candidate)
                Issue.record("AlgodClient accepted \(candidate)")
            } catch AlgorandError.invalidURL {
                // expected
            } catch {
                Issue.record("AlgodClient threw \(error) for \(candidate)")
            }
            do {
                _ = try IndexerClient(baseURL: candidate)
                Issue.record("IndexerClient accepted \(candidate)")
            } catch AlgorandError.invalidURL {
                // expected
            } catch {
                Issue.record("IndexerClient threw \(error) for \(candidate)")
            }
        }

        #expect(throws: Never.self) { try AlgodClient(baseURL: "https://testnet-api.algonode.cloud") }
        #expect(throws: Never.self) { try IndexerClient(baseURL: "http://localhost:8980") }
        #expect(AlgorandError.invalidURL("x").errorDescription == "Invalid URL: x")
    }

    @Test("Every built-in endpoint parses and the factories resolve them without trapping")
    internal func builtInEndpointsResolve() throws {
        for endpoint in AlgorandConfiguration.Endpoint.allCases {
            #expect(throws: Never.self) { try endpoint.resolve() }
        }

        let testnet = try AlgorandConfiguration.testnet()
        #expect(testnet.algodURL.absoluteString == "https://testnet-api.algonode.cloud")
        #expect(testnet.indexerURL?.absoluteString == "https://testnet-idx.algonode.cloud")
        #expect(testnet.apiToken == nil)

        let mainnet = try AlgorandConfiguration.mainnet(apiToken: "token")
        #expect(mainnet.algodURL.absoluteString == "https://mainnet-api.algonode.cloud")
        #expect(mainnet.indexerURL?.absoluteString == "https://mainnet-idx.algonode.cloud")
        #expect(mainnet.apiToken == "token")

        let localnet = try AlgorandConfiguration.localnet()
        #expect(localnet.algodURL.absoluteString == "http://localhost:4001")
        #expect(localnet.indexerURL?.absoluteString == "http://localhost:8980")
        #expect(localnet.apiToken == AlgorandConfiguration.defaultLocalnetAPIToken)
        #expect(AlgorandConfiguration.defaultLocalnetAPIToken == String(repeating: "a", count: 64))

        let algod = try #require(URL(string: "https://node.example.com"))
        let custom = AlgorandConfiguration.custom(algodURL: algod)
        #expect(custom.algodURL == algod)
        #expect(custom.indexerURL == nil)
    }

    @Test("The box URL carries a real query and a fully percent-encoded name")
    internal func boxURLIsWellFormed() throws {
        // Base64 of these bytes is "+/8=" - a `+`, a `/`, and padding, the three characters that
        // break naive query building.
        let name = Data([0xFB, 0xFF])
        #expect(name.base64EncodedString() == "+/8=")

        let base = try #require(URL(string: "https://algod.example.com"))
        let url = try AlgodClient.boxURL(baseURL: base, applicationID: 600_011_882, name: name)
        #expect(url.path == "/v2/applications/600011882/box")
        #expect(url.query == "name=b64%3A%2B%2F8%3D")
        #expect(!url.absoluteString.contains("%3F"))
        #expect(url.absoluteString == "https://algod.example.com/v2/applications/600011882/box?name=b64%3A%2B%2F8%3D")
    }

    @Test("The simulate body is MessagePack with the signed transactions spliced in")
    internal func simulateBodyIsMessagePack() throws {
        let first = Data([0x81, 0xA1, 0x61, 0x01])
        let second = Data([0x81, 0xA1, 0x62, 0x02])
        let request = SimulateRequest(txnGroups: [SimulateRequestTransactionGroup(txns: [first, second])])
        let body = try request.encodedForSimulate()

        var expected = Data([0x81])                     // fixmap(1)
        expected.append(0xAA)                           // fixstr(10)
        expected.append(contentsOf: "txn-groups".utf8)  // "txn-groups"
        expected.append(0x91)                           // fixarray(1)
        expected.append(0x81)                           // fixmap(1)
        expected.append(0xA4)                           // fixstr(4)
        expected.append(contentsOf: "txns".utf8)        // "txns"
        expected.append(0x92)                           // fixarray(2)
        expected.append(first)
        expected.append(second)
        #expect(body == expected)
    }

    @Test("Unset simulate flags are omitted, set ones are booleans in canonical order")
    internal func simulateFlagsAreOmittedOrCanonical() throws {
        let request = SimulateRequest(
            txnGroups: [SimulateRequestTransactionGroup(txns: [Data([0xC0])])],
            allowEmptySignatures: true,
            execTraceConfig: ExecTraceConfig(enable: true, stackChange: true),
            extraOpcodeBudget: 320
        )
        let body = try request.encodedForSimulate()
        let text = String(decoding: body, as: UTF8.self)

        // Four keys: allow-empty-signatures, exec-trace-config, extra-opcode-budget, txn-groups.
        #expect(body.first == 0x84)
        #expect(text.contains("allow-empty-signatures"))
        #expect(text.contains("exec-trace-config"))
        #expect(text.contains("stack-change"))
        #expect(text.contains("extra-opcode-budget"))
        #expect(!text.contains("allow-more-logging"))
        #expect(!text.contains("allow-unnamed-resources"))
        #expect(!text.contains("scratch-change"))
        #expect(!text.contains("round"))

        let allow = try #require(text.range(of: "allow-empty-signatures")).lowerBound
        let trace = try #require(text.range(of: "exec-trace-config")).lowerBound
        let budget = try #require(text.range(of: "extra-opcode-budget")).lowerBound
        let groups = try #require(text.range(of: "txn-groups")).lowerBound
        #expect(allow < trace && trace < budget && budget < groups)

        // `true` is a MessagePack bool (0xC3), never a uint.
        #expect(body.contains(0xC3))
    }

    @Test("A simulate group built from signed transactions carries their exact encodings")
    internal func simulateGroupFromSignedTransactions() throws {
        let account = try Account(privateKey: Data(repeating: 0x51, count: 32))
        let receiver = try Address(string: Self.canonicalAddress)
        let payment = PaymentTransaction(
            sender: account.address,
            receiver: receiver,
            amount: MicroAlgos(1000),
            fee: MicroAlgos(1000),
            firstValid: 1,
            lastValid: 1001,
            genesisID: "testnet-v1.0",
            genesisHash: Data(repeating: 0x11, count: 32)
        )
        let signed = try SignedTransaction.sign(payment, with: account)
        let group = try SimulateRequestTransactionGroup(signedTransactions: [signed])
        let encoded = try signed.encode()
        #expect(group.txns == [encoded])

        let body = try SimulateRequest(txnGroups: [group]).encodedForSimulate()
        #expect(body.suffix(encoded.count) == encoded)
    }

    @Test("Simulate and pending responses decode, and the transaction echo is ignored")
    internal func responsesDecode() throws {
        let simulate = Data(
            #"""
            {"last-round":66992586,"version":2,"txn-groups":[{"failed-at":[0],
             "failure-message":"transaction X: overspend (account Y, data {}, tried to spend 1mA)",
             "txn-results":[{"txn-result":{"pool-error":"","txn":{"sig":"AAA=","txn":{"type":"pay","fee":1000}}}}]}]}
            """#.utf8
        )
        let response = try JSONDecoder().decode(SimulateResponse.self, from: simulate)
        #expect(response.lastRound == 66_992_586)
        #expect(response.txnGroups.count == 1)
        #expect(response.txnGroups.first?.failedAt == [0])
        #expect(response.txnGroups.first?.failureMessage?.contains("overspend") == true)
        #expect(response.txnGroups.first?.txnResults.first?.txnResult.confirmedRound == nil)

        let pending = try JSONDecoder().decode(
            PendingTransaction.self,
            from: Data(#"{"confirmed-round":101,"asset-index":7,"txn":{"sig":"AAA=","txn":{"type":"acfg"}}}"#.utf8)
        )
        #expect(pending.confirmedRound == 101)
        #expect(pending.assetIndex == 7)
        #expect(pending.poolError == nil)
    }

    @Test("A block response carries the header the indexer returns")
    internal func blockResponseDecodes() throws {
        let json = Data(
            #"""
            {"round":66992586,"timestamp":1786000000,"genesis-id":"testnet-v1.0",
             "genesis-hash":"SGO1GKSzyE7IEPItTxCByw9x8FmnrCDexi9/cOUJOiI=",
             "previous-block-hash":"cHJldg==","seed":"c2VlZA==","transactions-root":"cm9vdA==",
             "transactions-root-sha256":"c2hh","txn-counter":12345,"proposer":"\#(Self.canonicalAddress)",
             "transactions":[{"id":"ABC","sender":"\#(Self.canonicalAddress)","fee":1000,"tx-type":"pay",
                              "confirmed-round":66992586}],
             "upgrade-state":{"current-protocol":"v42"}}
            """#.utf8
        )
        let block = try JSONDecoder().decode(BlockResponse.self, from: json)
        #expect(block.round == 66_992_586)
        #expect(block.timestamp == 1_786_000_000)
        #expect(block.genesisID == "testnet-v1.0")
        #expect(block.previousBlockHash == "cHJldg==")
        #expect(block.seed == "c2VlZA==")
        #expect(block.transactionsRoot == "cm9vdA==")
        #expect(block.transactionsRootSha256 == "c2hh")
        #expect(block.txnCounter == 12_345)
        #expect(block.proposer == Self.canonicalAddress)
        #expect(block.transactions?.count == 1)
        #expect(block.transactions?.first?.id == "ABC")
        #expect(block.transactions?.first?.txType == "pay")

        let minimal = try JSONDecoder().decode(BlockResponse.self, from: Data(#"{"round":1}"#.utf8))
        #expect(minimal.round == 1)
        #expect(minimal.proposer == nil)
        #expect(minimal.transactions == nil)
    }

    @Test("An indexer asset decodes its full parameters through AssetParamsResponse")
    internal func indexerAssetDecodesFullParameters() throws {
        let json = Data(
            #"""
            {"index":31566704,"params":{"creator":"\#(Self.canonicalAddress)","decimals":6,"total":18446744073709551615,
             "unit-name":"USDC","name":"USDC","url":"https://example.com","default-frozen":false,
             "manager":"\#(Self.canonicalAddress)","metadata-hash":"AAAA"}}
            """#.utf8
        )
        let asset = try JSONDecoder().decode(IndexerAsset.self, from: json)
        #expect(asset.index == 31_566_704)
        #expect(asset.params.creator == Self.canonicalAddress)
        #expect(asset.params.url == "https://example.com")
        #expect(asset.params.total == UInt64.max)
        #expect(asset.params.decimals == 6)
        #expect(asset.params.unitName == "USDC")
        #expect(asset.params.manager == Self.canonicalAddress)
        #expect(asset.params.defaultFrozen == false)
    }

    @Test("Only algod's 404 counts as 'not seen yet' while polling")
    internal func notYetKnownMatchesOnly404() {
        #expect(AlgodClient.isNotYetKnown(AlgorandError.apiError(statusCode: 404, message: "txn not found")))
        #expect(!AlgodClient.isNotYetKnown(AlgorandError.apiError(statusCode: 400, message: "bad")))
        #expect(!AlgodClient.isNotYetKnown(AlgorandError.apiError(statusCode: 500, message: "boom")))
        #expect(!AlgodClient.isNotYetKnown(AlgorandError.networkError("offline")))
        #expect(!AlgodClient.isNotYetKnown(URLError(.timedOut)))
    }

    // MARK: - Transport behaviour (REQ-algorand-033)

    /// The transport tests share one `StubProtocol` response queue, so they run one at a time;
    /// everything else in the parent suite stays parallel.
    @Suite(.serialized)
    internal struct Transport {

        private static var nodeStatusJSON: Data { SafetyAndSurfaceTests.nodeStatusJSON }

        private static func stubClient() throws -> AlgodClient { try SafetyAndSurfaceTests.stubClient() }

        /// algod answers 404 until the transaction reaches the queried node's pool. The 4665470 client
        /// surfaced that as `apiError(404, …)` and gave up on the first poll.
        @Test("waitForConfirmation keeps polling through a 404 and returns the confirmation")
        internal func waitForConfirmationToleratesA404() async throws {
            StubProtocol.setResponses([
                StubResponse(status: 200, body: Self.nodeStatusJSON),                              // status()
                StubResponse(status: 404, body: Data(#"{"message":"transaction not found"}"#.utf8)), // pending -> 404
                StubResponse(status: 200, body: Self.nodeStatusJSON),                              // waitForBlock
                StubResponse(status: 200, body: Data(#"{"confirmed-round":101}"#.utf8))            // pending -> ok
            ])

            let client = try Self.stubClient()
            let confirmed = try await client.waitForConfirmation(transactionID: "ABC", timeout: 3)
            #expect(confirmed.confirmedRound == 101)
            #expect(StubProtocol.requestCount == 4)

            let paths = StubProtocol.records.compactMap { $0.url?.path }
            #expect(paths == [
                "/v2/status",
                "/v2/transactions/pending/ABC",
                "/v2/status/wait-for-block-after/100",
                "/v2/transactions/pending/ABC"
            ])
        }

        @Test("waitForConfirmation surfaces non-404 failures and pool errors unchanged")
        internal func waitForConfirmationSurfacesOtherFailures() async throws {
            StubProtocol.setResponses([
                StubResponse(status: 200, body: Self.nodeStatusJSON),
                StubResponse(status: 500, body: Data(#"{"message":"boom"}"#.utf8))
            ])
            let client = try Self.stubClient()
            do {
                _ = try await client.waitForConfirmation(transactionID: "ABC", timeout: 3)
                Issue.record("A 500 was swallowed")
            } catch AlgorandError.apiError(let statusCode, _) {
                #expect(statusCode == 500)
            }

            StubProtocol.setResponses([
                StubResponse(status: 200, body: Self.nodeStatusJSON),
                StubResponse(status: 200, body: Data(#"{"pool-error":"overspend"}"#.utf8))
            ])
            do {
                _ = try await client.waitForConfirmation(transactionID: "ABC", timeout: 3)
                Issue.record("A pool error was swallowed")
            } catch AlgorandError.networkError(let message) {
                #expect(message.contains("overspend"))
            }
        }

        @Test("waitForConfirmation rejects a timeout that overflows the round counter")
        internal func waitForConfirmationRejectsOverflowingTimeout() async throws {
            let status = Data(
                #"""
                {"last-round":18446744073709551615,"last-version":"v42","next-version":"v42","next-version-round":0,
                 "next-version-supported":true,"time-since-last-round":0,"catchup-time":0}
                """#.utf8
            )
            StubProtocol.setResponses([StubResponse(status: 200, body: status)])
            let client = try Self.stubClient()
            do {
                _ = try await client.waitForConfirmation(transactionID: "ABC", timeout: 10)
                Issue.record("Expected an overflow error")
            } catch AlgorandError.invalidTransaction(let message) {
                #expect(message.contains("overflows"))
            }
        }

        @Test("applicationBox sends the live query URL")
        internal func applicationBoxSendsALiveQueryURL() async throws {
            StubProtocol.setResponses([
                StubResponse(status: 200, body: Data(#"{"name":"+/8=","value":"","round":1}"#.utf8))
            ])
            let client = try Self.stubClient()
            let box = try await client.applicationBox(600_011_882, name: Data([0xFB, 0xFF]))
            #expect(box.round == 1)

            let requested = try #require(StubProtocol.lastRecord?.url)
            #expect(requested.path == "/v2/applications/600011882/box")
            #expect(requested.query == "name=b64%3A%2B%2F8%3D")
        }

        @Test("simulateTransaction posts MessagePack and decodes the JSON response")
        internal func simulatePostsMessagePack() async throws {
            let success = Data(#"{"last-round":1,"version":2,"txn-groups":[{"txn-results":[]}]}"#.utf8)
            StubProtocol.setResponses([StubResponse(status: 200, body: success)])
            let client = try Self.stubClient()
            let group = SimulateRequestTransactionGroup(txns: [Data([0x81, 0xA1, 0x61, 0x01])])
            let request = SimulateRequest(txnGroups: [group])
            let response = try await client.simulateTransaction(request)
            #expect(response.lastRound == 1)
            #expect(response.txnGroups.first?.failureMessage == nil)

            let record = try #require(StubProtocol.lastRecord)
            #expect(record.url?.path == "/v2/transactions/simulate")
            #expect(record.headers?["Content-Type"] == "application/msgpack")
            #expect(record.headers?["Accept"] == "application/json")
            let expectedBody = try request.encodedForSimulate()
            #expect(record.body == expectedBody)
        }

    }

    // MARK: - Key storage (REQ-algorand-034)

    /// CryptoKit's Ed25519 signing is randomized on Apple platforms (BoringSSL's is deterministic),
    /// so the key surviving `mnemonic()` is shown by cross-verification rather than byte equality.
    @Test("An account round-trips through its mnemonic and keeps signing with the same key")
    internal func accountKeyStorageIsStable() throws {
        let seed = Data((0..<32).map { UInt8(truncatingIfNeeded: $0 * 13 + 5) })
        let account = try Account(privateKey: seed)
        let message = Data("canonical".utf8)

        let before = try account.sign(message)
        #expect(before.count == 64)
        let phrase = try account.mnemonic()
        let again = try account.mnemonic()
        #expect(phrase == again)
        let decoded = try Mnemonic.decode(phrase)
        #expect(decoded == seed)

        // The key is intact after `mnemonic()` materialised the seed: it still signs for the
        // stored public key, and the stored public key still verifies the earlier signature.
        let after = try account.sign(message)
        #expect(account.verify(signature: after, for: message))
        #expect(account.verify(signature: before, for: message))
        #expect(!account.verify(signature: before, for: Data("other".utf8)))

        let restored = try Account(mnemonic: phrase)
        #expect(restored.address == account.address)
        #expect(restored.publicKey == account.publicKey)
        let restoredSignature = try restored.sign(message)
        #expect(account.verify(signature: restoredSignature, for: message))
        #expect(restored.verify(signature: before, for: message))

        // Copies share one key and behave identically.
        let copy = account
        let copySignature = try copy.sign(message)
        #expect(account.verify(signature: copySignature, for: message))

        #expect(throws: AlgorandError.self) { try Account(privateKey: Data(repeating: 1, count: 31)) }
    }
}

// MARK: - Test transport

internal struct StubResponse: Sendable {
    internal let status: Int
    internal let body: Data
}

internal struct StubRecord: Sendable {
    internal let url: URL?
    internal let headers: [String: String]?
    internal let body: Data?
}

/// Records what the client sent and replays canned responses in order.
///
/// `URLProtocol.startLoading()` is synchronous and is called off the test's task, so the store is
/// a lock-guarded value rather than an actor. `nonisolated(unsafe)` is the narrowest way to say
/// that: every access below goes through `lock`.
internal final class StubProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var responses: [StubResponse] = []
    nonisolated(unsafe) private static var storedRecords: [StubRecord] = []

    internal static func setResponses(_ responses: [StubResponse]) {
        lock.lock()
        defer { lock.unlock() }
        self.responses = responses
        self.storedRecords = []
    }

    internal static var records: [StubRecord] {
        lock.lock()
        defer { lock.unlock() }
        return storedRecords
    }

    internal static var lastRecord: StubRecord? {
        records.last
    }

    internal static var requestCount: Int {
        records.count
    }

    internal static func configuration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return configuration
    }

    private static func record(_ request: URLRequest, body: Data?) -> StubResponse {
        lock.lock()
        defer { lock.unlock() }
        storedRecords.append(StubRecord(url: request.url, headers: request.allHTTPHeaderFields, body: body))
        guard !responses.isEmpty else {
            return StubResponse(status: 500, body: Data(#"{"message":"no stub"}"#.utf8))
        }
        return responses.removeFirst()
    }

    override internal class func canInit(with request: URLRequest) -> Bool { true }

    override internal class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override internal func startLoading() {
        // `httpBody` is nil once URLSession has turned the body into a stream, so read it back from
        // the stream when that happens.
        var body = request.httpBody
        if body == nil, let stream = request.httpBodyStream {
            body = Self.drain(stream)
        }

        let stub = Self.record(request, body: body)

        guard
            let url = request.url,
            let response = HTTPURLResponse(
                url: url,
                statusCode: stub.status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override internal func stopLoading() {}

    private static func drain(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            guard read > 0 else { break }
            data.append(contentsOf: buffer[0..<read])
        }
        return data
    }
}
