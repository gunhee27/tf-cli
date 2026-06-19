#!/usr/bin/env bash
set -euo pipefail

# ─── 설정 ────────────────────────────────────────────────────────────────────
TF_HOME="${TF_HOME:-$HOME/.tf}"
TF_REPO="gunhee27/tf-cli"
TF_RAW="https://raw.githubusercontent.com/${TF_REPO}/main"

# ─── 색상 ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

step()  { echo -e "\n${CYAN}${BOLD}▶ $*${RESET}"; }
ok()    { echo -e "${GREEN}✔ $*${RESET}"; }
warn()  { echo -e "${YELLOW}⚠ $*${RESET}"; }
die()   { echo -e "${RED}✖ $*${RESET}" >&2; exit 1; }

confirm() {
  local prompt="${1:-계속하시겠습니까?} [y/N] " ans
  read -r -p "$(echo -e "${BOLD}${prompt}${RESET}")" ans
  if [[ "$ans" == "y" || "$ans" == "Y" ]]; then return 0; else return 1; fi
}

# ─── init 필요 여부 판단 ─────────────────────────────────────────────────────
needs_init() {
  [[ ! -d ".terraform" ]] && return 0
  [[ ! -f ".terraform.lock.hcl" ]] && return 0
  [[ ! -d ".terraform/providers" ]] && return 0
  local newer
  newer=$(find . -maxdepth 1 -name "*.tf" -newer ".terraform.lock.hcl" 2>/dev/null \
    | xargs grep -l 'required_providers\|terraform {' 2>/dev/null | head -1)
  [[ -n "$newer" ]] && return 0
  return 1
}

# ─── terraform 프로젝트인지 확인 ─────────────────────────────────────────────
assert_tf_project() {
  local tf_files
  tf_files=$(find . -maxdepth 1 -name "*.tf" 2>/dev/null | head -1)
  if [[ -z "$tf_files" ]]; then
    die "현재 디렉토리에 .tf 파일이 없습니다 (terraform 프로젝트가 아닙니다)"
  fi
}

# ─── main ────────────────────────────────────────────────────────────────────
ACTION="${1:-up}"

case "$ACTION" in

  # ── tf up : init? → validate → plan → apply ──────────────────────────────
  up)
    assert_tf_project

    if needs_init; then
      step "terraform init (provider 변경 감지)"
      terraform init || die "init 실패"
      ok "init 완료"
    else
      ok "init 불필요 (.terraform 최신 상태)"
    fi

    step "terraform validate"
    terraform validate || die "validate 실패 — 문법 오류를 먼저 수정하세요"
    ok "validate 통과"

    step "terraform plan"
    echo ""
    set +e
    terraform plan -detailed-exitcode -out=".tfplan"
    PLAN_EXIT=$?
    set -e

    case $PLAN_EXIT in
      0)
        ok "변경사항 없음 — 인프라가 이미 최신 상태입니다"
        rm -f .tfplan
        exit 0
        ;;
      1)
        rm -f .tfplan
        die "plan 실패"
        ;;
      2)
        echo ""
        confirm "위 plan을 적용하시겠습니까?" || { warn "취소됨"; rm -f .tfplan; exit 0; }
        step "terraform apply"
        terraform apply ".tfplan"
        rm -f .tfplan
        ok "apply 완료"
        ;;
    esac
    ;;

  # ── tf destroy ────────────────────────────────────────────────────────────
  destroy)
    assert_tf_project
    warn "모든 리소스를 삭제합니다!"
    step "terraform plan -destroy"
    terraform plan -destroy -out=".tfplan" || die "plan 실패"

    echo ""
    confirm "정말로 destroy하시겠습니까?" || { warn "취소됨"; rm -f .tfplan; exit 0; }

    step "terraform destroy"
    terraform apply ".tfplan"
    rm -f .tfplan
    ok "destroy 완료"
    ;;

  # ── 개별 커맨드 ───────────────────────────────────────────────────────────
  init)     assert_tf_project; terraform init ;;
  validate) assert_tf_project; terraform validate ;;
  plan)     assert_tf_project; terraform plan ;;

  # ── tf version ────────────────────────────────────────────────────────────
  version)
    local_ver=$(cat "${TF_HOME}/VERSION" 2>/dev/null || echo "unknown")
    echo -e "${BOLD}tf-cli${RESET} v${local_ver}"
    echo -e "repo: https://github.com/${TF_REPO}"

    if command -v curl &>/dev/null; then
      remote_ver=$(curl -fsSL "${TF_RAW}/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "")
      if [[ -n "$remote_ver" && "$remote_ver" != "$local_ver" ]]; then
        warn "새 버전 v${remote_ver} 이 있습니다 — 'tf update' 로 업데이트하세요"
      else
        ok "최신 버전입니다"
      fi
    fi
    ;;

  # ── tf update ─────────────────────────────────────────────────────────────
  update)
    step "최신 버전 확인 중..."
    remote_ver=$(curl -fsSL "${TF_RAW}/VERSION" 2>/dev/null | tr -d '[:space:]') \
      || die "버전 확인 실패 (네트워크 오류)"
    local_ver=$(cat "${TF_HOME}/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "none")

    if [[ "$remote_ver" == "$local_ver" ]]; then
      ok "이미 최신 버전입니다 (v${local_ver})"
      exit 0
    fi

    echo -e "  ${local_ver} → ${BOLD}${remote_ver}${RESET}"
    confirm "업데이트하시겠습니까?" || { warn "취소됨"; exit 0; }

    curl -fsSL "${TF_RAW}/tf" -o "${TF_HOME}/bin/tf" || die "다운로드 실패"
    chmod +x "${TF_HOME}/bin/tf"
    echo "$remote_ver" > "${TF_HOME}/VERSION"
    ok "v${remote_ver} 업데이트 완료"
    ;;

  *)
    echo -e "사용법: ${BOLD}tf${RESET} [명령어]"
    echo ""
    echo -e "  ${BOLD}terraform 명령어${RESET}"
    echo "  up       — init(필요시) → validate → plan → apply  (기본)"
    echo "  destroy  — plan destroy → 확인 → destroy"
    echo "  init     — terraform init"
    echo "  validate — terraform validate"
    echo "  plan     — terraform plan"
    echo ""
    echo -e "  ${BOLD}tf-cli 관리${RESET}"
    echo "  version  — 현재 버전 확인 및 업데이트 알림"
    echo "  update   — 최신 버전으로 업데이트"
    exit 1
    ;;
esac
