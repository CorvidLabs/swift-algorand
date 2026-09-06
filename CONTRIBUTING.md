# Contributing to swift-algorand

Thank you for your interest in contributing to swift-algorand.

The package is pre-1.0. The API may still change between minor versions, so a well-argued
breaking change is welcome - just call it out in the pull request.

## How to Contribute

### Reporting Issues

If you find a bug or have a feature request:

1. Check if the issue already exists in [GitHub Issues](https://github.com/CorvidLabs/swift-algorand/issues)
2. If not, create a new issue with:
   - A clear, descriptive title
   - Steps to reproduce (for bugs)
   - Expected vs. actual behavior
   - Swift version and platform information

**Security vulnerabilities do not go in the issue tracker.** Report them privately through
[GitHub Private Vulnerability Reporting](https://github.com/CorvidLabs/swift-algorand/security/advisories/new).
See [SECURITY.md](SECURITY.md) for the policy and response times.

### Submitting Pull Requests

1. **Fork the repository** and create your branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**:
   - Follow the code style below
   - Add tests for new functionality
   - Update documentation as needed

3. **Ensure it builds and tests pass**:
   ```bash
   # The project's verification lane: build, then the suite with network tests gated off
   fledge run build
   fledge run test

   # Equivalent without fledge
   swift build
   CI=true swift test
   ```

   `CI=true swift test` executes 98 tests with 20 skipped and 0 failures. The 20 skipped
   are the integration suites, which need a local Algorand node.

4. **Optionally run only the offline tests** while iterating:
   ```bash
   swift test --skip IntegrationTest --skip ProofOfWorkTest
   ```
   That is 77 tests and needs no network and no Docker.

5. **Optionally run the integration tests** against a local node:
   ```bash
   ./scripts/start-localnet.sh
   ALGORAND_NETWORK=localnet swift test
   docker compose down
   ```
   `CI` must be unset for these to do anything, and the tests that submit transactions have
   extra environment requirements. Read [documentation/TESTING.md](documentation/TESTING.md)
   before treating a failure there as a regression.

6. **Commit your changes** with a clear message and a reference to any related issue.

7. **Push to your fork** and open a pull request.

## Code Style

This repository follows the CorvidLabs Swift conventions:

- Explicit access control on every declaration (`public`, `internal`, `private`)
- K&R braces - opening brace on the same line
- 4 spaces, never tabs; 120 column limit
- No force unwrapping: no `!`, no `try!`, no `as!` in library code
- `async`/`await` only - no completion handlers
- `Sendable` conformance on anything crossing a concurrency boundary
- Descriptive generic parameter names (`Value`, `Output`, `Key`), not `T` or `U`
- Documentation comments on every public API

The same rules apply to code samples in the documentation. A snippet in a Markdown file is
expected to compile against the current API as written, including the no-force-unwrap rule.

## Testing

- Write tests for new features
- Keep offline tests offline: anything that needs a node belongs in an integration suite
  gated on `ALGORAND_NETWORK` and `CI`, matching the existing pattern
- Test on macOS and Linux where you can

## Documentation

- Update README.md when adding or changing a public API
- Keep code samples runnable; do not document behaviour that no code implements
- Document breaking changes explicitly

## Spec Sync

Changes under `Sources/`, `Tests/`, `Package.swift`, `.github/`, and `specs/` are governed
by the repository's SpecSync workflow and need a change workspace. Run `fledge trust verify`
before calling such a change complete.

## Questions?

Feel free to open an issue for questions or discussion.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
