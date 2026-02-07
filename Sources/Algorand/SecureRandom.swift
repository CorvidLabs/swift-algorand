@preconcurrency import Foundation

#if canImport(Security)
import Security
#endif

#if canImport(Glibc)
import Glibc
#endif

/// Provides cryptographically secure random byte generation.
///
/// Uses platform-appropriate CSPRNGs:
/// - Apple platforms: `SecRandomCopyBytes` (Security framework)
/// - Linux: `/dev/urandom` (kernel CSPRNG)
enum SecureRandom {
    /// Generates cryptographically secure random bytes.
    ///
    /// - Parameter count: The number of random bytes to generate.
    /// - Returns: `Data` containing `count` cryptographically secure random bytes.
    /// - Throws: `AlgorandError.encodingError` if the platform CSPRNG fails.
    static func bytes(count: Int) throws -> Data {
        var data = Data(count: count)

        #if canImport(Security)
        // Apple platforms: use SecRandomCopyBytes (backed by the kernel CSPRNG)
        let status = data.withUnsafeMutableBytes { bufferPointer -> Int32 in
            guard let baseAddress = bufferPointer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, count, baseAddress)
        }
        guard status == errSecSuccess else {
            throw AlgorandError.encodingError(
                "SecRandomCopyBytes failed with status \(status)"
            )
        }
        #else
        // Linux / other platforms: read from /dev/urandom
        guard let fileHandle = FileHandle(forReadingAtPath: "/dev/urandom") else {
            throw AlgorandError.encodingError(
                "Failed to open /dev/urandom"
            )
        }
        defer { fileHandle.closeFile() }

        let randomData = fileHandle.readData(ofLength: count)
        guard randomData.count == count else {
            throw AlgorandError.encodingError(
                "Failed to read \(count) bytes from /dev/urandom (got \(randomData.count))"
            )
        }
        data = randomData
        #endif

        return data
    }
}
