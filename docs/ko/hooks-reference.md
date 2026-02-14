# Hooks 레퍼런스

이 문서는 shared-githooks에서 제공하는 모든 hook의 동작, 조건, 설정 방법을
상세히 설명합니다.

## 개요

| Hook 타입 | 스크립트 수 | 실행 방식 |
|-----------|------------|----------|
| pre-commit | 10 | 병렬 (`checks/` 디렉토리) |
| commit-msg | 3 | 병렬 (`checks/` 디렉토리) |

모든 hook 스크립트는 `set -euo pipefail`로 시작하며, 의존 도구가 없을 경우
조용히 건너뜁니다.

---

## Pre-commit Hooks

커밋 전에 코드 품질을 검증하는 hook들입니다. `.githooks/pre-commit/checks/`
디렉토리에 위치하여 **병렬로** 실행됩니다.

### check.sh — Makefile 기반 검사

프로젝트의 Makefile에 `check` 타겟이 있으면 `make -j check`을 실행합니다.

**동작 조건:**
- 프로젝트 루트에 `Makefile`이 존재
- Makefile에 `check:` 타겟이 정의되어 있음

**건너뛰는 조건:**
- `Makefile`이 없음
- `check:` 타겟이 없음

**실행 명령:** `make -j check` (병렬 빌드)

---

### check-large-files.sh — 대용량 파일 검사

스테이징된 파일이 크기 임계값을 초과하는지 검사합니다.

**기본 제한:** 1 MB (1048576 바이트)

**설정 방법:**

```bash
git config hooks.maxfilesize <bytes>
```

**동작 방식:**
- 스테이징된 모든 파일(Added/Changed/Modified)의 크기를 확인
- 임계값 초과 시 파일명과 크기를 표시하고 커밋을 중단
- 항상 실행됨 (건너뛰는 조건 없음)

---

### check-whitespace.sh — 공백 오류 검사

trailing whitespace, space-before-tab 등 공백 관련 오류를 검출합니다.

**동작 방식:**
- `git diff-index --check --cached`를 사용하여 스테이징된 변경사항 검사
- 언어별 포매터가 처리하는 파일은 제외

**제외 파일 확장자:**
- `.go` — gofmt가 처리
- `.py` — black/ruff 등이 처리
- `.proto` — clang-format이 처리
- `.bzl`, `BUILD`, `BUILD.bazel`, `WORKSPACE` — buildifier가 처리

---

### check-non-ascii.sh — 비ASCII 파일명 검사

새로 추가되는 파일의 이름에 비ASCII 문자가 포함되어 있는지 검사합니다.
크로스 플랫폼 호환성을 위한 검사입니다.

**비활성화 방법:**

```bash
git config hooks.allownonascii true
```

---

### lint-go.sh — Go 린트

Go 프로젝트에서 `golangci-lint`를 실행합니다.

**동작 조건:**
- 프로젝트 루트에 `.golangci.yml`이 존재
- `golangci-lint` 명령이 설치되어 있음

**건너뛰는 조건:**
- `.golangci.yml`이 없음
- `golangci-lint`가 설치되지 않음 (경고 메시지 출력)
- Makefile의 `check` 타겟에서 이미 `golangci-lint`를 실행하는 경우 (중복 방지)

**참고:** `GOPACKAGESDRIVER` 환경변수를 해제하여 깨끗한 실행 환경을
보장합니다.

---

### lint-python.sh — Python 린트

Python 프로젝트에서 `ruff check`과 `ruff format --check`을 실행합니다.

**동작 조건:**
- `ruff.toml`, `.ruff.toml`, 또는 `pyproject.toml`에 `[tool.ruff]` 섹션이 존재
- `ruff` 명령이 설치되어 있음

**건너뛰는 조건:**
- ruff 설정 파일이 없음
- `ruff`가 설치되지 않음 (경고 메시지 출력)
- Makefile의 `check` 타겟에서 이미 `ruff`를 실행하는 경우 (중복 방지)
- Bazel 프로젝트에서 `@multitool//tools/ruff`로 ruff를 관리하는 경우

---

### lint-shell.sh — 셸 스크립트 린트

스테이징된 `.sh` 파일에 대해 `shellcheck`를 실행합니다.

**동작 조건:**
- `shellcheck` 명령이 설치되어 있음
- 스테이징된 `.sh` 파일이 존재 (Added/Changed/Modified)

**건너뛰는 조건:**
- `shellcheck`가 설치되지 않음 (경고 메시지 출력)
- 스테이징된 `.sh` 파일이 없음
- Makefile의 `check` 타겟에서 이미 `shellcheck`를 실행하는 경우 (중복 방지)

---

### lint-org.sh — Org-mode 린트

스테이징된 `.org` 파일에 대해 `org-lint`를 실행합니다.

**동작 조건:**
- `org-lint` 명령이 설치되어 있음
- 스테이징된 `.org` 파일이 존재 (Added/Changed/Modified)

**건너뛰는 조건:**
- `org-lint`가 설치되지 않음 (조용히 건너뜀)
- 스테이징된 `.org` 파일이 없음

---

### lint-semgrep.sh — Semgrep 정적 분석

Semgrep 설정이 있는 프로젝트에서 `semgrep scan`을 실행합니다.

**동작 조건:**
- `.semgrep.yml`, `.semgrep.yaml`, 또는 `.semgrep/` 디렉토리가 존재
- `semgrep` 명령이 설치되어 있음

**건너뛰는 조건:**
- Semgrep 설정 파일/디렉토리가 없음
- `semgrep`가 설치되지 않음 (경고 메시지 출력)
- Makefile의 `check` 타겟에서 이미 `semgrep`를 실행하는 경우 (중복 방지)

---

### test-bazel.sh — Bazel 테스트

Bazel 프로젝트에서 변경에 영향받는 테스트를 실행합니다.

**동작 조건:**
- 프로젝트 루트에 `BUILD` 또는 `BUILD.bazel`이 존재
- `bazel` 명령이 설치되어 있음

**건너뛰는 조건:**
- `BUILD`/`BUILD.bazel`이 없음
- `bazel`이 설치되지 않음 (경고 메시지 출력)
- Makefile의 `check` 타겟에서 이미 `bazel test`를 실행하는 경우 (중복 방지)

**스마트 테스트 선택:**
- `bazel-affected-tests` 바이너리가 있으면 변경에 영향받는 테스트만 선택적 실행
- 없으면 `bazel test //...:all`로 전체 테스트 실행

**포맷 테스트 특별 처리:**
- `//tools/format:` 테스트가 실패하면 자동으로 `bazel run //:format`을
  실행하여 코드를 포맷팅한 뒤 커밋을 중단
- 개발자가 포맷팅된 코드를 확인 후 다시 커밋 가능

**플랫폼 제한:**
- macOS(Darwin)에서는 포맷 테스트 외의 테스트를 건너뜀

---

## Commit-msg Hooks

커밋 메시지의 품질과 정책을 검증하는 hook들입니다.
`.githooks/commit-msg/checks/` 디렉토리에 위치하여 **병렬로** 실행됩니다.

### check-subject-length.sh — 제목 길이 제한

커밋 메시지의 첫 번째 줄(제목)이 72자를 초과하지 않도록 강제합니다.

**규칙:** 제목 줄 <= 72자

---

### check-co-authored-by.sh — Co-Authored-By 거부

커밋 메시지에 `Co-Authored-By:` 줄이 포함되어 있으면 커밋을 거부합니다.

**검사 패턴:** `^Co-Authored-By:`

---

### check-generated-comment.sh — AI 생성 마커 거부

커밋 메시지에 `Generated with ` 문자열이 포함되어 있으면 커밋을 거부합니다.
AI 도구가 자동으로 추가하는 생성 마커를 제거하도록 유도합니다.

**검사 패턴:** `Generated with `
