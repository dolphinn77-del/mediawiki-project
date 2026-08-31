#!/usr/bin/env bash
set -Eeuo pipefail

vm_status() {
  yc compute instance get "$1" --format=json --jq='.status' | tr -d '"'
}

stop_vm() {
  local vm_name="$1"
  local current_status
  current_status="$(vm_status "$vm_name")"

  case "$current_status" in
    STOPPED|STOPPING)
      printf '%s: %s\n' "$vm_name" "$current_status"
      ;;
    RUNNING|STARTING)
      printf '%s: останавливается\n' "$vm_name"
      yc compute instance stop "$vm_name" --async >/dev/null
      ;;
    *)
      printf 'Нельзя остановить %s: статус %s\n' \
        "$vm_name" "$current_status" >&2
      return 1
      ;;
  esac
}

wait_stopped() {
  local vm_name="$1"
  local current_status=""

  for ((attempt = 1; attempt <= 60; attempt++)); do
    current_status="$(vm_status "$vm_name")"

    if [[ "$current_status" == "STOPPED" ]]; then
      printf '%s: STOPPED\n' "$vm_name"
      return 0
    fi

    sleep 5
  done

  printf 'Тайм-аут остановки %s; статус %s\n' \
    "$vm_name" "$current_status" >&2
  return 1
}

stop_group() {
  local vm_name

  for vm_name in "$@"; do
    stop_vm "$vm_name"
  done

  for vm_name in "$@"; do
    wait_stopped "$vm_name"
  done
}

command -v yc >/dev/null

stop_group wiki-01 wiki-02
stop_group backup-01 zabbix-01
stop_group db-01
stop_group db-02
stop_group lb-01

yc compute instance list

printf 'Все ВМ остановлены. vCPU и RAM больше не тарифицируются.\n'
