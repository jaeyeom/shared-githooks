# 시작하기

이 문서는 shared-githooks를 프로젝트에 도입하는 방법을 설명합니다.

## 사전 요구사항

- Git 2.x 이상
- [Githooks](https://github.com/gabyx/Githooks) 설치

### Githooks 설치

```bash
# macOS
brew install gabyx/githooks/githooks

# 또는 공식 설치 스크립트
curl -sL https://raw.githubusercontent.com/gabyx/Githooks/main/scripts/install.sh | bash
```

설치 후 초기화:

```bash
git hooks install
```

## 설정 방법

### 방법 1: 프로젝트별 설정 (권장)

프로젝트의 `.githooks/.shared.yaml` 파일에 추가합니다:

```yaml
urls:
  - "https://github.com/jaeyeom/shared-githooks.git@main"
```

이후 Githooks가 자동으로 이 저장소를 클론하고 hooks를 적용합니다.

### 방법 2: 글로벌 설정

모든 Git 저장소에 적용하려면:

```bash
git config --global githooks.shared "https://github.com/jaeyeom/shared-githooks.git@main"
```

### 방법 3: 로컬 저장소 설정

특정 저장소에만 적용하려면:

```bash
git config githooks.shared "https://github.com/jaeyeom/shared-githooks.git@main"
```

## 버전 고정

`@` 뒤에 브랜치, 태그 또는 커밋 SHA를 지정하여 버전을 고정할 수 있습니다:

```yaml
urls:
  # 브랜치 고정
  - "https://github.com/jaeyeom/shared-githooks.git@main"
  # 태그 고정
  - "https://github.com/jaeyeom/shared-githooks.git@v1.0.0"
  # 커밋 SHA 고정
  - "https://github.com/jaeyeom/shared-githooks.git@abc1234"
```

프로덕션 환경에서는 태그 또는 커밋 SHA로 고정하는 것을 권장합니다.

## 설정 확인

shared hooks가 올바르게 설정되었는지 확인합니다:

```bash
# 설치된 shared hooks 목록 확인
git hooks shared list

# shared hooks 수동 업데이트
git hooks shared update
```

## hooks 비활성화

특정 hook을 비활성화해야 하는 경우, 프로젝트의 `.githooks/.ignore.yaml`에
패턴을 추가합니다:

```yaml
patterns:
  # 특정 hook 비활성화
  - "pre-commit/checks/test-bazel.sh"
  # 네임스페이스 전체 비활성화
  - "ns:jaeyeom-shared-githooks/**"
```

## 다음 단계

- [Hooks 레퍼런스](hooks-reference.md) — 제공되는 모든 hook의 상세 설명
- [설정 가이드](configuration.md) — 고급 설정 옵션
- [개발 가이드](development.md) — hook 추가/수정 방법
