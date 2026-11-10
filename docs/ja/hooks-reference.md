# Hooksリファレンス

このドキュメントでは、shared-githooksが提供するすべてのhookの動作、
条件、設定方法を詳しく説明します。

## 概要

| Hookタイプ | スクリプト数 | 実行方式                      |
| ---------- | ------------ | ----------------------------- |
| pre-commit | 12           | 並列（`checks/`ディレクトリ） |
| commit-msg | 3            | 並列（`checks/`ディレクトリ） |

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

### check-large-files.sh — 大容量ファイル検査

ステージされたファイルがサイズ閾値を超えているかを検査します。

**デフォルト制限：** 1 MB（1048576バイト）

**設定方法：**

```bash
git config hooks.maxfilesize <bytes>
```

**動作方式：**

- ステージされたすべてのファイル（Added/Changed/Modified）のサイズを確認
- 閾値超過時にファイル名とサイズを表示し、コミットを中断
- 常に実行（スキップ条件なし）

---

### check-whitespace.sh — 空白エラー検査

trailing whitespace、space-before-tabなどの空白関連エラーを検出します。

**動作方式：**

- `git diff-index --check --cached`を使用してステージされた変更を検査
- 言語別フォーマッターが処理するファイルは除外
- `.gitattributes`で`binary`、`-text`、`eol=crlf`と指定されたファイルも除外

**除外ファイル拡張子：**

- `.go` — gofmtが処理
- `.py` — black/ruffなどが処理
- `.proto` — clang-formatが処理
- `.bzl`、`BUILD`、`BUILD.bazel`、`WORKSPACE` — buildifierが処理

**`.gitattributes`によるファイル単位の除外：**

改行コードや末尾空白をそのまま保持する必要があるファイル（HTTPフィクスチャ、
ゴールデンテストデータ、Windowsバッチスクリプトなど）の検査をスキップする
には、`.gitattributes`で指定します：

```gitattributes
# HTTPリクエスト/レスポンスフィクスチャはCRLF改行が必要
*.http        text eol=crlf
testdata/**   text eol=crlf

# バイナリブロブはテキスト検査の対象外
*.png         binary
*.bin         -text
```

`binary`、`-text`、`eol=crlf`のいずれかに一致するファイルはこのフックで
スキップされます。

---

### check-i18n-sync.sh — i18nドキュメント同期

多言語ドキュメントファイルがステージされる際、すべての言語バリアントが
一緒にステージされることを保証します。

**オプトイン：** このhookはデフォルトで無効です。

```bash
git config hooks.i18nsync true
```

**言語検出：**

- 追跡されている`README.<lang>.md`ファイルから言語を自動検出
- `README.<lang>.md`ファイルがなければ何もしない

**追跡ファイルグループ：**

- `README.md` ↔ `README.<lang>.md`（すべてのバリアントを一緒にステージする必要あり）
- `docs/*.md` ↔ `docs/<lang>/*.md`（翻訳対応ファイルが存在する場合のみ適用）

**スキップ条件：**

- `hooks.i18nsync`が`true`に設定されていない（デフォルト）
- リポジトリに`README.<lang>.md`ファイルが追跡されていない
- `docs/`ファイルに翻訳対応ファイルがない

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

### lint-python.sh — Pythonリント

Pythonプロジェクトで`ruff check`と`ruff format --check`を実行します。

**動作条件：**

- `ruff.toml`、`.ruff.toml`、または`pyproject.toml`の`[tool.ruff]`セクションが存在
- `ruff`コマンドがインストールされている

**スキップ条件：**

- ruff設定ファイルがない
- `ruff`がインストールされていない（警告メッセージ出力）
- Makefileの`check`ターゲットで既に`ruff`を実行している場合（重複防止）
- Bazelプロジェクトで`@multitool//tools/ruff`でruffを管理している場合

---

### lint-shell.sh — シェルスクリプトリント

ステージされた`.sh`ファイルに対して`shellcheck`を実行します。

**動作条件：**

- `shellcheck`コマンドがインストールされている
- ステージされた`.sh`ファイルが存在（Added/Changed/Modified）

**スキップ条件：**

- `shellcheck`がインストールされていない（警告メッセージ出力）
- ステージされた`.sh`ファイルがない
- Makefileの`check`ターゲットで既に`shellcheck`を実行している場合
  （重複防止）

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

### lint-semgrep.sh — Semgrep静的解析

Semgrep設定があるプロジェクトで`semgrep scan`を実行します。

**動作条件：**

- `.semgrep.yml`、`.semgrep.yaml`、または`.semgrep/`ディレクトリが存在
- `semgrep`コマンドがインストールされている

**スキップ条件：**

- Semgrep設定ファイル/ディレクトリがない
- `semgrep`がインストールされていない（警告メッセージ出力）
- Makefileの`check`ターゲットで既に`semgrep`を実行している場合
  （重複防止）

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

### check-workflow-actions.sh — 古いGitHub Actionsの検出

ステージされた`.github/workflows/*.yml`/`*.yaml`ファイルで、既知のアクションが
ハードコードされた最小メジャーバージョン未満である場合、または
`golangci/golangci-lint-action`の`version:`入力で`golangci-lint v1`が
ピン留めされている場合、コミットを拒否します。新しく生成された
ワークフローはしばしば古いタグ（`@v3`、`version: v1.x`）にデフォルト
設定されますが、このhookがコミット時に検出します。

**デフォルトで有効。** 無効化方法：

```bash
git config hooks.checkactions false
```

**動作条件：**

- ステージされたファイルに`.github/workflows/*.{yml,yaml}`が1つ以上存在

**スキップ条件：**

- ステージされたワークフローファイルがない
- `hooks.checkactions`が`false`に設定されている
- `uses:`参照がSHA（`@abc123...`）またはブランチ（`@main`）でピン留めされている
- 最小バージョン表にないアクション（未知のアクションは無視）

**強制される最小メジャーバージョン：**

| アクション                      | 最小 |
| ------------------------------- | ---- |
| `actions/checkout`              | v4   |
| `actions/setup-go`              | v5   |
| `actions/setup-node`            | v4   |
| `actions/setup-python`          | v5   |
| `actions/setup-java`            | v4   |
| `actions/setup-dotnet`          | v4   |
| `actions/cache`                 | v4   |
| `actions/upload-artifact`       | v4   |
| `actions/download-artifact`     | v4   |
| `actions/configure-pages`       | v5   |
| `actions/deploy-pages`          | v4   |
| `actions/upload-pages-artifact` | v3   |
| `golangci/golangci-lint-action` | v6   |
| `docker/build-push-action`      | v6   |
| `docker/login-action`           | v3   |
| `docker/setup-buildx-action`    | v3   |
| `docker/setup-qemu-action`      | v3   |
| `docker/metadata-action`        | v5   |
| `codecov/codecov-action`        | v4   |
| `softprops/action-gh-release`   | v2   |
| `github/codeql-action`          | v3   |

**golangci-lintバイナリバージョン：** `golangci/golangci-lint-action`
ステップ内部の`version:`入力はv2以上に解決される必要があります。
golangci-lint v2が互換性を破る設定変更を導入したため、v1.xのピン留めは
拒否されます。

最小バージョンを引き上げるには、`check-workflow-actions.sh`の`MIN_MAJOR`
を編集してください。

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

## Post-checkout Hooks

`git checkout`時および`git worktree add`後に実行されるhookです。
`.githooks/post-checkout/`の最上位に配置され、**順次** 実行されます。

### seed-worktree.sh — Worktreeファイルシード

追跡されていない／gitignoreされた個人ファイル（`.env`、`.bazelrc.user` など）
を、メイン作業ツリーからコピーまたはシンボリックリンクで新規作成のリンク
worktreeにシードします。マニフェストで駆動され、列挙したファイルのみをシード
し、gitignoreされたすべてのファイル（ビルド成果物、キャッシュ、シークレット
など）を無闇に取り込むことはありません。

**デフォルトのサイズ上限：** 1 MB（1048576 バイト）

**設定：**

```bash
git config hooks.worktreeseedmaxsize <bytes>
```

**動作タイミング：** 新規の*リンク*worktreeへの新規チェックアウト時のみ動作
します。hookは`$1=old-HEAD $2=new-HEAD $3=flag`を受け取り、次の条件をすべて
満たす場合のみ実行されます：

- `$3` == `1`（ファイルチェックアウトではなくブランチチェックアウト）、**かつ**
- `$1`がヌルOID（インプレースのブランチ切り替えではなく新規チェックアウト）、
  **かつ**
- `git rev-parse --absolute-git-dir`が解決された`--git-common-dir`と異なる
  （リンクworktreeであり、メインツリーの新規クローンもこれで除外される）、**かつ**
- `git rev-parse --show-superproject-working-tree`が空（サブモジュールでない）。

**マニフェスト形式** — 1行に1項目、`mode`の後にパスまたはグロブ；空行と`#`
コメントは無視されます：

```
# mode  path-or-glob
copy    .env
link    .bazelrc.user
copy    config/*.local.yaml
```

- `copy` — worktreeごとに独立したシード（例：worktreeごとに値を変えたい`.env`）。
- `link` — メインツリーのファイルへのシンボリックリンクで、すべてのworktreeが
  単一のソースを共有（例：`.bazelrc.user`）。

**マニフェストの場所**（両方が重ね合わされ、競合時は個人用が優先）：

- `<main-tree>/.git/worktree-seed` — 個人用・追跡なし（推奨）。
- `<main-tree>/.worktree-seed` — コミット済みのチーム共通デフォルト。

**動作：**

- メインツリーに存在し、かつ新しいworktreeには存在しない項目のみをシード
  （冪等、上書きしない）
- グロブはメインツリーを基準に展開
- シンボリックリンクのソース、ディレクトリ、サイズ上限を超えるファイルはスキップ
- メイン作業ツリーは`git worktree list --porcelain`の最初の項目から解決

**注意事項：**

- hookが有効である必要があり、CIやその他のhookを使わないチェックアウトには
  何も適用されない（CIはworktreeを作成しないため問題なし）
- `git worktree add --no-checkout`は`post-checkout`を発動させない
