#!/usr/bin/env bash
set -Eeuo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
inventory_file="${project_dir}/Ansible/inventory.ini"
all_vars_file="${project_dir}/Ansible/group_vars/all/main.yml"

vm_status() {
  yc compute instance get "$1" --format=json --jq='.status' | tr -d '"'
}

vm_external_ip() {
  yc compute instance get "$1" --format=json \
    --jq='.network_interfaces[0].primary_v4_address.one_to_one_nat.address' |
    tr -d '"'
}

start_vm() {
  local vm_name="$1"
  local current_status
  current_status="$(vm_status "$vm_name")"

  case "$current_status" in
    RUNNING|STARTING)
      printf '%s: %s\n' "$vm_name" "$current_status"
      ;;
    STOPPED)
      printf '%s: запускается\n' "$vm_name"
      yc compute instance start "$vm_name" --async >/dev/null
      ;;
    *)
      printf 'Нельзя запустить %s: статус %s\n' \
        "$vm_name" "$current_status" >&2
      return 1
      ;;
  esac
}

wait_running() {
  local vm_name="$1"
  local current_status=""

  for ((attempt = 1; attempt <= 60; attempt++)); do
    current_status="$(vm_status "$vm_name")"
    if [[ "$current_status" == "RUNNING" ]]; then
      printf '%s: RUNNING\n' "$vm_name"
      return 0
    fi
    sleep 5
  done

  printf 'Тайм-аут запуска %s; статус %s\n' \
    "$vm_name" "$current_status" >&2
  return 1
}

start_group() {
  local vm_name

  for vm_name in "$@"; do
    start_vm "$vm_name"
  done

  for vm_name in "$@"; do
    wait_running "$vm_name"
  done
}

command -v yc >/dev/null
[[ -f "$inventory_file" ]]
[[ -f "$all_vars_file" ]]

start_group lb-01

lb_public_ip=""

for ((attempt = 1; attempt <= 60; attempt++)); do
  lb_public_ip="$(vm_external_ip lb-01)"

  if [[ "$lb_public_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    break
  fi

  sleep 2
done

if [[ ! "$lb_public_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  printf 'Не удалось получить публичный IP lb-01\n' >&2
  exit 1
fi

cp -a "$inventory_file" \
  "${inventory_file}.backup-before-last-start"

cp -a "$all_vars_file" \
  "${all_vars_file}.backup-before-last-start"

sed -i -E \
  "s#^(lb-01[[:space:]]+ansible_host=)[^[:space:]]+#\1${lb_public_ip}#" \
  "$inventory_file"

sed -i -E \
  "s#(ProxyJump=ubuntu@)[0-9.]+#\1${lb_public_ip}#g" \
  "$inventory_file"

sed -i -E \
  "s#^(mediawiki_public_url:[[:space:]]*\").*(\")#\1http://${lb_public_ip}\2#" \
  "$all_vars_file"

printf 'Ansible обновлён: lb-01 = %s\n' "$lb_public_ip"

start_group db-02
start_group db-01
start_group wiki-01 wiki-02 backup-01 zabbix-01

zabbix_public_ip="$(vm_external_ip zabbix-01)"

yc compute instance list

printf 'MediaWiki: http://%s\n' "$lb_public_ip"
printf 'Zabbix:    http://%s\n' "$zabbix_public_ip"
