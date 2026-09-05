@preconcurrency import Foundation

/**
 Group-pooled fees.

 Consensus v42 checks fees once per group: `sum(fee) >= ceil(sum(usage) * minFee / 1_000_000)`.
 Because the sum is rounded once, a group where every member pays its own rounded share can
 overpay, and a group where one member pays for all is accepted as readily as one where each pays
 its own. The fee is part of every member's signed bytes and of the group identifier, so the
 requirement must be settled before the group is signed: build the members with placeholder fees,
 ask the group what it needs, and rebuild the paying member with that fee.
 */
extension AtomicTransactionGroup {

    // MARK: - Fees

    /**
     The pooled usage of the members, as Ed25519-signed transactions.

     A Falcon-1024 signer is not known until signing; add ``PQScheme/feeUsage`` for each such
     member, or ask ``SignedAtomicTransactionGroup/feeUsage()`` once the group is signed.

     - Returns: The sum of every member's ``Transaction/feeUsage()``.
     - Throws: ``FeeError/overflow(_:)`` if the sum does not fit.
     */
    public func feeUsage() throws -> TransactionUsage {
        try transactions.reduce(TransactionUsage.zero) { try $0.adding(try $1.feeUsage()) }
    }

    /**
     The smallest total fee the network accepts for this group, split however the caller likes.

     - Parameter minFee: The network's minimum fee, ``TransactionParams/minFee``.
     - Returns: `ceil(pooled usage * minFee / 1_000_000)`.
     - Throws: ``FeeError/overflow(_:)`` if the requirement does not fit.
     */
    public func requiredFee(minFee: MicroAlgos) throws -> MicroAlgos {
        try feeUsage().fee(minFee: minFee)
    }
}

extension SignedAtomicTransactionGroup {

    // MARK: - Fees

    /**
     The pooled usage of the envelopes, signatures included.

     - Returns: The sum of every member's ``SignedTransaction/feeUsage()``.
     - Throws: ``FeeError/overflow(_:)`` if the sum does not fit.
     */
    public func feeUsage() throws -> TransactionUsage {
        try signedTransactions.reduce(TransactionUsage.zero) { try $0.adding(try $1.feeUsage()) }
    }

    /**
     The smallest total fee the network accepts for this signed group.

     - Parameter minFee: The network's minimum fee, ``TransactionParams/minFee``.
     - Returns: `ceil(pooled usage * minFee / 1_000_000)`.
     - Throws: ``FeeError/overflow(_:)`` if the requirement does not fit.
     */
    public func requiredFee(minFee: MicroAlgos) throws -> MicroAlgos {
        try feeUsage().fee(minFee: minFee)
    }

    /**
     Makes the network's fee check before submission.

     A node reports a fee shortfall as an HTTP 200 `simulate` response with the verdict in
     `failure-message`, and rejects the group outright on submission; checking here turns that into
     a typed error with both numbers in it.

     - Parameter minFee: The network's minimum fee, ``TransactionParams/minFee``.
     - Returns: The required fee, for logging.
     - Throws: ``FeeError/insufficient(required:paid:)`` if the members' fees sum to less than the
       requirement, or ``FeeError/overflow(_:)`` if either total does not fit.
     */
    @discardableResult
    public func checkFees(minFee: MicroAlgos) throws -> MicroAlgos {
        let required = try requiredFee(minFee: minFee)

        var paid: UInt64 = 0
        for signed in signedTransactions {
            let (sum, overflow) = paid.addingReportingOverflow(signed.transaction.fee.value)
            guard !overflow else { throw FeeError.overflow("fees paid exceed UInt64") }
            paid = sum
        }

        guard paid >= required.value else {
            throw FeeError.insufficient(required: required, paid: MicroAlgos(paid))
        }
        return required
    }
}
