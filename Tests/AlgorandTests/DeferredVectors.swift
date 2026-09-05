import Foundation

/// Golden vectors recorded by the canonical-encoding change for behaviour that later changes make
/// live. Test files are exact-only delivery inputs of the change that wrote them, so a later change
/// adds its own suite and reads these constants instead of editing `CanonicalEncodingTests.swift`.
///
/// Provenance: generated from go-algorand v5.0.1-stable `msgp_gen.go` semantics and regenerated from
/// first principles; no AGPL-3.0 fixture was copied. Vectors listed by name only have their bytes in
/// the generator (`canonical-vectors.json`), not in this package. The post-quantum and rekeyed-`sgnr`
/// envelope vectors live, byte-exact, in the suite of the change that made them pass.
internal enum DeferredVectors {

    /// `pay_min_fee_from_params`: a payment built from suggested parameters whose `min-fee` is 2000
    /// must carry `fee: 2000`; today's builders hardcode 1000. Made live by the v42 fee-model change.
    internal static let payMinFeeFromParamsHex = "89a3616d74ce000f4240a3666565cd07d0a2667633a367656eac746573746e65742d76312e30a26768c4204863b518a4b3c84ec810f22d4f1081cb0f71f059a7ac20dec62f7f70e5093a22a26c76cd041ba3726376c4208485b1e921ad04a14459050fd1ebbbde38183318e8baf1961cf24638b6c2d9e0a3736e64c420d4eb7415bc02f185f032d40bd8e022605d7cbedbfef850793065291e151dc496a474797065a3706179"
    internal static let payMinFeeFromParamsTxID = "O3QXH5XHQDNATJZSH5QQ3BAVEATJGG6PTRZEDYT7TE6BTZSXUKPA"

    /// Vector names whose bytes are not transcribed into this package.
    internal static let namedOnly: [String] = [
        "appl_access_list_and_reject_version", "hb_heartbeat", "stpf_state_proof"
    ]
}
