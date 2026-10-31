#!/bin/sh
set -eu

# Run from a cloned repository: sh install.sh [--no-activate]
activate=1
case "${1-}" in
  '') ;;
  --no-activate) activate=0 ;;
  *) echo "Использование: sh install.sh [--no-activate]" >&2; exit 2 ;;
esac
[ "$#" -le 1 ] || { echo "Слишком много аргументов" >&2; exit 2; }
[ "$(uname -s)" = Darwin ] || { echo "Этот установщик поддерживает только macOS." >&2; exit 1; }
command -v herdr-app >/dev/null 2>&1 || { echo "Не найден herdr-app. Установите настольный Herdr и добавьте его в PATH." >&2; exit 1; }
command -v codex >/dev/null 2>&1 || { echo "Не найден codex. Установите Codex CLI и добавьте его в PATH." >&2; exit 1; }
[ -x /usr/bin/python3 ] || { echo "Не найден /usr/bin/python3." >&2; exit 1; }
source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
[ -f "$source_dir/usage-tabs/main.js" ] && [ -f "$source_dir/usage-tabs/usage.py" ] && [ -f "$source_dir/usage-tabs/mod.json" ] && [ -f "$source_dir/usage-layout.json" ] || { echo "Файлы мода не найдены рядом с install.sh." >&2; exit 1; }
app_dir=${HERDR_APP_HOME:-"$HOME/.config/herdr-app"}
mkdir -p "$app_dir/mods" "$app_dir/layouts"
# Preserve existing files without merging old mod contents into the new version.
backup_path() {
  target=$1
  [ -e "$target" ] || return 0
  backup="$target.backup-$(date +%Y%m%d-%H%M%S)"
  index=1
  while [ -e "$backup" ]; do backup="$target.backup-$(date +%Y%m%d-%H%M%S)-$index"; index=$((index + 1)); done
  mv "$target" "$backup"
  printf 'Сохранена резервная копия: %s\n' "$backup"
}
backup_path "$app_dir/mods/usage-tabs"
backup_path "$app_dir/layouts/usage-layout.json"
cp -R "$source_dir/usage-tabs" "$app_dir/mods/usage-tabs"
cp "$source_dir/usage-layout.json" "$app_dir/layouts/usage-layout.json"
echo "Проверяю мод…"
if ! herdr-app check "$app_dir/mods/usage-tabs"; then
  echo "Проверка не прошла. Оформление не включено; ранее существовавшие файлы сохранены в резервных копиях." >&2
  exit 1
fi
if [ "$activate" -eq 1 ]; then
  if herdr-app do layout.switch '{"name":"usage-layout"}'; then
    echo "Готово. Откройте вкладку с Codex — лимиты появятся в верхней панели."
  else
    echo "Файлы установлены, но включить оформление не удалось. Откройте Herdr и выполните:" >&2
    echo "herdr-app do layout.switch '{"name":"usage-layout"}'" >&2
    exit 1
  fi
else
  echo "Мод установлен и проверен; оформление не переключалось."
fi
