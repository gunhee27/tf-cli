#!/usr/bin/env bash
set -euo pipefail

TF_REPO="gunhee27/tf-cli"
TF_RAW="https://raw.githubusercontent.com/${TF_REPO}/main"
TF_HOME="${TF_HOME:-$HOME/.tf}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
ok()   { echo -e "${GREEN}✔ $*${RESET}"; }
warn() { echo -e "${YELLOW}⚠ $*${RESET}"; }
step() { echo -e "\n${CYAN}${BOLD}▶ $*${RESET}"; }

# ─── 1. 디렉토리 생성 ────────────────────────────────────────────────────────
step "tf-cli 설치 중..."
mkdir -p "${TF_HOME}/bin"

# ─── 2. 스크립트 다운로드 ────────────────────────────────────────────────────
curl -fsSL "${TF_RAW}/tf" -o "${TF_HOME}/bin/tf"
chmod +x "${TF_HOME}/bin/tf"

curl -fsSL "${TF_RAW}/VERSION" -o "${TF_HOME}/VERSION"
VERSION=$(cat "${TF_HOME}/VERSION" | tr -d '[:space:]')
ok "tf-cli v${VERSION} 다운로드 완료"

# ─── 3. PATH 등록 ────────────────────────────────────────────────────────────
SHELL_RC=""
if [[ "$SHELL" == */zsh ]]; then
  SHELL_RC="$HOME/.zshrc"
elif [[ "$SHELL" == */bash ]]; then
  SHELL_RC="$HOME/.bashrc"
fi

PATH_LINE='export PATH="$HOME/.tf/bin:$PATH"'

if [[ -n "$SHELL_RC" ]]; then
  if ! grep -qF '.tf/bin' "$SHELL_RC" 2>/dev/null; then
    echo "" >> "$SHELL_RC"
    echo "# tf-cli" >> "$SHELL_RC"
    echo "$PATH_LINE" >> "$SHELL_RC"
    ok "PATH 등록 완료 ($SHELL_RC)"
  else
    ok "PATH 이미 등록되어 있음"
  fi
fi

# ─── 4. 현재 세션에서 즉시 사용 가능하게 ────────────────────────────────────
export PATH="$HOME/.tf/bin:$PATH"

echo ""
echo -e "${BOLD}설치 완료!${RESET}"
echo ""
echo "  새 터미널에서 바로 사용 가능합니다."
echo "  현재 터미널에서 즉시 사용하려면:"
echo -e "    ${CYAN}source ${SHELL_RC:-~/.zshrc}${RESET}"
echo ""
echo "  사용법:"
echo -e "    ${CYAN}tf${RESET}         — init? → validate → plan → apply"
echo -e "    ${CYAN}tf destroy${RESET} — 리소스 전체 삭제"
echo -e "    ${CYAN}tf update${RESET}  — tf-cli 업데이트"
echo -e "    ${CYAN}tf version${RESET} — 버전 확인"
