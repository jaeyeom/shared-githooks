# 설정 가이드

이 문서는 shared-githooks의 고급 설정 옵션을 설명합니다.

## 네임스페이스

`.githooks/.namespace` 파일은 이 shared 저장소의 네임스페이스 식별자를
정의합니다. 현재 값은 `jaeyeom-shared-githooks`입니다.

소비(consuming) 저장소에서 이 네임스페이스를 사용하여 hooks를 선택적으로
비활성화하거나 실행할 수 있습니다:

```bash
# 네임스페이스의 특정 hook 실행
git hooks exec ns:jaeyeom-shared-githooks/pre-commit/checks/check.sh

# 네임스페이스 전체 비활성화
# .githooks/.ignore.yaml
patterns:
  - "ns:jaeyeom-shared-githooks/**"
```

## Hook 비활성화 (.ignore.yaml)

특정 hook을 비활성화하려면 소비 저장소의 `.githooks/.ignore.yaml`에
패턴을 추가합니다:

```yaml
patterns:
  # 특정 hook 비활성화
  - "pre-commit/checks/test-bazel.sh"

  # 디렉토리 단위 비활성화
  - "pre-commit/checks/**"

  # 네임스페이스 기반 비활성화
  - "ns:jaeyeom-shared-githooks/**"

  # 와일드카드 패턴
  - "**/experimental/**"
```

## 환경변수 (.envs.yaml)

`.githooks/.envs.yaml`을 통해 hook 실행 시 환경변수를 설정할 수 있습니다.

## Git 설정을 통한 제어

일부 hook은 Git 설정 값으로 동작을 제어할 수 있습니다:

| 설정 | 기본값 | 설명 |
|------|--------|-----|
| `hooks.allownonascii` | `false` | `true`로 설정하면 비ASCII 파일명 허용 |
| `hooks.i18nsync` | `false` | `true`로 설정하면 모든 언어 변형이 함께 스테이징되어야 함 |
| `hooks.maxfilesize` | `1048576` (1 MB) | 스테이징된 파일의 최대 크기 (바이트) |

```bash
# 비ASCII 파일명 허용
git config hooks.allownonascii true

# i18n 문서 동기화 검사 활성화
git config hooks.i18nsync true

# 대용량 파일 임계값을 5 MB로 설정
git config hooks.maxfilesize 5242880
```

## hook에서 사용 가능한 환경변수

Githooks가 hook 실행 시 자동으로 설정하는 환경변수입니다:

| 변수 | 설명 |
|------|-----|
| `STAGED_FILES` | 스테이징된 파일 목록 (줄바꿈 구분, pre-commit 전용) |
| `STAGED_FILES_FILE` | 스테이징된 파일 경로가 담긴 파일 경로 (null 구분) |
| `GITHOOKS_OS` | 운영 체제 (`linux`, `darwin`, `windows`) |
| `GITHOOKS_ARCH` | 아키텍처 (`amd64`, `arm64`) |
| `GITHOOKS_CONTAINER_RUN` | 컨테이너 내부 실행 시 설정됨 |

## 컨테이너화된 Hook 실행

hooks를 Docker/Podman 컨테이너 내에서 실행할 수 있습니다.

### 이미지 정의 (.images.yaml)

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

### Hook에서 이미지 참조

```yaml
# .githooks/pre-commit/containerized-check.yaml
version: 3
cmd: ./check.sh
image:
  reference: "my-image:1.0"
```

## YAML Hook 설정

셸 스크립트 대신 YAML로 hook을 정의할 수 있습니다:

```yaml
# .githooks/pre-commit/my-hook.yaml
version: 1
cmd: "path/to/executable"
args:
  - "--flag"
  - "${env:MY_VAR}"
  - "${git:some.config}"
```

### 변수 치환 패턴

| 패턴 | 소스 |
|------|-----|
| `${env:VAR}` | 환경변수 |
| `${git:VAR}` | Git 설정 (자동 스코프) |
| `${git-l:VAR}` | 로컬 Git 설정 |
| `${git-g:VAR}` | 글로벌 Git 설정 |
| `${git-s:VAR}` | 시스템 Git 설정 |
| `${!env:VAR}` | 필수 환경변수 (없으면 실패) |

## 병렬 실행 설정

hooks의 실행 방식을 제어할 수 있습니다:

- **순차 실행:** hook 타입 디렉토리에 직접 스크립트 배치
- **병렬 실행:** 하위 디렉토리에 스크립트를 묶어서 배치
- **전체 병렬:** 디렉토리에 `.all-parallel` 마커 파일 생성

```
.githooks/pre-commit/
├── sequential-a.sh          # 순차 실행 (사전순)
├── sequential-b.sh          # 순차 실행 (사전순)
└── parallel-batch/          # 내부 스크립트는 병렬 실행
    ├── check-a.sh
    └── check-b.sh
```
