# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.0.x   | Yes       |
| < 1.0   | No        |

## Reporting a Vulnerability

Please report security vulnerabilities via GitHub Issues with the `security` label, or email the maintainer directly.

**Do not** open a public issue for vulnerabilities that could be exploited before a fix is available.

## Security Model

- **MCP server** validates all file paths stay within the repository (`os.path.realpath` + prefix check)
- **CLI** does not execute arbitrary code from config files (config values are passed to git, not eval'd)
- **Agent** LLM responses are used for analysis/reporting only, never executed as code
- **Hooks** are user-installed executables; pingo-light does not ship hooks that execute by default
- **Shallow clone** auto-unshallowing uses `git fetch --unshallow`, not custom network calls

## Known Security Considerations

- The `.pingolight` config file is excluded from git tracking via `.git/info/exclude`, preventing accidental commit of upstream URLs
- Patch descriptions set via `PINGO_DESCRIPTION` environment variable are sanitized through git commit message handling
- The `auto-sync` GitHub Actions workflow requires a `GITHUB_TOKEN` with write permissions
