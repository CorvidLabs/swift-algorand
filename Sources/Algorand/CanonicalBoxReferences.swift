@preconcurrency import Foundation

/**
 Translates caller-facing box references, which name an application by its ID, into the wire form
 go-algorand expects, which names it by position.

 On the wire a `BoxRef`'s `i` is not an application ID. It is `0` for the application the transaction
 is calling, and otherwise a **one-based** index into the transaction's `apfa` foreign-application
 array. Writing the raw application ID there makes the node reject the reference outright:
 `tx.Boxes[0].Index is 600011882. Exceeds len(tx.ForeignApps)`.

 When a referenced application is absent from `apfa`, it is appended, because a box reference is only
 resolvable through that array.
 */
internal struct CanonicalBoxReferences {

    // MARK: - Nested Types

    /// One translated box reference, in the shape the wire encoding uses.
    internal struct Reference {
        /// `0` for the called application, otherwise the one-based position in `apfa`.
        internal let index: UInt64

        /// The box name, which may be empty.
        internal let name: Data
    }

    // MARK: - Properties

    /// The maximum number of foreign applications a transaction may carry, from consensus v28 onward.
    internal static let maximumForeignApplications = 8

    /// The translated references, in the order the caller supplied them.
    internal let references: [Reference]

    /// The foreign-application array, extended with any application a box reference needed.
    internal let foreignApplications: [UInt64]

    // MARK: - Initializers

    /**
     Translates box references against a transaction's called application and foreign applications.

     - Parameters:
       - boxes: The caller's `(applicationID, boxName)` pairs. An application ID of `0`, or the ID of
         the application being called, both mean "the current application".
       - applicationID: The application the transaction calls, or `0` when it creates one.
       - foreignApplications: The foreign applications the caller declared.
     - Throws: `AlgorandError.invalidTransaction` when a reference names an application that is not
       declared and cannot be added without exceeding the foreign-application limit.
     */
    internal init(
        boxes: [(UInt64, Data)],
        applicationID: UInt64,
        foreignApplications: [UInt64]
    ) throws {
        var applications = foreignApplications
        var translated: [Reference] = []
        translated.reserveCapacity(boxes.count)

        for (referencedApplicationID, name) in boxes {
            translated.append(
                Reference(
                    index: try Self.index(
                        of: referencedApplicationID,
                        applicationID: applicationID,
                        in: &applications
                    ),
                    name: name
                )
            )
        }

        self.references = translated
        self.foreignApplications = applications
    }

    // MARK: - Private Methods

    /// Resolves one referenced application to its wire index, extending `applications` if needed.
    private static func index(
        of referencedApplicationID: UInt64,
        applicationID: UInt64,
        in applications: inout [UInt64]
    ) throws -> UInt64 {
        guard referencedApplicationID != 0, referencedApplicationID != applicationID else {
            return 0
        }

        if let existing = applications.firstIndex(of: referencedApplicationID) {
            return UInt64(existing + 1)
        }

        guard applications.count < maximumForeignApplications else {
            throw AlgorandError.invalidTransaction(
                "Box reference names application \(referencedApplicationID), which is neither the "
                + "called application nor one of the \(applications.count) declared foreign "
                + "applications. It cannot be added because a transaction may declare at most "
                + "\(maximumForeignApplications) foreign applications."
            )
        }

        applications.append(referencedApplicationID)
        return UInt64(applications.count)
    }
}
