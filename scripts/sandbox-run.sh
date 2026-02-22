#!/usr/bin/env bash
# sandbox-run.sh — Docker sandbox management for isolated implement execution
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$ROOT/sandbox/docker-compose.yml"
SERVICE="runner"

source "$SCRIPT_DIR/event-log.sh"

usage() {
  cat <<'USAGE'
Usage:
  sandbox-run.sh up                    Start sandbox container
  sandbox-run.sh down                  Stop and remove sandbox
  sandbox-run.sh status                Show sandbox status
  sandbox-run.sh run "<command>"        Run command in sandbox
  sandbox-run.sh seed <path...>         Copy files into sandbox
  sandbox-run.sh collect <output-tar>   Collect artifacts from sandbox
USAGE
}

require_docker() {
  command -v docker >/dev/null 2>&1 || { echo "[ERROR] docker not found" >&2; exit 1; }
  docker compose version >/dev/null 2>&1 || { echo "[ERROR] docker compose not available" >&2; exit 1; }
  [[ -f "$COMPOSE_FILE" ]] || { echo "[ERROR] compose file missing: $COMPOSE_FILE" >&2; exit 1; }
}

cmd_up() {
  require_docker
  docker compose -f "$COMPOSE_FILE" up -d --build
  echo "[INFO] sandbox is up" >&2
}

cmd_down() {
  require_docker
  docker compose -f "$COMPOSE_FILE" down -v
  echo "[INFO] sandbox is down" >&2
}

cmd_status() {
  require_docker
  docker compose -f "$COMPOSE_FILE" ps
}

cmd_run() {
  require_docker
  [[ $# -ge 1 ]] || { echo "[ERROR] run requires command string" >&2; exit 1; }
  local command_str="$*"
  docker compose -f "$COMPOSE_FILE" run --rm -T "$SERVICE" sh -lc "$command_str"
}

cmd_seed() {
  require_docker
  [[ $# -ge 1 ]] || { echo "[ERROR] seed requires at least one path" >&2; exit 1; }

  (
    cd "$ROOT"
    tar -cf - "$@"
  ) | docker compose -f "$COMPOSE_FILE" run --rm -T "$SERVICE" \
    sh -lc 'mkdir -p /workspace/input && tar -C /workspace/input -xf -'

  echo "[INFO] seeded sandbox input" >&2
}

cmd_collect() {
  require_docker
  [[ $# -eq 1 ]] || { echo "[ERROR] collect requires output tar path" >&2; exit 1; }
  local out_tar="$1"

  docker compose -f "$COMPOSE_FILE" run --rm -T "$SERVICE" \
    sh -lc 'mkdir -p /workspace/output && tar -C /workspace/output -cf - .' > "$out_tar"

  echo "[INFO] collected sandbox output to $out_tar" >&2
}

sub="${1:-help}"
case "$sub" in
  up)     shift; [[ $# -eq 0 ]] || { usage >&2; exit 1; }; cmd_up ;;
  down)   shift; [[ $# -eq 0 ]] || { usage >&2; exit 1; }; cmd_down ;;
  status) shift; [[ $# -eq 0 ]] || { usage >&2; exit 1; }; cmd_status ;;
  run)    shift; cmd_run "$@" ;;
  seed)   shift; cmd_seed "$@" ;;
  collect) shift; cmd_collect "$@" ;;
  help|-h|--help) usage ;;
  *) usage >&2; exit 1 ;;
esac
