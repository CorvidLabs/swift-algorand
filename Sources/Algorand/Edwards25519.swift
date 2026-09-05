@preconcurrency import Foundation

/**
 The Edwards25519 point-decodability predicate that post-quantum address derivation depends on.

 Algorand derives a native post-quantum address by rejection sampling: it scans salts `0...255`
 ascending and keeps the first digest that is **not** decodable as an Edwards25519 point, so a PQ
 address can never collide with an address an Ed25519 key could produce.

 The predicate must match go-algorand's `crypto.IsEdwards25519Point` exactly, which is
 `filippo.io/edwards25519`'s `Point.SetBytes` succeeding. Two properties of that decoder are
 load-bearing:

 1. **Non-canonical encodings are accepted.** `SetBytes` masks bit 255 (the x sign bit) and reduces
    the remaining 255-bit little-endian integer modulo `p`; it never rejects a `y` at or above `p`.
 2. **Prime-order subgroup membership is not checked.** Small-order and torsion points are points.
    libsodium's `crypto_core_ed25519_is_valid_point` is stricter; using it picks a different salt
    and therefore derives a different address.

 The test, matching `SetBytes` followed by `field.Element.SqrtRatio`:

 ```
 y    = LE(encoded) with bit 255 cleared, reduced mod p
 u    = y² - 1
 v    = d·y² + 1
 root = u·v³·(u·v⁷)^((p-5)/8)
 point exists  <=>  v·root² == u  OR  v·root² == -u
 ```

 - Important: This arithmetic is not constant time. It is only ever applied to public values.
 */
internal enum Edwards25519 {

    // MARK: - Constants

    /// The length in bytes of an encoded Edwards25519 point.
    internal static let encodedPointSize = 32

    // MARK: - Internal Methods

    /**
     Reports whether 32 bytes decode to a point on the Edwards25519 curve under `SetBytes` rules.

     - Parameter encoded: The candidate encoding. Any length other than 32 returns `false`.
     - Returns: `true` if some curve point encodes to these bytes.
     */
    internal static func isPoint(_ encoded: Data) -> Bool {
        guard encoded.count == encodedPointSize else { return false }

        let y = FieldElement(maskedLittleEndianBytes: encoded)
        let ySquared = y.multiplied(by: y)

        // u = y² - 1, v = d·y² + 1
        let u = ySquared.subtracting(.one)
        let v = FieldElement.d.multiplied(by: ySquared).adding(.one)

        // root = u·v³·(u·v⁷)^((p-5)/8)
        let vSquared = v.multiplied(by: v)
        let vCubed = vSquared.multiplied(by: v)
        let vToTheSeventh = vCubed.multiplied(by: vCubed).multiplied(by: v)
        let candidate = u.multiplied(by: vToTheSeventh).raised(to: .squareRootExponent)
        let root = u.multiplied(by: vCubed).multiplied(by: candidate)

        // A point exists iff v·root² is u or -u.
        let check = v.multiplied(by: root).multiplied(by: root)
        return check == u || check == u.negated()
    }
}

// MARK: - Field Arithmetic

/**
 An element of GF(2^255 - 19), stored as four little-endian 64-bit limbs.

 Values are kept fully reduced into `[0, p)` after every operation, which keeps the equality test a
 plain limb comparison. Deliberately simple rather than fast: the salt scan performs a few hundred
 multiplications in the common case, and correctness here is a consensus concern.
 */
private struct FieldElement: Sendable, Equatable {

    // MARK: - Properties

    private var limb0: UInt64
    private var limb1: UInt64
    private var limb2: UInt64
    private var limb3: UInt64

    // MARK: - Constants

    /// Additive identity.
    fileprivate static let zero = FieldElement(0, 0, 0, 0)

    /// Multiplicative identity.
    fileprivate static let one = FieldElement(1, 0, 0, 0)

    /// p = 2^255 - 19.
    fileprivate static let modulus = FieldElement(
        0xFFFF_FFFF_FFFF_FFED,
        0xFFFF_FFFF_FFFF_FFFF,
        0xFFFF_FFFF_FFFF_FFFF,
        0x7FFF_FFFF_FFFF_FFFF
    )

    /// d = -121665 / 121666 mod p, the Edwards25519 curve constant.
    fileprivate static let d = FieldElement(
        0x75EB_4DCA_1359_78A3,
        0x0070_0A4D_4141_D8AB,
        0x8CC7_4079_7779_E898,
        0x5203_6CEE_2B6F_FE73
    )

    /// (p - 5) / 8 = 2^252 - 3, the exponent in the candidate square-root formula.
    fileprivate static let squareRootExponent = FieldElement(
        0xFFFF_FFFF_FFFF_FFFD,
        0xFFFF_FFFF_FFFF_FFFF,
        0xFFFF_FFFF_FFFF_FFFF,
        0x0FFF_FFFF_FFFF_FFFF
    )

    // MARK: - Initializers

    fileprivate init(_ limb0: UInt64, _ limb1: UInt64, _ limb2: UInt64, _ limb3: UInt64) {
        self.limb0 = limb0
        self.limb1 = limb1
        self.limb2 = limb2
        self.limb3 = limb3
    }

    /**
     Decodes 32 little-endian bytes, clearing bit 255 and reducing modulo p.

     This is exactly `field.Element.SetBytes`: the top bit is the x sign bit and carries no
     magnitude, and an unreduced `y` is silently reduced rather than rejected.

     - Parameter bytes: Exactly 32 bytes; callers range-check first.
     */
    fileprivate init(maskedLittleEndianBytes bytes: Data) {
        var values: (UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0)
        let base = bytes.startIndex

        for limbIndex in 0..<4 {
            var accumulated: UInt64 = 0
            for byteIndex in 0..<8 {
                let offset = base + limbIndex * 8 + byteIndex
                guard offset < bytes.endIndex else { continue }
                accumulated |= UInt64(bytes[offset]) << UInt64(byteIndex * 8)
            }
            switch limbIndex {
            case 0: values.0 = accumulated
            case 1: values.1 = accumulated
            case 2: values.2 = accumulated
            default: values.3 = accumulated
            }
        }

        // Clear bit 255: it encodes the sign of x and never contributes to y.
        values.3 &= 0x7FFF_FFFF_FFFF_FFFF

        self.init(values.0, values.1, values.2, values.3)
        reduceFully()
    }

    // MARK: - Subscript

    fileprivate subscript(index: Int) -> UInt64 {
        get {
            switch index {
            case 0: return limb0
            case 1: return limb1
            case 2: return limb2
            default: return limb3
            }
        }
        set {
            switch index {
            case 0: limb0 = newValue
            case 1: limb1 = newValue
            case 2: limb2 = newValue
            default: limb3 = newValue
            }
        }
    }

    // MARK: - Arithmetic

    /// Returns `self + other` modulo p.
    fileprivate func adding(_ other: FieldElement) -> FieldElement {
        var result = FieldElement.zero
        var carry: UInt64 = 0

        for index in 0..<4 {
            let (partial, overflowedOnValue) = self[index].addingReportingOverflow(other[index])
            let (total, overflowedOnCarry) = partial.addingReportingOverflow(carry)
            result[index] = total
            carry = (overflowedOnValue ? 1 : 0) &+ (overflowedOnCarry ? 1 : 0)
        }

        // Both operands are below p < 2^255, so the sum never leaves four limbs.
        result.reduceFully()
        return result
    }

    /// Returns `self - other` modulo p.
    fileprivate func subtracting(_ other: FieldElement) -> FieldElement {
        adding(other.negated())
    }

    /// Returns `-self` modulo p.
    fileprivate func negated() -> FieldElement {
        var result = FieldElement.zero
        var borrow: UInt64 = 0

        for index in 0..<4 {
            let (partial, borrowedOnValue) = FieldElement.modulus[index].subtractingReportingOverflow(self[index])
            let (total, borrowedOnBorrow) = partial.subtractingReportingOverflow(borrow)
            result[index] = total
            borrow = (borrowedOnValue ? 1 : 0) &+ (borrowedOnBorrow ? 1 : 0)
        }

        // p - 0 == p, which reduces back to zero.
        result.reduceFully()
        return result
    }

    /// Returns `self * other` modulo p.
    fileprivate func multiplied(by other: FieldElement) -> FieldElement {
        // Schoolbook 4x4 -> 8 limbs.
        var product = [UInt64](repeating: 0, count: 8)

        for i in 0..<4 {
            var carry: UInt64 = 0
            for j in 0..<4 {
                // product[i + j] + self[i] * other[j] + carry always fits in 128 bits,
                // so the new carry never overflows a single limb.
                let (high, low) = self[i].multipliedFullWidth(by: other[j])
                var upper = high

                let (partial, overflowedOnLow) = product[i + j].addingReportingOverflow(low)
                if overflowedOnLow {
                    upper &+= 1
                }
                let (total, overflowedOnCarry) = partial.addingReportingOverflow(carry)
                if overflowedOnCarry {
                    upper &+= 1
                }

                product[i + j] = total
                carry = upper
            }

            var index = i + 4
            while carry != 0 && index < 8 {
                let (total, overflowed) = product[index].addingReportingOverflow(carry)
                product[index] = total
                carry = overflowed ? 1 : 0
                index += 1
            }
        }

        return FieldElement(foldingWideProduct: product)
    }

    /**
     Returns `self` raised to `exponent` modulo p, most-significant-bit-first square-and-multiply.

     The exponent is public (always `(p-5)/8`), so the data-dependent branch is acceptable here.
     */
    fileprivate func raised(to exponent: FieldElement) -> FieldElement {
        var result = FieldElement.one
        var bit = 255

        while bit >= 0 {
            result = result.multiplied(by: result)
            let limb = exponent[bit / 64]
            if (limb >> UInt64(bit % 64)) & 1 == 1 {
                result = result.multiplied(by: self)
            }
            bit -= 1
        }

        return result
    }

    // MARK: - Private Methods

    /**
     Reduces an eight-limb product modulo p.

     Uses `2^256 ≡ 38 (mod p)`: fold the high half in with a multiply-by-38, then fold any remaining
     overflow the same way until it settles, then subtract p while possible.
     */
    private init(foldingWideProduct product: [UInt64]) {
        var low = FieldElement(product[0], product[1], product[2], product[3])
        var carry: UInt64 = 0

        // low += 38 * high
        for index in 0..<4 {
            let (high, lowPart) = product[index + 4].multipliedFullWidth(by: 38)
            var upper = high

            let (partial, overflowedOnLow) = low[index].addingReportingOverflow(lowPart)
            if overflowedOnLow {
                upper &+= 1
            }
            let (total, overflowedOnCarry) = partial.addingReportingOverflow(carry)
            if overflowedOnCarry {
                upper &+= 1
            }

            low[index] = total
            carry = upper
        }

        // Anything that spilled past limb 3 is worth 2^256 each, i.e. 38 each.
        var spill = carry
        while spill != 0 {
            let addend = spill &* 38
            var propagate = addend
            var index = 0
            while propagate != 0 && index < 4 {
                let (total, overflowed) = low[index].addingReportingOverflow(propagate)
                low[index] = total
                propagate = overflowed ? 1 : 0
                index += 1
            }
            spill = propagate
        }

        low.reduceFully()
        self = low
    }

    /// Subtracts p until the value is below p. At most two iterations for any four-limb input.
    private mutating func reduceFully() {
        while isGreaterThanOrEqualToModulus() {
            subtractModulus()
        }
    }

    private func isGreaterThanOrEqualToModulus() -> Bool {
        var index = 3
        while index >= 0 {
            if self[index] != FieldElement.modulus[index] {
                return self[index] > FieldElement.modulus[index]
            }
            index -= 1
        }
        return true
    }

    private mutating func subtractModulus() {
        var borrow: UInt64 = 0
        for index in 0..<4 {
            let (partial, borrowedOnValue) = self[index].subtractingReportingOverflow(FieldElement.modulus[index])
            let (total, borrowedOnBorrow) = partial.subtractingReportingOverflow(borrow)
            self[index] = total
            borrow = (borrowedOnValue ? 1 : 0) &+ (borrowedOnBorrow ? 1 : 0)
        }
    }
}
