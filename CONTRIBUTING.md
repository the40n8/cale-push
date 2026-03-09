# Contributing to cale-push

Thank you for your interest in contributing!

## Repository

**[github.com/the40n8/cale-push](https://github.com/the40n8/cale-push)**

## How to contribute

### Report a bug

1. Check if the bug has already been reported in [Issues](https://github.com/the40n8/cale-push/issues)
2. [Open a new issue](https://github.com/the40n8/cale-push/issues/new/choose) — a bug report template is provided, please fill it in completely

### Suggest an improvement

1. Open an issue to discuss the idea first
2. Wait for feedback before writing code

### Submit code

1. Fork the project on GitHub
2. Create a branch from `main`:

   ```bash
   git checkout -b feature/my-improvement
   ```

3. Follow the conventions below
4. Test locally with `./cale-push scan movies` and `./cale-push preview "file.mkv"`
5. Commit with a clear message
6. Push and open a **Pull Request** — a template is provided, please fill in the checklist

### Add a provider

Providers for new torrent clients are especially welcome:

1. Copy `providers/example.sh` to `providers/yourprovider.sh`
2. Implement `provider_check()` and `provider_add_torrent()`
3. Test with your client
4. Submit a PR

## Conventions

### Code

- **Language**: all code (variables, functions, comments) in **English**
- **Style**: follow existing style (4-space indent, `local` for variables)
- **Naming**: `snake_case` for functions/variables, `UPPER_CASE` for constants/config
- **Bash**: compatible with bash 4+, no non-portable bashisms

### Commits

```text
feat: add qbittorrent provider
fix: handle spaces in file paths
docs: update naming rules for series
refactor: split upload pipeline into smaller functions
```

### Documentation

- README and user docs in **French** (target audience is the La Cale community)
- Code comments in **English**

## AI-assisted development

Parts of this codebase were written with the help of [Claude Code](https://claude.ai/claude-code) — which is why a `CLAUDE.md` file exists at the root. It provides context to the AI about the project's architecture and conventions.

**AI assistance is not rejected** for contributions. If it helps you write better code, go for it.

That said, please follow these guidelines:

- **Understand what you submit.** If you used AI to generate code, read it, test it, and make sure you can explain every part of it. We will ask questions in review.
- **No vibe coding.** Do not paste a prompt, accept the output blindly, and open a PR. AI-generated code that ignores project conventions, adds unnecessary abstractions, or breaks shellcheck will be closed without merge.
- **Keep it minimal.** AI tends to over-engineer. Prefer the simplest solution that solves the problem — three lines over a new abstraction.
- **Test it.** `./cale-push check`, `./cale-push scan movies --dry-run`, `./cale-push preview "file.mkv"` — run them before submitting.

The goal is a maintainable, readable Bash codebase. AI is a tool, not a substitute for understanding the code.

## Maintainers

Maintainers are responsible for:

- Reviewing and merging PRs
- Managing releases and version tags
- Maintaining code quality

To become a maintainer, contribute regularly and reach out to the current team.

## Versioning

This project follows [Semantic Versioning](https://semver.org/):

- **MAJOR**: breaking changes (config format, API)
- **MINOR**: new backwards-compatible features
- **PATCH**: bug fixes

Releases are tagged with `v` prefix: `v3.0.0`, `v3.1.0`, etc.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
