# Contributing to pi-gateway-ansible

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers
- Focus on constructive feedback

## How to Contribute

### Reporting Bugs

1. Check [existing issues](https://github.com/Steve-M365/pi-gateway-ansible/issues)
2. If not found, create a new issue with:
   - Clear title
   - Steps to reproduce
   - Expected vs actual behavior
   - Pi model, OS version, Ansible version
   - Relevant logs (`make logs`, `docker logs <service>`)

### Suggesting Features

1. Open an issue with `[Feature]` prefix
2. Describe the use case
3. Explain why it fits the lightweight Pi4 constraint

### Submitting Changes

1. Fork the repo
2. Create a branch: `git checkout -b feature/my-feature`
3. Make changes and test:
   ```bash
   make bootstrap
   make deploy
   make review
   ```
4. Commit with clear message:
   ```bash
   git commit -m "Add feature: description"
   ```
5. Push to your fork
6. Open a Pull Request

## Development Setup

```bash
git clone https://github.com/Steve-M365/pi-gateway-ansible.git
cd pi-gateway-ansible
python3 -m venv venv
source venv/bin/activate
pip install ansible ansible-lint
```

## Style Guide

### Ansible
- Use `kebab-case` for role/task names
- Include comments for complex logic
- Always test idempotency (run twice, second run should report "ok")
- Use `when` clauses instead of `tags` for conditional tasks

### YAML
- 2-space indentation
- Quote strings with special characters
- Use `|` for multi-line strings

### Bash
- Use `set -euo pipefail`
- Quote variables: `"$VAR"`
- Use `[[` instead of `[`
- Run `shellcheck` before committing

### Documentation
- Update README.md if adding features
- Add entry to docs/ if creating new guide
- Include Pi4 memory/CPU impact for new services

## Review Process

1. CI must pass (ansible-lint, shellcheck)
2. Maintainer reviews code
3. Changes tested on Pi4 2GB
4. Merged to `main`

## Questions?

Open an issue or reach out to @Steve-M365 on GitHub.
