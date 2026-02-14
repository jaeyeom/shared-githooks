# はじめに

このドキュメントでは、shared-githooksをプロジェクトに導入する方法を
説明します。

## 前提条件

- Git 2.x以上
- [Githooks](https://github.com/gabyx/Githooks)のインストール

### Githooksのインストール

```bash
# macOS
brew install gabyx/githooks/githooks

# または公式インストールスクリプト
curl -sL https://raw.githubusercontent.com/gabyx/Githooks/main/scripts/install.sh | bash
```

インストール後の初期化：

```bash
git hooks install
```

## 設定方法

### 方法1：プロジェクトごとの設定（推奨）

プロジェクトの`.githooks/.shared.yaml`ファイルに追加します：

```yaml
urls:
  - "https://github.com/jaeyeom/shared-githooks.git@main"
```

その後、Githooksが自動的にこのリポジトリをクローンし、hooksを適用します。

### 方法2：グローバル設定

すべてのGitリポジトリに適用する場合：

```bash
git config --global githooks.shared "https://github.com/jaeyeom/shared-githooks.git@main"
```

### 方法3：ローカルリポジトリ設定

特定のリポジトリにのみ適用する場合：

```bash
git config githooks.shared "https://github.com/jaeyeom/shared-githooks.git@main"
```

## バージョン固定

`@`の後にブランチ、タグ、またはコミットSHAを指定してバージョンを
固定できます：

```yaml
urls:
  # ブランチ固定
  - "https://github.com/jaeyeom/shared-githooks.git@main"
  # タグ固定
  - "https://github.com/jaeyeom/shared-githooks.git@v1.0.0"
  # コミットSHA固定
  - "https://github.com/jaeyeom/shared-githooks.git@abc1234"
```

本番環境では、タグまたはコミットSHAでの固定を推奨します。

## 設定の確認

shared hooksが正しく設定されていることを確認します：

```bash
# インストールされたshared hooksの一覧を確認
git hooks shared list

# shared hooksの手動更新
git hooks shared update
```

## hooksの無効化

特定のhookを無効にする必要がある場合、プロジェクトの
`.githooks/.ignore.yaml`にパターンを追加します：

```yaml
patterns:
  # 特定のhookを無効化
  - "pre-commit/checks/test-bazel.sh"
  # ネームスペース全体を無効化
  - "ns:jaeyeom-shared-githooks/**"
```

## 次のステップ

- [Hooksリファレンス](hooks-reference.md) — すべてのhookの詳細説明
- [設定ガイド](configuration.md) — 高度な設定オプション
- [開発ガイド](development.md) — hookの追加・変更方法
