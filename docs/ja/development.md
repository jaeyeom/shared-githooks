# 開発ガイド

このドキュメントでは、shared-githooksに新しいhookを追加したり、既存のhookを
変更する方法を説明します。

## 開発環境セットアップ

### 必要なツールのインストール

```bash
brew install shfmt shellcheck yamllint biome
```

| ツール | 用途 |
|--------|------|
| shfmt | シェルスクリプトフォーマット |
| shellcheck | シェルスクリプト静的解析 |
| yamllint | YAMLファイルリント |
| biome | Markdown、JSONフォーマット |

### Makefileターゲット

```bash
make            # フォーマット + リント（ローカル開発用）
make check      # CI用チェック（ファイル変更なし）
make format     # すべてのファイルをフォーマット
make lint       # すべてのリンターを実行
make list       # 検出されたhookスクリプトの一覧
make help       # 利用可能なターゲットを表示
```

## Hookの追加

### 1. ディレクトリの作成

サポートされているGit hookイベント名で`.githooks/`の下にディレクトリを
作成します：

```bash
mkdir -p .githooks/pre-commit/checks
```

### 2. スクリプトの作成

```bash
#!/usr/bin/env bash
# Pre-commit: [hookの動作説明].
# [スキップ条件の説明].

set -euo pipefail

# 依存ツールの確認 — なければ静かにスキップ
if ! command -v my-tool &>/dev/null; then
  exit 0
fi

# メインロジック
echo "Running my check..."
if ! my-tool check; then
  echo >&2 "Check failed. Fix the reported issues, then commit again."
  exit 1
fi
```

### 3. 実行権限の付与

```bash
chmod +x .githooks/pre-commit/checks/my-check.sh
```

### 4. テスト

```bash
# 直接実行
.githooks/pre-commit/checks/my-check.sh

# Githooksを通じて実行
git hooks exec ns:jaeyeom-shared-githooks/pre-commit/checks/my-check.sh
```

## Hook作成ルール

### 必須事項

- `#!/usr/bin/env bash` shebangを使用（クロスプラットフォーム互換性）
- `set -euo pipefail` — 厳格なエラー処理
- ファイル先頭にコメントで目的とスキップ条件を明記
- スクリプトに実行権限（`chmod +x`）を付与

### グレースフルデグレデーション

すべてのhookは依存ツールがない場合、**失敗せずにスキップ** する必要が
あります：

```bash
# ツールがなければ静かにスキップ
if ! command -v my-tool &>/dev/null; then
  exit 0
fi
```

警告メッセージを出力したい場合：

```bash
if ! command -v my-tool &>/dev/null; then
  echo "Warning: my-tool not found, skipping check" >&2
  exit 0
fi
```

### 重複実行の防止

Makefileの`check`ターゲットで既に同じツールを実行している場合、hookが
重複実行されないようにします：

```bash
if [ -f Makefile ] \
  && grep -q '^check:' Makefile 2>/dev/null \
  && grep -q 'my-tool' Makefile 2>/dev/null; then
  echo "Skipping standalone check: Makefile has check target and mentions my-tool"
  exit 0
fi
```

### エラーメッセージ

失敗時に明確なエラーメッセージをstderrに出力します：

```bash
echo >&2 "Check failed. Fix the reported issues, then commit again."
exit 1
```

## ディレクトリ構造ルール

```
.githooks/<hook-type>/
├── script.sh              # 順次実行
└── checks/                # サブディレクトリ = 並列実行
    ├── check-a.sh
    └── check-b.sh
```

- hookタイプディレクトリに直接配置されたスクリプトは **辞書順で順次実行**
- サブディレクトリ（`checks/`など）内のスクリプトは **並列実行**
- ドット（`.`）で始まるファイルはhook探索から除外

## サポートされるHookタイプ

| Hook | 実行タイミング |
|------|--------------|
| `pre-commit` | コミット前 |
| `commit-msg` | コミットメッセージ作成後 |
| `post-commit` | コミット後 |
| `pre-push` | プッシュ前 |
| `post-checkout` | チェックアウト後 |
| `post-merge` | マージ後 |
| `pre-rebase` | リベース前 |
| `pre-merge-commit` | マージコミット前 |
| `post-rewrite` | 履歴書き換え後 |

## コード品質

コミット前に必ずフォーマットとリントを実行します：

```bash
make check
```

### shfmt設定

シェルスクリプトフォーマットルール：

- インデント：2スペース（`-i 2`）
- caseインデント：有効化（`-ci`）
- 二項演算子：改行前に配置（`-bn`）

### shellcheck

すべての`.sh`ファイルに対してshellcheckを実行し、潜在的なバグ、移植性の
問題、スタイルの問題を検出します。
