# 개발 가이드

이 문서는 shared-githooks에 새로운 hook을 추가하거나 기존 hook을 수정하는
방법을 설명합니다.

## 개발 환경 설정

### 필수 도구 설치

```bash
brew install shfmt shellcheck yamllint biome
```

| 도구 | 용도 |
|------|-----|
| shfmt | 셸 스크립트 포매팅 |
| shellcheck | 셸 스크립트 정적 분석 |
| yamllint | YAML 파일 린트 |
| biome | Markdown, JSON 포매팅 |

### Makefile 타겟

```bash
make            # 포맷 + 린트 (로컬 개발용)
make check      # CI용 검사 (파일 변경 없음)
make format     # 모든 파일 포매팅
make lint       # 모든 린터 실행
make list       # 발견된 hook 스크립트 목록
make help       # 사용 가능한 타겟 표시
```

## Hook 추가하기

### 1. 디렉토리 생성

지원되는 Git hook 이벤트 이름으로 `.githooks/` 아래에 디렉토리를 만듭니다:

```bash
mkdir -p .githooks/pre-commit/checks
```

### 2. 스크립트 작성

```bash
#!/usr/bin/env bash
# Pre-commit: [hook이 하는 일에 대한 설명].
# [건너뛰는 조건 설명].

set -euo pipefail

# 의존 도구 확인 — 없으면 조용히 건너뜀
if ! command -v my-tool &>/dev/null; then
  exit 0
fi

# 메인 로직
echo "Running my check..."
if ! my-tool check; then
  echo >&2 "Check failed. Fix the reported issues, then commit again."
  exit 1
fi
```

### 3. 실행 권한 부여

```bash
chmod +x .githooks/pre-commit/checks/my-check.sh
```

### 4. 테스트

```bash
# 직접 실행
.githooks/pre-commit/checks/my-check.sh

# Githooks를 통해 실행
git hooks exec ns:jaeyeom-shared-githooks/pre-commit/checks/my-check.sh
```

## Hook 작성 규칙

### 필수 사항

- `#!/usr/bin/env bash` shebang 사용 (크로스 플랫폼 호환성)
- `set -euo pipefail` — 엄격한 에러 처리
- 파일 상단에 주석으로 목적과 건너뛰는 조건 명시
- 스크립트에 실행 권한 (`chmod +x`) 부여

### 그레이스풀 디그레이데이션

모든 hook은 의존 도구가 없을 때 **실패하지 않고 건너뛰어야** 합니다:

```bash
# 도구가 없으면 조용히 건너뜀
if ! command -v my-tool &>/dev/null; then
  exit 0
fi
```

경고 메시지를 출력하고 싶다면:

```bash
if ! command -v my-tool &>/dev/null; then
  echo "Warning: my-tool not found, skipping check" >&2
  exit 0
fi
```

### 중복 실행 방지

Makefile의 `check` 타겟에서 이미 같은 도구를 실행하는 경우, hook이 중복
실행되지 않도록 합니다:

```bash
if [ -f Makefile ] \
  && grep -q '^check:' Makefile 2>/dev/null \
  && grep -q 'my-tool' Makefile 2>/dev/null; then
  echo "Skipping standalone check: Makefile has check target and mentions my-tool"
  exit 0
fi
```

### 에러 메시지

실패 시 명확한 에러 메시지를 stderr로 출력합니다:

```bash
echo >&2 "Check failed. Fix the reported issues, then commit again."
exit 1
```

## 디렉토리 구조 규칙

```
.githooks/<hook-type>/
├── script.sh              # 순차 실행
└── checks/                # 하위 디렉토리 = 병렬 실행
    ├── check-a.sh
    └── check-b.sh
```

- Hook 타입 디렉토리에 직접 배치된 스크립트는 **사전순으로 순차 실행**
- 하위 디렉토리(`checks/` 등) 내부의 스크립트는 **병렬 실행**
- 점(`.`)으로 시작하는 파일은 hook 탐색에서 제외

## 지원되는 Hook 타입

| Hook | 실행 시점 |
|------|----------|
| `pre-commit` | 커밋 전 |
| `commit-msg` | 커밋 메시지 작성 후 |
| `post-commit` | 커밋 후 |
| `pre-push` | 푸시 전 |
| `post-checkout` | 체크아웃 후 |
| `post-merge` | 머지 후 |
| `pre-rebase` | 리베이스 전 |
| `pre-merge-commit` | 머지 커밋 전 |
| `post-rewrite` | 히스토리 재작성 후 |

## 코드 품질

커밋 전에 반드시 포맷과 린트를 실행합니다:

```bash
make check
```

### shfmt 설정

셸 스크립트 포매팅 규칙:

- 들여쓰기: 2칸 스페이스 (`-i 2`)
- case 들여쓰기: 활성화 (`-ci`)
- 이항 연산자: 줄바꿈 전 배치 (`-bn`)

### shellcheck

모든 `.sh` 파일에 대해 shellcheck를 실행하여 잠재적 버그, 이식성 문제,
스타일 문제를 검출합니다.
