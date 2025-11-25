# Contributing to swift-algorand

Thank you for your interest in contributing to swift-algorand! 🎉

## How to Contribute

### Reporting Issues

If you find a bug or have a feature request:

1. Check if the issue already exists in [GitHub Issues](https://github.com/CorvidLabs/swift-algorand/issues)
2. If not, create a new issue with:
   - A clear, descriptive title
   - Steps to reproduce (for bugs)
   - Expected vs. actual behavior
   - Swift version and platform information

### Submitting Pull Requests

1. **Fork the repository** and create your branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**:
   - Write clear, concise code following Swift conventions
   - Add tests for new functionality
   - Update documentation as needed

3. **Ensure tests pass**:
   ```bash
   # Run unit tests
   swift test --filter 'AccountTests|AddressTests|ApplicationTransactionTests|AssetManagementTests|AssetTests|AtomicTransactionGroupTests|KeyRegistrationTests|MicroAlgosTests|MnemonicTests'

   # Run integration tests (requires LocalNet)
   docker-compose up -d
   ALGORAND_NETWORK=localnet swift test
   docker-compose down
   ```

4. **Verify the build**:
   ```bash
   swift build
   ```

5. **Commit your changes**:
   - Use clear, descriptive commit messages
   - Reference any related issues

6. **Push to your fork** and submit a pull request

## Code Style

- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Add documentation comments for public APIs
- Keep functions focused and concise
- Use Swift 6 concurrency features (async/await, actors)

## Testing

- Write tests for new features
- Ensure existing tests pass
- Test on multiple platforms when possible (macOS, Linux)
- Use LocalNet for integration testing

## Documentation

- Update README.md if adding major features
- Add code examples for new functionality
- Document any breaking changes

## Questions?

Feel free to open an issue for questions or discussion!

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
