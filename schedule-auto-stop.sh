#!/usr/bin/env bash
set -Eeuo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pid_file="${project_dir}/auto-stop.pid"
log_file="${project_dir}/auto-stop.log"
delay_seconds="${AUTO_STOP_SECONDS:-2400}"

if [[ -f "$pid_file" ]]; then
  old_pid="$(cat "$pid_file" 2>/dev/null || true)"

  if [[ "$old_pid" =~ ^[0-9]+$ ]] &&
     kill -0 "$old_pid" 2>/dev/null; then

    old_command="$(
      ps -p "$old_pid" -o args= 2>/dev/null || true
    )"

    if [[ "$old_command" == *"stop-project.sh"* ||
          "$old_command" == *"mediawiki-project-auto-stop"* ]]; then
      kill "$old_pid" 2>/dev/null || true
      printf 'Предыдущий таймер отменён: PID %s\n' "$old_pid"
    fi
  fi
fi

nohup bash -c '
  delay_seconds="$1"
  project_dir="$2"
  log_file="$3"

  sleep "$delay_seconds"
  cd "$project_dir"
  ./stop-project.sh >> "$log_file" 2>&1
' mediawiki-project-auto-stop \
  "$delay_seconds" \
  "$project_dir" \
  "$log_file" \
  >/dev/null 2>&1 &

new_pid=$!
printf '%s\n' "$new_pid" > "$pid_file"

printf 'Автоотключение через %s минут, PID: %s\n' \
  "$((delay_seconds / 60))" \
  "$new_pid"
