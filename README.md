# shared-githooks

Shared Git hooks repository for use with [Githooks](https://github.com/gabyx/Githooks).

## Usage

Add this repo to your project's `.githooks/.shared.yaml`:

```yaml
urls:
  - "https://github.com/jaeyeom/shared-githooks.git@main"
```

Or configure it globally:

```bash
git config --global githooks.shared "https://github.com/jaeyeom/shared-githooks.git@main"
```

## Development

Install tools:

```bash
brew install shfmt shellcheck yamllint biome
```

Run formatting and linting:

```bash
make          # format + lint
make check    # CI-friendly checks (no mutation)
make help     # show all targets
```

## Adding Hooks

Place executable scripts under `.githooks/<hook-type>/`:

```bash
mkdir -p .githooks/pre-commit
cat > .githooks/pre-commit/my-check.sh << 'EOF'
#!/usr/bin/env bash
echo "Running my check..."
EOF
chmod +x .githooks/pre-commit/my-check.sh
```

See [CLAUDE.md](CLAUDE.md) for full documentation on directory structure, YAML configs, parallel execution, and more.
