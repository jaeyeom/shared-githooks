# 設定ガイド

このドキュメントでは、shared-githooksの高度な設定オプションを説明します。

## ネームスペース

`.githooks/.namespace`ファイルは、このsharedリポジトリのネームスペース
識別子を定義します。現在の値は`jaeyeom-shared-githooks`です。

利用（consuming）リポジトリでこのネームスペースを使用して、hooksを選択的に
無効化または実行できます：

```bash
# ネームスペースの特定のhookを実行
git hooks exec ns:jaeyeom-shared-githooks/pre-commit/checks/check.sh

# ネームスペース全体を無効化
# .githooks/.ignore.yaml
patterns:
  - "ns:jaeyeom-shared-githooks/**"
```

## Hookの無効化（.ignore.yaml）

特定のhookを無効にするには、利用リポジトリの`.githooks/.ignore.yaml`に
パターンを追加します：

```yaml
patterns:
  # 特定のhookを無効化
  - "pre-commit/checks/test-bazel.sh"

  # ディレクトリ単位の無効化
  - "pre-commit/checks/**"

  # ネームスペースベースの無効化
  - "ns:jaeyeom-shared-githooks/**"

  # ワイルドカードパターン
  - "**/experimental/**"
```

## 環境変数（.envs.yaml）

`.githooks/.envs.yaml`を通じて、hook実行時の環境変数を設定できます。

## Git設定による制御

一部のhookはGit設定値で動作を制御できます：

| 設定 | デフォルト | 説明 |
|------|----------|------|
| `hooks.allownonascii` | `false` | `true`に設定すると非ASCIIファイル名を許可 |

```bash
# 非ASCIIファイル名を許可
git config hooks.allownonascii true
```

## hookで使用可能な環境変数

Githooksがhook実行時に自動的に設定する環境変数です：

| 変数 | 説明 |
|------|------|
| `STAGED_FILES` | ステージされたファイルリスト（改行区切り、pre-commit専用） |
| `STAGED_FILES_FILE` | ステージされたファイルパスを含むファイルのパス（null区切り） |
| `GITHOOKS_OS` | オペレーティングシステム（`linux`、`darwin`、`windows`） |
| `GITHOOKS_ARCH` | アーキテクチャ（`amd64`、`arm64`） |
| `GITHOOKS_CONTAINER_RUN` | コンテナ内実行時に設定 |

## コンテナ化されたHook実行

hooksをDocker/Podmanコンテナ内で実行できます。

### イメージ定義（.images.yaml）

```yaml
# .githooks/.images.yaml
images:
  my-image:1.0:
    pull:
      reference: "registry/my-image:1.0"
  custom-tool:latest:
    build:
      dockerfile: ./docker/Dockerfile
      stage: final
      context: ./docker
```

### Hookでのイメージ参照

```yaml
# .githooks/pre-commit/containerized-check.yaml
version: 3
cmd: ./check.sh
image:
  reference: "my-image:1.0"
```

## YAML Hook設定

シェルスクリプトの代わりにYAMLでhookを定義できます：

```yaml
# .githooks/pre-commit/my-hook.yaml
version: 1
cmd: "path/to/executable"
args:
  - "--flag"
  - "${env:MY_VAR}"
  - "${git:some.config}"
```

### 変数置換パターン

| パターン | ソース |
|---------|--------|
| `${env:VAR}` | 環境変数 |
| `${git:VAR}` | Git設定（自動スコープ） |
| `${git-l:VAR}` | ローカルGit設定 |
| `${git-g:VAR}` | グローバルGit設定 |
| `${git-s:VAR}` | システムGit設定 |
| `${!env:VAR}` | 必須環境変数（ない場合は失敗） |

## 並列実行設定

hooksの実行方式を制御できます：

- **順次実行：** hookタイプディレクトリにスクリプトを直接配置
- **並列実行：** サブディレクトリにスクリプトをまとめて配置
- **全並列：** ディレクトリに`.all-parallel`マーカーファイルを作成

```
.githooks/pre-commit/
├── sequential-a.sh          # 順次実行（辞書順）
├── sequential-b.sh          # 順次実行（辞書順）
└── parallel-batch/          # 内部スクリプトは並列実行
    ├── check-a.sh
    └── check-b.sh
```
