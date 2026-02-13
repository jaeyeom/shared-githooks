# Hooksリファレンス

このドキュメントでは、shared-githooksが提供するすべてのhookの動作、
条件、設定方法を詳しく説明します。

## 概要

| Hookタイプ | スクリプト数 | 実行方式 |
|-----------|------------|---------|
| pre-commit | 6 | 並列（`checks/`ディレクトリ） |
| commit-msg | 3 | 並列（`checks/`ディレクトリ） |

すべてのhookスクリプトは`set -euo pipefail`で始まり、依存ツールがない場合は
静かにスキップします。

---

## Pre-commit Hooks

コミット前にコード品質を検証するhookです。
`.githooks/pre-commit/checks/`ディレクトリに配置され、**並列に** 実行されます。

### check.sh — Makefileベースのチェック

プロジェクトのMakefileに`check`ターゲットがあれば`make -j check`を
実行します。

**動作条件：**
- プロジェクトルートに`Makefile`が存在
- Makefileに`check:`ターゲットが定義されている

**スキップ条件：**
- `Makefile`がない
- `check:`ターゲットがない

**実行コマンド：** `make -j check`（並列ビルド）

---

### check-whitespace.sh — 空白エラー検査

trailing whitespace、space-before-tabなどの空白関連エラーを検出します。

**動作方式：**
- `git diff-index --check --cached`を使用してステージされた変更を検査
- 言語別フォーマッターが処理するファイルは除外

**除外ファイル拡張子：**
- `.go` — gofmtが処理
- `.py` — black/autopep8などが処理
- `.proto` — clang-formatが処理
- `.bzl`、`BUILD`、`BUILD.bazel`、`WORKSPACE` — buildifierが処理

---

### check-non-ascii.sh — 非ASCIIファイル名検査

新しく追加されるファイルの名前に非ASCII文字が含まれているかを検査します。
クロスプラットフォーム互換性のためのチェックです。

**無効化方法：**

```bash
git config hooks.allownonascii true
```

---

### lint-go.sh — Goリント

Goプロジェクトで`golangci-lint`を実行します。

**動作条件：**
- プロジェクトルートに`.golangci.yml`が存在
- `golangci-lint`コマンドがインストールされている

**スキップ条件：**
- `.golangci.yml`がない
- `golangci-lint`がインストールされていない（警告メッセージ出力）
- Makefileの`check`ターゲットで既に`golangci-lint`を実行している場合
  （重複防止）

**注意：** `GOPACKAGESDRIVER`環境変数を解除し、クリーンな実行環境を
保証します。

---

### lint-org.sh — Org-modeリント

ステージされた`.org`ファイルに対して`org-lint`を実行します。

**動作条件：**
- `org-lint`コマンドがインストールされている
- ステージされた`.org`ファイルが存在（Added/Changed/Modified）

**スキップ条件：**
- `org-lint`がインストールされていない（静かにスキップ）
- ステージされた`.org`ファイルがない

---

### test-bazel.sh — Bazelテスト

Bazelプロジェクトで変更の影響を受けるテストを実行します。

**動作条件：**
- プロジェクトルートに`BUILD`または`BUILD.bazel`が存在
- `bazel`コマンドがインストールされている

**スキップ条件：**
- `BUILD`/`BUILD.bazel`がない
- `bazel`がインストールされていない（警告メッセージ出力）
- Makefileの`check`ターゲットで既に`bazel test`を実行している場合
  （重複防止）

**スマートテスト選択：**
- `bazel-affected-tests`バイナリがあれば、変更の影響を受けるテストのみ
  選択的に実行
- なければ`bazel test //...:all`で全テストを実行

**フォーマットテストの特別処理：**
- `//tools/format:`テストが失敗した場合、自動的に`bazel run //:format`を
  実行してコードをフォーマットし、コミットを中断
- 開発者がフォーマットされたコードを確認後、再コミット可能

**プラットフォーム制限：**
- macOS（Darwin）ではフォーマットテスト以外のテストをスキップ

---

## Commit-msg Hooks

コミットメッセージの品質とポリシーを検証するhookです。
`.githooks/commit-msg/checks/`ディレクトリに配置され、**並列に** 実行されます。

### check-subject-length.sh — タイトル長制限

コミットメッセージの最初の行（タイトル）が72文字を超えないように
強制します。

**ルール：** タイトル行 <= 72文字

---

### check-co-authored-by.sh — Co-Authored-By拒否

コミットメッセージに`Co-Authored-By:`行が含まれている場合、コミットを
拒否します。

**検査パターン：** `^Co-Authored-By:`

---

### check-generated-comment.sh — AI生成マーカー拒否

コミットメッセージに`Generated with `文字列が含まれている場合、コミットを
拒否します。AIツールが自動的に追加する生成マーカーの削除を促します。

**検査パターン：** `Generated with `
