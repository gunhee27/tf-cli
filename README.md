# tf-cli

Terraform 워크플로우 자동화 도구.

`init` / `validate` / `plan` / `apply` 를 상황에 맞게 자동 판단합니다.

## 설치

```bash
curl -fsSL https://raw.githubusercontent.com/gunhee27/tf-cli/main/install.sh | bash
source ~/.zshrc
```

## 사용법

```bash
tf           # init(필요시) → validate → plan → apply
tf destroy   # 리소스 전체 삭제
tf plan      # plan만 확인
tf update    # tf-cli 업데이트
tf version   # 버전 확인
```

## 자동 판단 로직

| 상황 | 동작 |
|------|------|
| `.terraform` 없음 / provider 변경 | `init` 자동 실행 |
| 인프라가 코드와 동일한 상태 | `apply` 건너뜀 |
| 변경사항 있음 | 확인 후 `apply` |
