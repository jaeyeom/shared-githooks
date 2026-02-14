# shared-githooks

모든 저장소를 위한 하나의 Git hooks 세트.

**[English](README.md)** | **[日本語](README.ja.md)**

## 왜 사용해야 하나요?

[Claude Code](https://docs.anthropic.com/en/docs/claude-code)로 작업할 때는 커밋과 푸시를 끊임없이 합니다. 안전장치가 없으면 잘못된 커밋이 빠져나갑니다 — 깨진 포매팅, 실패하는 테스트, 린트 위반 — CI가 실패하거나 리뷰어가 잡아낼 때까지 알아채지 못합니다.

이 hooks는 안전망입니다. 한 번 글로벌로 설정하면, 모든 저장소의 모든 커밋이 자동으로 검사됩니다. Claude Code가 `git commit`을 실행하면 hooks가 문제를 잡아내고, 안심하고 작업을 이어갈 수 있습니다. 저장소별 설정도, 수동 검사도 필요 없습니다.

## 개요

[Githooks](https://github.com/gabyx/Githooks)로 관리되는 글로벌 설치형 Git hooks 모음입니다. 한 번 설치하면 모든 곳에 적용됩니다. hooks는 프로젝트 타입을 자동 감지하고, Makefile 규칙이 있으면 이를 따르며, 도구가 없으면 조용히 건너뜁니다. 저장소별 설정이 필요 없습니다.

hooks는 **Makefile 우선 철학** 을 따릅니다: 프로젝트에 `check` 타겟이 있는 `Makefile`이 있으면 `make -j check`을 실행하고 기존 빌드 시스템이 처리하도록 맡깁니다. 이는 `check`, `check-format`, `lint`, `test` 타겟이 표준화된 [makefile-workflow](https://github.com/jaeyeom/claude-toolbox) 규칙과 일치합니다.

이 모음은 시간이 지남에 따라 더 많은 언어와 도구 체인을 지원하도록 성장하지만, 항상 글로벌 친화적으로 유지됩니다 — 설정 없이 작동하는 합리적인 기본값.

## 빠른 설정

모든 저장소에 글로벌로 설치:

```bash
# Githooks 설치 (필요한 경우)
git hooks install

# shared hooks를 글로벌로 추가
git config --global githooks.shared "https://github.com/jaeyeom/shared-githooks.git@main"

# shared hooks 업데이트
git hooks shared update
```

또는 `.githooks/.shared.yaml`을 통한 저장소별 설정:

```yaml
urls:
  - "https://github.com/jaeyeom/shared-githooks.git@main"
```

## 작동 원리

커밋 시 hooks가 다음 로직에 따라 병렬로 실행됩니다:

```
commit → pre-commit hooks (병렬) →
  ├── check: 타겟이 있는 Makefile? → make -j check (모든 것을 처리)
  ├── Makefile check 없는 Go 프로젝트? → golangci-lint
  ├── Makefile check 없는 Python 프로젝트? → ruff check + format
  ├── 스테이징된 셸 스크립트? → shellcheck
  ├── Makefile check 없는 Bazel 프로젝트? → 영향받는 테스트
  ├── 스테이징된 .org 파일? → org-lint
  ├── Semgrep 설정 존재? → semgrep scan
  ├── 대용량 파일 스테이징? → 거부 (설정 가능한 제한)
  ├── 공백 오류? → git diff --check
  └── 비ASCII 파일명? → 거부 (설정 가능)

commit-msg hooks (병렬) →
  ├── 제목 줄 >72자? → 거부
  ├── Co-Authored-By: 줄? → 거부
  └── AI 생성 마커? → 거부
```

핵심은 **위임 패턴** 입니다: Makefile에 린터를 실행하는 `check` 타겟이 있으면, 도구별 hooks(`lint-go.sh` 등)가 중복 작업을 피하기 위해 자동으로 건너뜁니다. Makefile이 `golangci-lint`를 언급하면 Go hook이 위임합니다. `bazel test`를 언급하면 Bazel hook이 위임합니다.

Makefile이 없으면 hooks가 도구를 직접 실행합니다. 도구가 설치되지 않았으면 조용히 건너뜁니다.

## 저장소 호환성 확보

최적의 경험을 위해 `check` 타겟이 있는 `Makefile`을 추가하세요:

```makefile
.PHONY: all check format check-format lint test

all: format lint test
check: check-format lint test   # CI 안전, 읽기 전용

check-format:
	# 파일 변경 없이 포매팅 검증

lint:
	# 린터 실행 (예: golangci-lint, shellcheck, eslint)

test:
	# 테스트 실행
```

`check` 타겟은 **읽기 전용** (파일 변경 없음)이어야 하며 `make -j`(병렬 실행)에 안전해야 합니다. hooks가 `make check`를 감지하면 도구별 검사를 Makefile에 위임합니다.

언어별 상세 패턴(Go, Node.js, Bazel, 혼합 스택)은 [makefile-workflow](https://github.com/jaeyeom/claude-toolbox) 규칙을 참조하세요.

## 포함된 Hooks

### Pre-commit Hooks (모두 병렬 실행)

| Hook | 기능 | 스킵 조건 |
|------|------|----------|
| `check.sh` | `make -j check` 실행 (가능한 경우) | `check:` 타겟이 있는 Makefile 없음 |
| `check-large-files.sh` | 크기 임계값 초과 스테이징 파일 거부 (기본 1 MB) | 항상 실행; `git config hooks.maxfilesize <bytes>`로 제한 설정 |
| `check-whitespace.sh` | `git diff-index --check`로 trailing whitespace 및 혼합 줄 끝 검출 | 언어 포매터가 처리하는 파일 (*.go, *.py, *.proto, *.bzl, BUILD*) |
| `check-non-ascii.sh` | 이식성을 위해 비ASCII 파일명 거부 | `git config hooks.allownonascii true` |
| `lint-go.sh` | `golangci-lint run ./...` 실행 | `.golangci.yml` 없음, 도구 미설치, 또는 Makefile `check:` 타겟이 `golangci-lint` 언급 |
| `lint-python.sh` | Python 프로젝트에서 `ruff check` 및 `ruff format --check` 실행 | ruff 설정 없음, 도구 미설치, Bazel이 `@multitool`로 ruff 관리, 또는 Makefile `check:` 타겟이 `ruff` 언급 |
| `lint-shell.sh` | 스테이징된 `.sh` 파일에 `shellcheck` 실행 | 스테이징된 `.sh` 파일 없음, 도구 미설치, 또는 Makefile `check:` 타겟이 `shellcheck` 언급 |
| `lint-org.sh` | 스테이징된 `.org` 파일에 `org-lint` 실행 | 스테이징된 `.org` 파일 없음, 도구 미설치 |
| `lint-semgrep.sh` | 정적 분석을 위한 `semgrep scan` 실행 | `.semgrep.yml`, `.semgrep.yaml`, `.semgrep/` 디렉토리 없음; 도구 미설치; 또는 Makefile `check:` 타겟이 `semgrep` 언급 |
| `test-bazel.sh` | `bazel-affected-tests`로 영향받는 Bazel 테스트 실행, 포맷 테스트 자동 수정 | `BUILD`/`BUILD.bazel` 파일 없음, `bazel` 미설치, 또는 Makefile `check:` 타겟이 `bazel test` 언급 |

### Commit-msg Hooks (모두 병렬 실행)

| Hook | 기능 | 스킵 조건 |
|------|------|----------|
| `check-subject-length.sh` | 72자 이하 제목 줄 강제 | 항상 실행 |
| `check-co-authored-by.sh` | `Co-Authored-By:` 줄 거부 | 항상 실행 |
| `check-generated-comment.sh` | `Generated with ` 마커 (AI 도구 아티팩트) 거부 | 항상 실행 |

## 설정

| 설정 | 효과 |
|------|------|
| `git config hooks.allownonascii true` | 비ASCII 파일명 허용 |
| `git config hooks.maxfilesize <bytes>` | 대용량 파일 임계값 설정 (기본: 1048576 = 1 MB) |
| Makefile `check:` 타겟 | 존재 시 도구별 hooks를 대체 |
| Makefile의 `.NOTPARALLEL` | 병렬 `make -j` 실행 비활성화 |

## Hooks 비활성화

Githooks ignore 패턴으로 특정 hooks 비활성화:

```bash
# 특정 hook 비활성화
git hooks ignore add --pattern "ns:jaeyeom-shared-githooks/pre-commit/checks/test-bazel.sh"

# 모든 Bazel 테스트 비활성화
git hooks ignore add --pattern "**/test-bazel.sh"
```

또는 `.githooks/.ignore.yaml`에 패턴 추가:

```yaml
patterns:
  - "pre-commit/checks/test-bazel.sh"
```

## 문서

| 문서 | 설명 |
|------|-----|
| [시작하기](docs/ko/getting-started.md) | 설치, 설정, 버전 고정 |
| [Hooks 레퍼런스](docs/ko/hooks-reference.md) | 모든 hook의 상세 동작과 조건 |
| [설정 가이드](docs/ko/configuration.md) | 네임스페이스, 비활성화, 환경변수, 컨테이너 |
| [개발 가이드](docs/ko/development.md) | 새 hook 추가, 코딩 규칙, 테스트 |

## 개발

개발 도구 설치:

```bash
brew install shfmt shellcheck yamllint biome
```

포매팅과 검사 실행:

```bash
make          # format + lint
make check    # CI용 검사 (파일 변경 없음)
make help     # 사용 가능한 타겟 표시
```

디렉토리 구조, YAML hook 설정, 병렬 실행, 컨테이너화 등에 대한 전체 기술 문서는 [CLAUDE.md](CLAUDE.md)를 참조하세요.
