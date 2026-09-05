@preconcurrency import Foundation

/**
 A consensus protocol this SDK has been certified against, and the fee facts that come with it.

 `algod` names the running protocol by an opaque spec URL, reported as
 ``TransactionParams/consensusVersion``. ``v42`` is the protocol this package's fee model was
 derived from (go-algorand v5.0.1-stable, `config/consensus.go`) and verified against on a live
 TestNet node through read-only `simulate` calls, whose `group-usage` equals the usage
 ``TransactionUsage`` computes for the same group.

 The value carries only what a caller can act on: the identifier, to compare with the node's
 report, and ``minimumFee``, the protocol's `MinTxnFee`, which is what the header-field
 initializers default to when no ``TransactionParams`` are at hand. The per-byte surcharge and the
 free tiers are internal constants of the v42 model; they are documented on ``TransactionUsage``.
 */
public struct AlgorandConsensus: Sendable, Hashable {

    // MARK: - Certified Protocols

    /**
     Consensus v42, live on MainNet and TestNet since go-algorand 5.0.

     v42 introduced transaction-size pricing (`PerByteTxnSurcharge = 100`), native Falcon-1024
     account signatures (`EnablePQSchemeFalcon1024`), and the larger absolute limits those
     surcharges pay for: notes up to 4096 bytes, application arguments up to 16384 bytes in total,
     and up to 7 extra program pages. Its `MinTxnFee` is the 1000 microAlgos every protocol has
     had; `GET /v2/transactions/params` reports the same value as `min-fee`.
     */
    public static let v42 = AlgorandConsensus(
        identifier: "https://github.com/algorandfoundation/specs/tree/268b63433a907455d439995bf916f6b296018f4f",
        minimumFee: MicroAlgos(1000)
    )

    // MARK: - Properties

    /// The exact `consensus-version` string `algod` reports for this protocol.
    public let identifier: String

    /**
     `MinTxnFee`: the fee of one unit of usage, and therefore of an ordinary transaction.

     The v42 fee model prices a group as `ceil(usage * minimumFee / 1_000_000)`, so this is the
     multiplier every surcharge scales with. Prefer the live value, ``TransactionParams/minFee``,
     whenever suggested parameters are available; this constant exists so that a transaction built
     from bare header fields still has a defined, protocol-derived fee.
     */
    public let minimumFee: MicroAlgos

    // MARK: - Fee Model Constants

    /// One minimum fee expressed in usage micro-units: `basics.Micros(1e6)`.
    internal static let usageScale: UInt64 = 1_000_000

    /// `PerByteTxnSurcharge`: micro-units of usage added per byte beyond a free tier, 0.0001 of a
    /// minimum fee. At `min-fee` 1000 that is 0.1 microAlgo per byte, and it scales with `min-fee`.
    internal static let perByteSurcharge: UInt64 = 100

    /// `MaxTxnNoteBytes`: note bytes carried without surcharge. The absolute maximum is 4096.
    internal static let freeNoteBytes = 1024

    /// `MaxAppTotalArgLen`: application-argument bytes carried without surcharge, summed over
    /// every argument. The absolute maximum is 16384.
    internal static let freeApplicationArgumentBytes = 2048

    /// `MaxAppTotalProgramLen * (1 + MaxExtraAppProgramPages)`, i.e. `2048 * 4`: approval plus
    /// clear-state program bytes carried without surcharge. The hard ceiling is
    /// `2048 * (1 + apep)` with `apep` at most 7, so `apep` itself contributes nothing.
    internal static let freeProgramBytes = 8192

    /// `PQSchemeFeeContribution(PQSchemeFalcon1024)`: two minimum fees for a Falcon-1024 envelope.
    internal static let falcon1024Usage: UInt64 = 2_000_000

    // MARK: - Initializers

    /// Certification is this package's job, so only the SDK names a protocol.
    internal init(identifier: String, minimumFee: MicroAlgos) {
        self.identifier = identifier
        self.minimumFee = minimumFee
    }
}
