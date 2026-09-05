@preconcurrency import Foundation
import Testing
@testable import Algorand

/**
 The consensus v42 fee model: strategies, usage, and the pooled group requirement.

 The oracle for every usage figure is go-algorand v5.0.1-stable (`Header.FeeContribution`,
 `ApplicationCallTxnFields.feeContribution`, `SignedTxn.FeeFactor`, `SummarizeFees`,
 `CheckGroupFees`) and a live TestNet v42 node's `group-usage`, recorded in the change's testing
 artifact. Fixtures are the canonical suite's: TestNet genesis, account A as sender, account B as
 receiver, and the first post-quantum key. Throwing calls are hoisted out of `#expect` because the
 Swift 6.0 toolchain's macro does not accept them inside its expression.
 */

/// Requirement evidence: REQ-algorand-024, REQ-algorand-025, REQ-algorand-026, REQ-algorand-027, REQ-algorand-028.
@Suite
internal struct FeeModelTests {

    // MARK: - Fixtures

    /// The usage of an ordinary transaction: one minimum fee.
    internal static let oneFee: UInt64 = 1_000_000

    /// The spec URL a live TestNet node reports as `consensus-version`.
    internal static let v42Identifier =
        "https://github.com/algorandfoundation/specs/tree/268b63433a907455d439995bf916f6b296018f4f"

    internal static func makeParams(
        minFee: UInt64 = 1000,
        fee: UInt64 = 0,
        lastRound: UInt64 = 51
    ) throws -> TransactionParams {
        TransactionParams(
            consensusVersion: v42Identifier,
            minFee: minFee,
            fee: fee,
            genesisID: CanonicalEncodingTests.genesisID,
            genesisHash: try CanonicalEncodingTests.genesisHash(),
            lastRound: lastRound
        )
    }

    /// The `pay_normal` payment from header fields, with an explicit fee.
    internal static func makePayment(
        fee: MicroAlgos = MicroAlgos(1000),
        note: Data? = nil
    ) throws -> PaymentTransaction {
        PaymentTransaction(
            sender: try CanonicalEncodingTests.accountA(),
            receiver: try CanonicalEncodingTests.accountB(),
            amount: MicroAlgos(1_000_000),
            fee: fee,
            firstValid: 51,
            lastValid: 1051,
            genesisID: CanonicalEncodingTests.genesisID,
            genesisHash: try CanonicalEncodingTests.genesisHash(),
            note: note
        )
    }

    internal static func makeApplicationCall(
        approvalProgram: Data? = nil,
        clearStateProgram: Data? = nil,
        appArguments: [Data]? = nil,
        extraPages: UInt64? = nil,
        note: Data? = nil
    ) throws -> ApplicationCallTransaction {
        ApplicationCallTransaction(
            sender: try CanonicalEncodingTests.accountA(),
            applicationID: 0,
            approvalProgram: approvalProgram,
            clearStateProgram: clearStateProgram,
            appArguments: appArguments,
            accounts: [try CanonicalEncodingTests.accountB()],
            foreignApps: [7],
            foreignAssets: [9],
            boxes: [(0, Data("box".utf8))],
            extraPages: extraPages,
            fee: MicroAlgos(1000),
            firstValid: 51,
            lastValid: 1051,
            genesisID: CanonicalEncodingTests.genesisID,
            genesisHash: try CanonicalEncodingTests.genesisHash(),
            note: note
        )
    }

    /// A shape-valid Falcon-1024 proof for the first golden key; it fails Falcon verification by
    /// design and is never sent anywhere.
    internal static func makePostQuantumProof() throws -> PQSignature {
        let key = PostQuantumVectors.pqAddressCases[0]
        return PQSignature(
            scheme: .falcon1024,
            salt: UInt8(key.salt),
            publicKey: try hexData(key.publicKeyHex),
            signature: Data(repeating: 0x5A, count: PostQuantumVectors.falconDet1024SignatureSize)
        )
    }

    // MARK: - Strategies

    @Test("pay_min_fee_from_params: .minimum reads min-fee, byte-exact through the builder and the initializer")
    internal func testMinimumStrategyReadsMinFeeFromParams() throws {
        let params = try Self.makeParams(minFee: 2000)
        let expected = try hexData(DeferredVectors.payMinFeeFromParamsHex)

        let built = try PaymentTransactionBuilder()
            .sender(try CanonicalEncodingTests.accountA())
            .receiver(try CanonicalEncodingTests.accountB())
            .amount(MicroAlgos(1_000_000))
            .params(params)
            .build()
        let builtBytes = try built.encode()
        let builtID = try built.id()

        let initialized = try PaymentTransaction(
            sender: try CanonicalEncodingTests.accountA(),
            receiver: try CanonicalEncodingTests.accountB(),
            amount: MicroAlgos(1_000_000),
            params: params
        )
        let initializedBytes = try initialized.encode()

        #expect(built.fee == MicroAlgos(2000))
        #expect(builtBytes == expected)
        #expect(builtID == DeferredVectors.payMinFeeFromParamsTxID)
        #expect(initializedBytes == expected)
        #expect(initialized.firstValid == 51)
        #expect(initialized.lastValid == 1051)
    }

    @Test(".minimum is the usage requirement, so a priced note raises it above min-fee")
    internal func testMinimumStrategyPricesUsage() throws {
        let params = try Self.makeParams(minFee: 1000)
        let plain = try PaymentTransaction(
            sender: try CanonicalEncodingTests.accountA(),
            receiver: try CanonicalEncodingTests.accountB(),
            amount: MicroAlgos(1),
            params: params
        )
        let noted = try PaymentTransaction(
            sender: try CanonicalEncodingTests.accountA(),
            receiver: try CanonicalEncodingTests.accountB(),
            amount: MicroAlgos(1),
            params: params,
            note: Data(repeating: 0x41, count: 2000)
        )

        #expect(plain.fee == MicroAlgos(1000))
        #expect(noted.fee == MicroAlgos(1098))
    }

    @Test(".flat carries the amount verbatim, including a zero that is omitted from the encoding")
    internal func testFlatStrategyIsCarriedVerbatim() throws {
        let params = try Self.makeParams()
        let pinned = try PaymentTransaction(
            sender: try CanonicalEncodingTests.accountA(),
            receiver: try CanonicalEncodingTests.accountB(),
            amount: MicroAlgos(1_000_000),
            fee: .flat(MicroAlgos(5000)),
            params: params
        )
        let unpaid = try PaymentTransaction(
            sender: try CanonicalEncodingTests.accountA(),
            receiver: try CanonicalEncodingTests.accountB(),
            amount: MicroAlgos(1_000_000),
            fee: .flat(MicroAlgos(0)),
            params: params
        )
        let unpaidBytes = try unpaid.encode()
        let feeKey = Data([0xA3, 0x66, 0x65, 0x65])

        #expect(pinned.fee == MicroAlgos(5000))
        #expect(unpaid.fee == MicroAlgos(0))
        #expect(!unpaidBytes.contains(feeKey))
    }

    @Test(".suggested uses the per-byte fee over the signed size and never drops below the minimum")
    internal func testSuggestedStrategyFloorsAtMinimum() throws {
        let uncongested = try Self.makeParams(minFee: 1000, fee: 0)
        let cheap = try Self.makeParams(minFee: 1000, fee: 1)
        let congested = try Self.makeParams(minFee: 1000, fee: 30)

        let draftSize = try Self.makePayment(fee: MicroAlgos(1000)).encode().count
        let sizedFee = UInt64(draftSize + 75) * 30

        let floored = try Self.makePayment(fee: MicroAlgos(1000)).encode()
        let atMinimum = try PaymentTransaction(
            sender: try CanonicalEncodingTests.accountA(),
            receiver: try CanonicalEncodingTests.accountB(),
            amount: MicroAlgos(1_000_000),
            fee: .suggested,
            params: uncongested
        )
        let stillMinimum = try PaymentTransaction(
            sender: try CanonicalEncodingTests.accountA(),
            receiver: try CanonicalEncodingTests.accountB(),
            amount: MicroAlgos(1_000_000),
            fee: .suggested,
            params: cheap
        )
        let sized = try PaymentTransaction(
            sender: try CanonicalEncodingTests.accountA(),
            receiver: try CanonicalEncodingTests.accountB(),
            amount: MicroAlgos(1_000_000),
            fee: .suggested,
            params: congested
        )
        let atMinimumBytes = try atMinimum.encode()

        #expect(atMinimum.fee == MicroAlgos(1000))
        #expect(atMinimumBytes == floored)
        #expect(stillMinimum.fee == MicroAlgos(1000))
        #expect(sized.fee == MicroAlgos(sizedFee))
        #expect(sized.fee > MicroAlgos(1000))
    }

    @Test("A strategy resolved by hand agrees with the initializer")
    internal func testStrategyResolvesForAnyTransaction() throws {
        let params = try Self.makeParams(minFee: 1500)
        let draft = try Self.makePayment(fee: MicroAlgos(1500), note: Data(repeating: 1, count: 1124))

        let minimum = try FeeStrategy.minimum.fee(for: draft, params: params)
        let flat = try FeeStrategy.flat(MicroAlgos(42)).fee(for: draft, params: params)
        let suggested = try FeeStrategy.suggested.fee(for: draft, params: params)

        // usage 1_010_000 at min-fee 1500 = 1515 exactly.
        #expect(minimum == MicroAlgos(1515))
        #expect(flat == MicroAlgos(42))
        #expect(suggested == MicroAlgos(1515))
    }

    @Test("The builder's fee overloads pin a flat fee or choose a strategy")
    internal func testBuilderFeeOverloads() throws {
        let params = try Self.makeParams(minFee: 1000, fee: 0)
        let base = PaymentTransactionBuilder()
            .sender(try CanonicalEncodingTests.accountA())
            .receiver(try CanonicalEncodingTests.accountB())
            .amount(MicroAlgos(1))
            .params(params)

        let pinned = try base.fee(MicroAlgos(2500)).build()
        let strategic = try base.fee(.suggested).build()
        let defaulted = try base.build()

        #expect(pinned.fee == MicroAlgos(2500))
        #expect(strategic.fee == MicroAlgos(1000))
        #expect(defaulted.fee == MicroAlgos(1000))
    }

    @Test("Header-field initializers default to the certified protocol's minimum fee")
    internal func testHeaderFieldInitializersDefaultToTheCertifiedMinimum() throws {
        let genesisHash = try CanonicalEncodingTests.genesisHash()
        let sender = try CanonicalEncodingTests.accountA()
        let payment = PaymentTransaction(
            sender: sender,
            receiver: try CanonicalEncodingTests.accountB(),
            amount: MicroAlgos(1),
            firstValid: 51,
            lastValid: 1051,
            genesisID: CanonicalEncodingTests.genesisID,
            genesisHash: genesisHash
        )
        let optIn = AssetOptInTransaction(
            sender: sender,
            assetID: 1,
            firstValid: 51,
            lastValid: 1051,
            genesisID: CanonicalEncodingTests.genesisID,
            genesisHash: genesisHash
        )
        let offline = KeyRegistrationTransaction.offline(
            sender: sender,
            firstValid: 51,
            lastValid: 1051,
            genesisID: CanonicalEncodingTests.genesisID,
            genesisHash: genesisHash
        )
        let call = ApplicationCallTransaction.call(
            sender: sender,
            applicationID: 1,
            firstValid: 51,
            lastValid: 1051,
            genesisID: CanonicalEncodingTests.genesisID,
            genesisHash: genesisHash
        )

        #expect(AlgorandConsensus.v42.minimumFee == MicroAlgos(1000))
        #expect(AlgorandConsensus.v42.identifier == Self.v42Identifier)
        #expect(payment.fee == AlgorandConsensus.v42.minimumFee)
        #expect(optIn.fee == AlgorandConsensus.v42.minimumFee)
        #expect(offline.fee == AlgorandConsensus.v42.minimumFee)
        #expect(call.fee == AlgorandConsensus.v42.minimumFee)
    }

    @Test("Every params-based initializer and factory prices a strategy and fills the header from params")
    internal func testParamsInitializersAndFactoriesAcrossTypes() throws {
        let params = try Self.makeParams(minFee: 1000, lastRound: 700)
        let sender = try CanonicalEncodingTests.accountA()
        let other = try CanonicalEncodingTests.accountB()
        let program = Data([0x0A, 0x81, 0x01])
        let schema = StateSchema(numUint: 1, numByteSlice: 1)
        let flat = FeeStrategy.flat(MicroAlgos(1234))

        let votePK = Data(repeating: 1, count: 32)
        let selectionPK = Data(repeating: 2, count: 32)
        let assetParams = AssetParams(total: 1)

        let transactions: [(String, any Transaction)] = [
            ("acfg create", try AssetCreateTransaction(
                sender: sender, assetParams: assetParams, fee: flat, params: params
            )),
            ("axfer opt-in", try AssetOptInTransaction(sender: sender, assetID: 1, fee: flat, params: params)),
            ("afrz", try AssetFreezeTransaction(
                sender: sender, assetID: 1, freezeAccount: other, frozen: true, fee: flat, params: params
            )),
            ("acfg config", try AssetConfigTransaction(
                sender: sender, assetID: 1, manager: other, fee: flat, params: params
            )),
            ("acfg destroy", try AssetConfigTransaction.destroy(sender: sender, assetID: 1, fee: flat, params: params)),
            ("acfg update", try AssetConfigTransaction.update(
                sender: sender, assetID: 1, manager: other, fee: flat, params: params
            )),
            ("axfer", try AssetTransferTransaction(
                sender: sender, receiver: other, assetID: 1, amount: 5, fee: flat, params: params
            )),
            ("axfer clawback", try AssetClawbackTransaction(
                sender: sender, assetID: 1, assetSender: other, assetReceiver: sender, amount: 5,
                fee: flat, params: params
            )),
            ("keyreg", try KeyRegistrationTransaction(
                sender: sender, nonparticipation: true, fee: flat, params: params
            )),
            ("keyreg online", try KeyRegistrationTransaction.online(
                sender: sender, votePK: votePK, selectionPK: selectionPK, voteFirst: 1, voteLast: 2, voteKeyDilution: 3,
                fee: flat, params: params
            )),
            ("keyreg offline", try KeyRegistrationTransaction.offline(sender: sender, fee: flat, params: params)),
            ("keyreg nonpart", try KeyRegistrationTransaction.nonparticipating(
                sender: sender, fee: flat, params: params
            )),
            ("appl", try ApplicationCallTransaction(sender: sender, applicationID: 1, fee: flat, params: params)),
            ("appl create", try ApplicationCallTransaction.create(
                sender: sender, approvalProgram: program, clearStateProgram: program,
                globalStateSchema: schema, localStateSchema: schema, fee: flat, params: params
            )),
            ("appl update", try ApplicationCallTransaction.update(
                sender: sender, applicationID: 1, approvalProgram: program, clearStateProgram: program,
                fee: flat, params: params
            )),
            ("appl delete", try ApplicationCallTransaction.delete(
                sender: sender, applicationID: 1, fee: flat, params: params
            )),
            ("appl opt-in", try ApplicationCallTransaction.optIn(
                sender: sender, applicationID: 1, fee: flat, params: params
            )),
            ("appl close-out", try ApplicationCallTransaction.closeOut(
                sender: sender, applicationID: 1, fee: flat, params: params
            )),
            ("appl clear", try ApplicationCallTransaction.clearState(
                sender: sender, applicationID: 1, fee: flat, params: params
            )),
            ("appl call", try ApplicationCallTransaction.call(
                sender: sender, applicationID: 1, fee: flat, params: params
            ))
        ]

        for (name, transaction) in transactions {
            #expect(transaction.fee == MicroAlgos(1234), "\(name)")
            #expect(transaction.firstValid == 700, "\(name)")
            #expect(transaction.lastValid == 1700, "\(name)")
            #expect(transaction.genesisID == CanonicalEncodingTests.genesisID, "\(name)")
            #expect(transaction.genesisHash == params.genesisHash, "\(name)")
        }

        let defaulted = try KeyRegistrationTransaction.offline(sender: sender, params: params, validRounds: 10)
        let onCompletions = try [
            ApplicationCallTransaction.create(
                sender: sender, approvalProgram: program, clearStateProgram: program,
                globalStateSchema: schema, localStateSchema: schema, params: params
            ).onCompletion,
            ApplicationCallTransaction.update(
                sender: sender, applicationID: 1, approvalProgram: program, clearStateProgram: program, params: params
            ).onCompletion,
            ApplicationCallTransaction.delete(sender: sender, applicationID: 1, params: params).onCompletion,
            ApplicationCallTransaction.optIn(sender: sender, applicationID: 1, params: params).onCompletion,
            ApplicationCallTransaction.closeOut(sender: sender, applicationID: 1, params: params).onCompletion,
            ApplicationCallTransaction.clearState(sender: sender, applicationID: 1, params: params).onCompletion,
            ApplicationCallTransaction.call(sender: sender, applicationID: 1, params: params).onCompletion
        ]
        let nonparticipating = try KeyRegistrationTransaction.nonparticipating(sender: sender, params: params)

        #expect(defaulted.fee == MicroAlgos(1000))
        #expect(defaulted.lastValid == 710)
        #expect(onCompletions == [.noOp, .updateApplication, .deleteApplication, .optIn, .closeOut, .clearState, .noOp])
        #expect(nonparticipating.nonparticipation == true)
    }

    @Test("A params-based transaction encodes byte-identically to the header-field form with the same fields")
    internal func testParamsInitializerMatchesHeaderFieldInitializer() throws {
        let params = try Self.makeParams(minFee: 1000)
        let note = Data(repeating: 0x7E, count: 3000)
        let program = Data(repeating: 0x0A, count: 9000)

        let payment = try PaymentTransaction(
            sender: try CanonicalEncodingTests.accountA(),
            receiver: try CanonicalEncodingTests.accountB(),
            amount: MicroAlgos(1_000_000),
            fee: .flat(MicroAlgos(1000)),
            params: params,
            note: note
        )
        let call = try ApplicationCallTransaction(
            sender: try CanonicalEncodingTests.accountA(),
            applicationID: 0,
            approvalProgram: program,
            clearStateProgram: program,
            appArguments: [Data(repeating: 1, count: 3000)],
            accounts: [try CanonicalEncodingTests.accountB()],
            foreignApps: [7],
            foreignAssets: [9],
            boxes: [(0, Data("box".utf8))],
            extraPages: 7,
            fee: .flat(MicroAlgos(1000)),
            params: params,
            note: note
        )

        let paymentBytes = try payment.encode()
        let legacyPaymentBytes = try Self.makePayment(fee: MicroAlgos(1000), note: note).encode()
        let callBytes = try call.encode()
        let legacyCallBytes = try Self.makeApplicationCall(
            approvalProgram: program,
            clearStateProgram: program,
            appArguments: [Data(repeating: 1, count: 3000)],
            extraPages: 7,
            note: note
        ).encode()

        #expect(paymentBytes == legacyPaymentBytes)
        #expect(callBytes == legacyCallBytes)
    }

    // MARK: - Usage

    @Test("Header usage is one fee plus 100 micro-units per note byte beyond 1024")
    internal func testHeaderUsageIsOneFeePlusNoteSurcharge() throws {
        let cases: [(noteBytes: Int, micros: UInt64, at1000: UInt64, at2000: UInt64)] = [
            (0, 1_000_000, 1000, 2000),
            (1024, 1_000_000, 1000, 2000),
            (1025, 1_000_100, 1001, 2001),
            (2000, 1_097_600, 1098, 2196),
            (4096, 1_307_200, 1308, 2615)
        ]

        for entry in cases {
            let note = entry.noteBytes == 0 ? nil : Data(repeating: 0x41, count: entry.noteBytes)
            let usage = try Self.makePayment(note: note).feeUsage()
            let at1000 = try usage.fee(minFee: MicroAlgos(1000))
            let at2000 = try usage.fee(minFee: MicroAlgos(2000))

            #expect(usage.micros == entry.micros, "note of \(entry.noteBytes) bytes")
            #expect(at1000 == MicroAlgos(entry.at1000), "note of \(entry.noteBytes) bytes at 1000")
            #expect(at2000 == MicroAlgos(entry.at2000), "note of \(entry.noteBytes) bytes at 2000")
        }
    }

    @Test("Non-application types price only their header")
    internal func testNonApplicationTypesUseHeaderUsageOnly() throws {
        let params = try Self.makeParams()
        let sender = try CanonicalEncodingTests.accountA()
        let note = Data(repeating: 0x41, count: 2000)

        let transfer = try AssetTransferTransaction(
            sender: sender,
            receiver: try CanonicalEncodingTests.accountB(),
            assetID: 1,
            amount: 1,
            params: params,
            note: note
        )
        let create = try AssetCreateTransaction(
            sender: sender,
            assetParams: AssetParams(total: 1, unitName: "UNIT", assetName: "Asset", url: "https://example.com"),
            params: params
        )
        let keyreg = try KeyRegistrationTransaction.online(
            sender: sender,
            votePK: Data(repeating: 1, count: 32),
            selectionPK: Data(repeating: 2, count: 32),
            voteFirst: 1,
            voteLast: 1000,
            voteKeyDilution: 10,
            stateProofPK: Data(repeating: 3, count: 64),
            params: params
        )

        let transferUsage = try transfer.feeUsage()
        let createUsage = try create.feeUsage()
        let keyregUsage = try keyreg.feeUsage()

        #expect(transferUsage.micros == 1_097_600)
        #expect(transfer.fee == MicroAlgos(1098))
        #expect(createUsage.micros == Self.oneFee)
        #expect(keyregUsage.micros == Self.oneFee)
    }

    @Test("Application usage prices argument bytes beyond 2048 and program bytes beyond 8192, nothing else")
    internal func testApplicationUsagePricesArgumentsAndPrograms() throws {
        let freeArguments = try Self.makeApplicationCall(
            appArguments: [Data(repeating: 1, count: 1024), Data(repeating: 2, count: 1024)]
        ).feeUsage()
        let pricedArguments = try Self.makeApplicationCall(
            appArguments: [Data(repeating: 1, count: 2000), Data(repeating: 2, count: 2000)]
        ).feeUsage()
        let freePrograms = try Self.makeApplicationCall(
            approvalProgram: Data(repeating: 0x0A, count: 4096),
            clearStateProgram: Data(repeating: 0x0A, count: 4096),
            extraPages: 3
        ).feeUsage()
        let onePricedByte = try Self.makeApplicationCall(
            approvalProgram: Data(repeating: 0x0A, count: 4097),
            clearStateProgram: Data(repeating: 0x0A, count: 4096),
            extraPages: 3
        ).feeUsage()
        let largePrograms = try Self.makeApplicationCall(
            approvalProgram: Data(repeating: 0x0A, count: 10000),
            clearStateProgram: Data(repeating: 0x0A, count: 2000),
            extraPages: 5
        ).feeUsage()
        let everything = try Self.makeApplicationCall(
            approvalProgram: Data(repeating: 0x0A, count: 10000),
            clearStateProgram: Data(repeating: 0x0A, count: 2000),
            appArguments: [Data(repeating: 1, count: 4000)],
            extraPages: 7,
            note: Data(repeating: 0x41, count: 2000)
        ).feeUsage()
        let pagesOnly = try Self.makeApplicationCall(extraPages: 7).feeUsage()

        #expect(freeArguments.micros == Self.oneFee)
        #expect(pricedArguments.micros == 1_195_200)
        #expect(freePrograms.micros == Self.oneFee)
        #expect(onePricedByte.micros == 1_000_100)
        #expect(largePrograms.micros == 1_380_800)
        #expect(everything.micros == 1_000_000 + 380_800 + 195_200 + 97_600)
        #expect(pagesOnly.micros == Self.oneFee)
    }

    @Test("Signature usage: nothing for Ed25519, two fees for Falcon-1024, nothing for an unknown scheme")
    internal func testSignatureUsage() throws {
        let proof = try Self.makePostQuantumProof()
        let unknownScheme = try PQScheme(bytes: Data([0x66, 0x39]))
        let transaction = try Self.makePayment()
        let account = try SignedTransactionEnvelopeTests.accountA()

        let ed25519 = try SignedTransaction.sign(transaction, with: account)
        let postQuantum = SignedTransaction(transaction: transaction, authorization: .postQuantum(proof))
        let ed25519Usage = try ed25519.feeUsage()
        let postQuantumUsage = try postQuantum.feeUsage()

        #expect(PQScheme.falcon1024.feeUsage.micros == 2_000_000)
        #expect(unknownScheme.feeUsage.micros == 0)
        #expect(TransactionAuthorization.ed25519(Data(repeating: 0, count: 64)).feeUsage.micros == 0)
        #expect(TransactionAuthorization.postQuantum(proof).feeUsage.micros == 2_000_000)
        #expect(ed25519Usage.micros == Self.oneFee)
        #expect(postQuantumUsage.micros == 3_000_000)
    }

    // MARK: - Groups

    @Test("A group's requirement is one rounding over the pooled usage, not a sum of per-member roundings")
    internal func testGroupUsageIsPooled() throws {
        let note = Data(repeating: 0x41, count: 1025)
        let first = try Self.makePayment(note: note)
        let second = PaymentTransaction(
            sender: try CanonicalEncodingTests.accountB(),
            receiver: try CanonicalEncodingTests.accountA(),
            amount: MicroAlgos(1),
            fee: MicroAlgos(1000),
            firstValid: 51,
            lastValid: 1051,
            genesisID: CanonicalEncodingTests.genesisID,
            genesisHash: try CanonicalEncodingTests.genesisHash(),
            note: note
        )
        let group = try AtomicTransactionGroup(transactions: [first, second])

        let firstFee = try first.feeUsage().fee(minFee: MicroAlgos(1000))
        let secondFee = try second.feeUsage().fee(minFee: MicroAlgos(1000))
        let usage = try group.feeUsage()
        let required = try group.requiredFee(minFee: MicroAlgos(1000))

        #expect(firstFee == MicroAlgos(1001))
        #expect(secondFee == MicroAlgos(1001))
        #expect(usage.micros == 2_000_200)
        #expect(required == MicroAlgos(2001))
    }

    @Test("A signed group passes the check when one member pays for all, and fails by the exact shortfall")
    internal func testSignedGroupCheckFees() throws {
        let params = try Self.makeParams(minFee: 1000)
        let payer = try SignedTransactionEnvelopeTests.accountA()
        let other = try SignedTransactionEnvelopeTests.authAccount()

        func makeGroup(payerFee: MicroAlgos) throws -> SignedAtomicTransactionGroup {
            let paid = try PaymentTransaction(
                sender: payer.address, receiver: other.address, amount: MicroAlgos(1),
                fee: .flat(payerFee), params: params
            )
            let covered = try PaymentTransaction(
                sender: other.address, receiver: payer.address, amount: MicroAlgos(1),
                fee: .flat(MicroAlgos(0)), params: params
            )
            let group = try AtomicTransactionGroup(transactions: [paid, covered])
            return try SignedAtomicTransactionGroup.sign(group, with: [0: payer, 1: other])
        }

        let sufficient = try makeGroup(payerFee: MicroAlgos(2000))
        let required = try sufficient.checkFees(minFee: MicroAlgos(1000))
        let sufficientUsage = try sufficient.feeUsage()

        let short = try makeGroup(payerFee: MicroAlgos(1999))
        var shortfall: FeeError?
        do {
            try short.checkFees(minFee: MicroAlgos(1000))
        } catch let error as FeeError {
            shortfall = error
        }

        #expect(required == MicroAlgos(2000))
        #expect(sufficientUsage.micros == 2_000_000)
        #expect(shortfall == .insufficient(required: MicroAlgos(2000), paid: MicroAlgos(1999)))
    }

    @Test("A Falcon-1024 member raises the signed group's requirement by two fees")
    internal func testSignedGroupCountsPostQuantumEnvelopes() throws {
        let proof = try Self.makePostQuantumProof()
        let account = try SignedTransactionEnvelopeTests.accountA()
        let first = try Self.makePayment(fee: MicroAlgos(4000))
        let second = try Self.makePayment(fee: MicroAlgos(0), note: Data("second".utf8))
        let group = try AtomicTransactionGroup(transactions: [first, second])

        let ed25519 = try SignedTransaction.sign(first, with: account, groupID: group.groupID)
        let postQuantum = SignedTransaction(
            transaction: second, authorization: .postQuantum(proof), groupID: group.groupID
        )
        let signed = SignedAtomicTransactionGroup(
            signedTransactions: [ed25519, postQuantum], groupID: group.groupID
        )

        let unsignedRequirement = try group.requiredFee(minFee: MicroAlgos(1000))
        let signedUsage = try signed.feeUsage()
        let signedRequirement = try signed.checkFees(minFee: MicroAlgos(1000))
        let predicted = try group.feeUsage()
            .adding(PQScheme.falcon1024.feeUsage)
            .fee(minFee: MicroAlgos(1000))

        #expect(unsignedRequirement == MicroAlgos(2000))
        #expect(signedUsage.micros == 4_000_000)
        #expect(signedRequirement == MicroAlgos(4000))
        #expect(predicted == signedRequirement)
    }

    // MARK: - Arithmetic

    @Test("Rounding matches FeeForUsage: exact quotients stay, any remainder rounds up once")
    internal func testFeeRoundsUpOnce() throws {
        let exact = try TransactionUsage(micros: 2_000_000).fee(minFee: MicroAlgos(1000))
        let tiny = try TransactionUsage(micros: 1_000_001).fee(minFee: MicroAlgos(1000))
        let halfway = try TransactionUsage(micros: 1_000_500).fee(minFee: MicroAlgos(1000))
        let scaled = try TransactionUsage(micros: 1_097_600).fee(minFee: MicroAlgos(2000))
        let zero = try TransactionUsage(micros: 0).fee(minFee: MicroAlgos(1000))
        let sum = try TransactionUsage(micros: 1).adding(TransactionUsage(micros: 2))

        #expect(exact == MicroAlgos(2000))
        #expect(tiny == MicroAlgos(1001))
        #expect(halfway == MicroAlgos(1001))
        #expect(scaled == MicroAlgos(2196))
        #expect(zero == MicroAlgos(0))
        #expect(sum.micros == 3)
    }

    @Test("Overflow throws a typed error and never saturates")
    internal func testOverflowThrowsInsteadOfSaturating() throws {
        let huge = TransactionUsage(micros: UInt64.max)
        let params = try Self.makeParams(minFee: 1000, fee: UInt64.max)
        let draft = try Self.makePayment()
        let account = try SignedTransactionEnvelopeTests.accountA()
        let maxed = try Self.makePayment(fee: MicroAlgos(UInt64.max))
        let group = try AtomicTransactionGroup(transactions: [maxed, maxed])
        let signed = try SignedAtomicTransactionGroup.sign(group, with: [0: account, 1: account])

        let fits = try huge.fee(minFee: MicroAlgos(1_000_000))

        var productOverflow = false
        do {
            _ = try huge.fee(minFee: MicroAlgos(1_000_001))
        } catch FeeError.overflow {
            productOverflow = true
        }

        var sumOverflow = false
        do {
            _ = try huge.adding(TransactionUsage(micros: 1))
        } catch FeeError.overflow {
            sumOverflow = true
        }

        var suggestedOverflow = false
        do {
            _ = try FeeStrategy.suggested.fee(for: draft, params: params)
        } catch FeeError.overflow {
            suggestedOverflow = true
        }

        var paidOverflow = false
        do {
            try signed.checkFees(minFee: MicroAlgos(1000))
        } catch FeeError.overflow {
            paidOverflow = true
        }

        #expect(fits == MicroAlgos(UInt64.max))
        #expect(productOverflow)
        #expect(sumOverflow)
        #expect(suggestedOverflow)
        #expect(paidOverflow)
    }

    @Test("A validity window past UInt64 is an error, not a trap")
    internal func testValidRoundsOverflowIsAnError() throws {
        let params = try Self.makeParams(lastRound: UInt64.max)

        var overflowed = false
        do {
            _ = try PaymentTransaction(
                sender: try CanonicalEncodingTests.accountA(),
                receiver: try CanonicalEncodingTests.accountB(),
                amount: MicroAlgos(1),
                params: params,
                validRounds: 1
            )
        } catch AlgorandError.invalidTransaction {
            overflowed = true
        }

        #expect(overflowed)
    }

    // MARK: - Parameters and Errors

    @Test("TransactionParams decodes the per-byte fee and tolerates its absence")
    internal func testTransactionParamsDecodesFeePerByte() throws {
        let genesisHashBase64 = "SGO1GKSzyE7IEPItTxCByw9x8FmnrCDexi9/cOUJOiI="
        let withFee = Data("""
        {"consensus-version":"\(Self.v42Identifier)","fee":7,"genesis-hash":"\(genesisHashBase64)",\
        "genesis-id":"testnet-v1.0","last-round":51,"min-fee":1000}
        """.utf8)
        let withoutFee = Data("""
        {"consensus-version":"\(Self.v42Identifier)","genesis-hash":"\(genesisHashBase64)",\
        "genesis-id":"testnet-v1.0","last-round":51,"min-fee":2000}
        """.utf8)

        let congested = try JSONDecoder().decode(TransactionParams.self, from: withFee)
        let legacy = try JSONDecoder().decode(TransactionParams.self, from: withoutFee)
        let genesisHash = try CanonicalEncodingTests.genesisHash()

        #expect(congested.fee == 7)
        #expect(congested.minFee == 1000)
        #expect(congested.consensusVersion == AlgorandConsensus.v42.identifier)
        #expect(congested.genesisHash == genesisHash)
        #expect(legacy.fee == 0)
        #expect(legacy.minFee == 2000)
    }

    @Test("Fee errors describe themselves")
    internal func testFeeErrorsDescribeThemselves() {
        let overflow = FeeError.overflow("usage 1 + 2 exceeds UInt64")
        let insufficient = FeeError.insufficient(required: MicroAlgos(2000), paid: MicroAlgos(1999))

        #expect(overflow.errorDescription == "Fee overflow: usage 1 + 2 exceeds UInt64")
        #expect(insufficient.errorDescription == "Insufficient fee: the group pays 1999 microAlgos but needs 2000")
    }
}

extension Data {
    fileprivate func contains(_ subsequence: Data) -> Bool {
        guard subsequence.count <= count else { return false }
        for offset in 0...(count - subsequence.count) where self[offset..<(offset + subsequence.count)] == subsequence {
            return true
        }
        return false
    }
}
