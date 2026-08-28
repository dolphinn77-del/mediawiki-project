#!/usr/bin/env bash
# START PROJECT WRAPPER
set -Eeuo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
inventory_file="${project_dir}/Ansible/inventory.ini"
post_start_playbook="${project_dir}/Ansible/post-start-project.yml"
ssh_key="${HOME}/.ssh/id_ed25519"
auto_stop_script="${project_dir}/schedule-auto-stop.sh"

"$auto_stop_script"

"${project_dir}/start-project-vms.sh"

lb_ip="$(
  awk '
    /^lb-01[[:space:]]/ {
      for (field = 1; field <= NF; field++) {
        if ($field ~ /^ansible_host=/) {
          split($field, value, "=")
          print value[2]
          exit
        }
      }
    }
  ' "$inventory_file"
)"

if [[ -z "$lb_ip" ]]; then
  printf 'Не удалось получить IP lb-01 из inventory.ini\n' >&2
  exit 1
fi

printf '\nПодготовка SSH через lb-01 (%s)...\n' "$lb_ip"

ssh-keygen -R "$lb_ip" >/dev/null 2>&1 || true

lb_ssh_ready=false

for ((attempt = 1; attempt <= 30; attempt++)); do
  if ssh \
    -i "$ssh_key" \
    -o IdentitiesOnly=yes \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=5 \
    "ubuntu@${lb_ip}" \
    'test "$(hostname)" = "lb-01"' \
    >/dev/null 2>&1; then

    lb_ssh_ready=true
    break
  fi

  printf 'Ожидание SSH lb-01: попытка %s/30\n' "$attempt"
  sleep 5
done

if [[ "$lb_ssh_ready" != true ]]; then
  printf 'SSH на lb-01 не стал доступен\n' >&2
  exit 1
fi

printf 'SSH lb-01: доступен\n'
printf '\nВведите пароль Ansible Vault для постстартовой настройки проекта.\n'

ansible-playbook \
  -i "$inventory_file" \
  --ask-vault-pass \
  --forks 1 \
  "$post_start_playbook"

mediawiki_url="$(
  sed -nE \
    's/^mediawiki_public_url:[[:space:]]*"([^"]+)".*/\1/p' \
    "${project_dir}/Ansible/group_vars/all/main.yml"
)"

printf '\nПроверка MediaWiki: %s\n' "$mediawiki_url"

curl \
  --fail \
  --silent \
  --show-error \
  --location \
  --connect-timeout 5 \
  --max-time 20 \
  --output /dev/null \
  --write-out 'MediaWiki HTTP: %{http_code}\nИтоговый URL: %{url_effective}\n' \
  "$mediawiki_url"

printf '\nПроект полностью запущен и настроен.\n'
