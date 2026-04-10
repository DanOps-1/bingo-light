# Contributing to bingo-light

Thanks for your interest in contributing! This guide covers everything you need to get started.

## Reporting Bugs

Open an issue using the **Bug Report** template. Include the bingo-light version, your OS, and steps to reproduce the problem.

## Submitting Changes

1. Fork the repository and create a feature branch from `main`.
2. Make your changes and add tests if applicable.
3. Run the test suite to confirm nothing is broken.
4. Open a pull request against `main` with a clear description of what you changed and why.

## Running Tests

```bash
make test
# or directly:
./tests/test.sh
```

## Code Style

- bingo-light is a single-file Bash tool. Keep it that way.
- All code must pass [ShellCheck](https://www.shellcheck.net/) with zero warnings.
- Use `snake_case` for variables and functions.
- Prefer clarity over cleverness.

## CLA

No Contributor License Agreement is required. By submitting a pull request you agree that your contribution is licensed under the MIT License.
