#!/usr/bin/env bash
# Update only the existing static logo URL in live admin pages. Never copy repo PHP over them.
set -euo pipefail
umask 077
root=${1:?live document root required}
backup=${2:?backup directory required}
[[ -d "$root" && ! -L "$root" && -d "$backup" && ! -L "$backup" ]]
root=$(cd "$root" && pwd -P)
backup=$(cd "$backup" && pwd -P)
case "$backup/" in "$root/"*) echo "Backup must be outside document root" >&2; exit 1;; esac
stage=$(mktemp -d "$backup/logo-url-stage.XXXXXX")
# Keep backups outside webroot; staging on the same filesystem permits atomic rename.
[[ "$(stat -c %d "$root")" = "$(stat -c %d "$stage")" ]]
trap 'rm -rf -- "$stage"' EXIT
saved="$backup/logo-url-originals"
mkdir -m 700 "$saved"
pages=(fire_safety_job_prep_dashboard.php users.php notes.php support_admin.php questions.php homepage_admin.php premium_admin.php job_circulars.php admin_operations.php category_management.php model_tests.php)
changed=()
for page in "${pages[@]}"; do
  live="$root/$page"
  if [[ ! -e "$live" && ! -L "$live" ]]; then
    if [[ "$page" == fire_safety_job_prep_dashboard.php ]]; then
      echo "Dashboard missing; no PHP files changed" >&2; exit 1
    fi
    echo "Logo URL skipped (not installed): $page"
    continue
  fi
  [[ -f "$live" && ! -L "$live" ]]
  cp -p -- "$live" "$saved/$page"
  cp -p -- "$live" "$stage/$page"
  sed -e 's|src="assets/fire-safety-bd-logo\.png"|src="assets/fire-safety-bd-logo.png?v=177"|g' \
      -e "s|src='assets/fire-safety-bd-logo\.png'|src='assets/fire-safety-bd-logo.png?v=177'|g" \
      "$saved/$page" > "$stage/$page"
  if ! grep -Fq 'assets/fire-safety-bd-logo.png?v=177' "$stage/$page"; then
    if [[ "$page" == fire_safety_job_prep_dashboard.php ]]; then
      echo "Dashboard logo URL differs; no PHP files changed" >&2; exit 1
    fi
    echo "Logo URL skipped (different reference): $page"
    continue
  fi
  if cmp -s "$saved/$page" "$stage/$page"; then
    echo "Logo URL already current: $page"
    continue
  fi
  php -l "$stage/$page" >/dev/null
  changed+=("$page")
done
# Validate all candidates and ensure live originals are unchanged before writing any.
for page in "${changed[@]}"; do
  [[ -f "$root/$page" && ! -L "$root/$page" ]]
  cmp -s "$saved/$page" "$root/$page"
done
for page in "${changed[@]}"; do
  mv -f -- "$stage/$page" "$root/$page"
  echo "Logo URL updated: $page"
done
echo "ADMIN_LOGO_CACHE_BUST_OK (${#changed[@]} pages changed)"
