# shared-githooks

すべてのリポジトリのためのGit hooksセット。

**[English](README.md)** | **[한국어](README.ko.md)**

## なぜ使うべきか？

[Claude Code](https://docs.anthropic.com/en/docs/claude-code)で作業する際、コミットとプッシュを絶え間なく行います。ガードレールがなければ、不正なコミットがすり抜けます — フォーマットの崩れ、失敗するテスト、リント違反 — CIが失敗するかレビュアーが指摘するまで気付きません。

これらのhooksはセーフティネットです。一度グローバルに設定すれば、すべてのリポジトリのすべてのコミットが自動的にチェックされます。Claude Codeが`git commit`を実行すると、hooksが問題をキャッチし、自信を持って作業を続けられます。リポジトリごとの設定も、手動チェックも不要です。

## 概要

[Githooks](https://github.com/gabyx/Githooks)で管理されるグローバルインストール型Git hooksコレクションです。一度インストールすれば、すべてに適用されます。hooksはプロジェクトタイプを自動検出し、Makefile規約があればそれに従い、ツールがなければ静かにスキップします。リポジトリごとの設定は不要です。

hooksは **Makefile優先哲学** に従います：プロジェクトに`check`ターゲットのある`Makefile`があれば、`make -j check`を実行し、既存のビルドシステムに処理を任せます。これは`check`、`check-format`、`lint`、`test`ターゲットが標準化された[makefile-workflow](https://github.com/jaeyeom/claude-toolbox)規約と一致します。

このコレクションは時間とともにより多くの言語とツールチェーンをサポートするよう成長しますが、常にグローバルフレンドリーを維持します — 設定なしで動作する合理的なデフォルト値。

## クイックセットアップ

すべてのリポジトリにグローバルインストール：

```bash
# Githooksのインストール（必要な場合）
git hooks install

# shared hooksをグローバルに追加
git config --global githooks.shared "https://github.com/jaeyeom/shared-githooks.git@main"

# shared hooksの更新
git hooks shared update
```

または`.githooks/.shared.yaml`によるリポジトリごとの設定：

```yaml
urls:
  - "https://github.com/jaeyeom/shared-githooks.git@main"
```

## 動作原理

コミット時、hooksは以下のロジックに従って並列実行されます：

```
commit → pre-commit hooks（並列）→
  ├── check:ターゲットのあるMakefile？ → make -j check（すべてをカバー）
  ├── Makefile checkのないGoプロジェクト？ → golangci-lint
  ├── Makefile checkのないPythonプロジェクト？ → ruff check + format
  ├── ステージされたシェルスクリプト？ → shellcheck
  ├── Makefile checkのないBazelプロジェクト？ → 影響を受けるテスト
  ├── ステージされた.orgファイル？ → org-lint
  ├── Semgrep設定あり？ → semgrep scan
  ├── 大容量ファイルのステージ？ → 拒否（設定可能な制限）
  ├── 空白エラー？ → git diff --check
  └── 非ASCIIファイル名？ → 拒否（設定可能）

commit-msg hooks（並列）→
  ├── タイトル行 >72文字？ → 拒否
  ├── Co-Authored-By:行？ → 拒否
  └── AI生成マーカー？ → 拒否
```

核心は **委任パターン** です：Makefileにリンターを実行する`check`ターゲットがあれば、ツール固有のhooks（`lint-go.sh`など）が重複作業を避けるために自動的にスキップします。Makefileが`golangci-lint`に言及していればGo hookが委任します。`bazel test`に言及していればBazel hookが委任します。

Makefileがない場合、hooksはツールを直接実行します。ツールがインストールされていなければ、静かにスキップします。

## リポジトリの互換性確保

最適な体験のために、`check`ターゲットのある`Makefile`を追加してください：

```makefile
.PHONY: all check format check-format lint test

all: format lint test
check: check-format lint test   # CI安全、読み取り専用

check-format:
	# ファイル変更なしでフォーマットを検証

lint:
	# リンターを実行（例：golangci-lint、shellcheck、eslint）

test:
	# テストを実行
```

`check`ターゲットは **読み取り専用** （ファイル変更なし）で、`make -j`（並列実行）に安全である必要があります。hooksが`make check`を検出すると、ツール固有のチェックをMakefileに委任します。

言語別の詳細パターン（Go、Node.js、Bazel、混合スタック）は[makefile-workflow](https://github.com/jaeyeom/claude-toolbox)規約を参照してください。

## 含まれるHooks

### Pre-commit Hooks（すべて並列実行）

| Hook | 機能 | スキップ条件 |
|------|------|-------------|
| `check.sh` | `make -j check`を実行（可能な場合） | `check:`ターゲットのあるMakefileなし |
| `check-large-files.sh` | サイズ閾値を超えるステージファイルを拒否（デフォルト1 MB） | 常に実行；`git config hooks.maxfilesize <bytes>`で制限設定 |
| `check-whitespace.sh` | `git diff-index --check`でtrailing whitespaceと混合改行を検出 | 言語フォーマッターが処理するファイル（*.go、*.py、*.proto、*.bzl、BUILD*） |
| `check-i18n-sync.sh` | ドキュメントファイル変更時にすべての言語バリアントのステージが必要 | オプトイン：`git config hooks.i18nsync true`で有効化 |
| `check-non-ascii.sh` | 移植性のため非ASCIIファイル名を拒否 | `git config hooks.allownonascii true` |
| `lint-go.sh` | `golangci-lint run ./...`を実行 | `.golangci.yml`なし、ツール未インストール、またはMakefile `check:`ターゲットが`golangci-lint`に言及 |
| `lint-python.sh` | Pythonプロジェクトで`ruff check`と`ruff format --check`を実行 | ruff設定なし、ツール未インストール、Bazelが`@multitool`でruffを管理、またはMakefile `check:`ターゲットが`ruff`に言及 |
| `lint-shell.sh` | ステージされた`.sh`ファイルに`shellcheck`を実行 | ステージされた`.sh`ファイルなし、ツール未インストール、またはMakefile `check:`ターゲットが`shellcheck`に言及 |
| `lint-org.sh` | ステージされた`.org`ファイルに`org-lint`を実行 | ステージされた`.org`ファイルなし、ツール未インストール |
| `lint-semgrep.sh` | 静的解析のため`semgrep scan`を実行 | `.semgrep.yml`、`.semgrep.yaml`、`.semgrep/`ディレクトリなし；ツール未インストール；またはMakefile `check:`ターゲットが`semgrep`に言及 |
| `test-bazel.sh` | `bazel-affected-tests`で影響を受けるBazelテストを実行、フォーマットテスト自動修正 | `BUILD`/`BUILD.bazel`ファイルなし、`bazel`未インストール、またはMakefile `check:`ターゲットが`bazel test`に言及 |

### Commit-msg Hooks（すべて並列実行）

| Hook | 機能 | スキップ条件 |
|------|------|-------------|
| `check-subject-length.sh` | 72文字以下のタイトル行を強制 | 常に実行 |
| `check-co-authored-by.sh` | `Co-Authored-By:`行を拒否 | 常に実行 |
| `check-generated-comment.sh` | `Generated with `マーカー（AIツールアーティファクト）を拒否 | 常に実行 |

## 設定

| 設定 | 効果 |
|------|------|
| `git config hooks.allownonascii true` | 非ASCIIファイル名を許可 |
| `git config hooks.i18nsync true` | ドキュメント同期チェックを有効化（すべての言語バリアントのステージが必要） |
| `git config hooks.maxfilesize <bytes>` | 大容量ファイル閾値を設定（デフォルト：1048576 = 1 MB） |
| Makefile `check:`ターゲット | 存在時にツール固有のhooksを代替 |
| Makefileの`.NOTPARALLEL` | 並列`make -j`実行を無効化 |

## Hooksの無効化

Githooks ignoreパターンで特定のhooksを無効化：

```bash
# 特定のhookを無効化
git hooks ignore add --pattern "ns:jaeyeom-shared-githooks/pre-commit/checks/test-bazel.sh"

# すべてのBazelテストを無効化
git hooks ignore add --pattern "**/test-bazel.sh"
```

または`.githooks/.ignore.yaml`にパターンを追加：

```yaml
patterns:
  - "pre-commit/checks/test-bazel.sh"
```

## ドキュメント

| ドキュメント | 説明 |
|-------------|------|
| [はじめに](docs/ja/getting-started.md) | インストール、設定、バージョン固定 |
| [Hooksリファレンス](docs/ja/hooks-reference.md) | すべてのhookの詳細な動作と条件 |
| [設定ガイド](docs/ja/configuration.md) | ネームスペース、無効化、環境変数、コンテナ |
| [開発ガイド](docs/ja/development.md) | 新しいhookの追加、コーディング規約、テスト |

## 開発

開発ツールのインストール：

```bash
brew install shfmt shellcheck yamllint biome
```

フォーマットとチェックの実行：

```bash
make          # format + lint
make check    # CI用チェック（ファイル変更なし）
make help     # 利用可能なターゲットを表示
```

ディレクトリ構造、YAML hook設定、並列実行、コンテナ化などの完全な技術ドキュメントは[CLAUDE.md](CLAUDE.md)を参照してください。
