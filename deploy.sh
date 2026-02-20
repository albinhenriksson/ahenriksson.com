#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# 🚀 Hugo Build + Deploy (rsync over SSH)
# Repo:   /home/albin/Git/ahenriksson.com
# Remote: albin@46.62.230.205:/var/www/ahenriksson.com/public/
# ──────────────────────────────────────────────────────────────────────────────

REPO_DIR="/home/albin/Git/ahenriksson.com"
PUBLIC_DIR="public"

REMOTE_USER="albin"
REMOTE_HOST="46.62.230.205"
REMOTE_DIR="/var/www/ahenriksson.com/public"

SSH_PORT="22"

MINIFY=1
DRYRUN=0
VERBOSE=0

# Colors.
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
  BOLD="$(tput bold)"; DIM="$(tput dim)"; RESET="$(tput sgr0)"
  RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"; BLUE="$(tput setaf 4)"; MAGENTA="$(tput setaf 5)"; CYAN="$(tput setaf 6)"
else
  BOLD=""; DIM=""; RESET=""
  RED=""; GREEN=""; YELLOW=""; BLUE=""; MAGENTA=""; CYAN=""
fi

usage() {
  cat <<EOF
${BOLD}deploy.sh${RESET} — bygg + rsync:a Hugo-sajten 🚀

Flags:
  --dry-run       Gör allt men rsync:ar med --dry-run (inget skrivs på servern)
  --no-minify     Bygg utan --minify
  -v, --verbose   Mer output (rsync blir snackigare)
  -h, --help      Den här texten

Exempel:
  ./deploy.sh
  ./deploy.sh --dry-run
EOF
}

log()   { echo -e "${CYAN}ℹ${RESET}  $*"; }
ok()    { echo -e "${GREEN}✅${RESET} $*"; }
warn()  { echo -e "${YELLOW}⚠️${RESET}  $*"; }
die()   { echo -e "${RED}💥${RESET} ${BOLD}$*${RESET}" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRYRUN=1; shift ;;
    --no-minify) MINIFY=0; shift ;;
    -v|--verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Okänd flagga: $1 (kör --help)" ;;
  esac
done

for cmd in hugo rsync ssh; do
  command -v "$cmd" >/dev/null 2>&1 || die "Saknar '$cmd' i PATH."
done

[[ -d "$REPO_DIR" ]] || die "Repo saknas: $REPO_DIR"

# Lock.
LOCKFILE="/tmp/hugo-deploy.$(id -u).lock"
exec 9>"$LOCKFILE"
flock -n 9 || die "Deploy kör redan (lock: $LOCKFILE)."

echo -e "${MAGENTA}${BOLD}
╔══════════════════════════════════════╗
║   🧱  BUILD   ➜   🚀  DEPLOY         ║
╚══════════════════════════════════════╝
${RESET}"

cd "$REPO_DIR"

# Info.
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  COMMIT="$(git rev-parse --short HEAD 2>/dev/null || true)"
  BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  DIRTY=""
  if [[ -n "$(git status --porcelain 2>/dev/null || true)" ]]; then
    DIRTY=" ${YELLOW}(dirty)${RESET}"
  fi
  log "Git: ${BOLD}${BRANCH}${RESET} @ ${BOLD}${COMMIT}${RESET}${DIRTY}"
fi

log "Kör: ${BOLD}hugo${RESET} ${DIM}(repo: $REPO_DIR)${RESET}"

HUGO_ARGS=()
[[ $MINIFY -eq 1 ]] && HUGO_ARGS+=(--minify)
HUGO_ARGS+=(--gc --cleanDestinationDir)

# Build.
hugo "${HUGO_ARGS[@]}"

[[ -d "$PUBLIC_DIR" ]] || die "Hittar inte '$PUBLIC_DIR' efter build. Något gick åt helvete."

ok "Build klar 🧁  ($(du -sh "$PUBLIC_DIR" | awk '{print $1}'))"

REMOTE="${REMOTE_USER}@${REMOTE_HOST}"
SSH_OPTS=(-p "$SSH_PORT" -o BatchMode=yes)

log "Förbereder remote-katalog: ${BOLD}${REMOTE}:${REMOTE_DIR}${RESET}"
ssh "${SSH_OPTS[@]}" "$REMOTE" "mkdir -p '$REMOTE_DIR'"

RSYNC_ARGS=(-a -z --delete)
RSYNC_ARGS+=(--human-readable --stats)

RSYNC_ARGS+=(--info=progress2)

[[ $VERBOSE -eq 1 ]] && RSYNC_ARGS+=(-v)

if [[ $DRYRUN -eq 1 ]]; then
  warn "DRY-RUN aktiv: inget skrivs till servern 🧪"
  RSYNC_ARGS+=(--dry-run)
fi

log "Rsyncar: ${BOLD}${PUBLIC_DIR}/ ➜ ${REMOTE}:${REMOTE_DIR}/${RESET}"
rsync "${RSYNC_ARGS[@]}" -e "ssh -p $SSH_PORT" "${PUBLIC_DIR}/" "${REMOTE}:${REMOTE_DIR}/"

if [[ $DRYRUN -eq 1 ]]; then
  ok "Dry-run klar. Inget ändrat på servern 👀"
else
  ok "Deploy klar! 🚀🔥"
fi
