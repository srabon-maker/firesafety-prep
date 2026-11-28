#!/usr/bin/env bash
set -euo pipefail
base=$(mktemp -d)
trap 'rm -rf -- "$base"' EXIT
live="$base/live"
mkdir "$live" "$base/backup1" "$base/backup2" "$base/backup3"
dashboard=fire_safety_job_prep_dashboard.php
cat > "$live/$dashboard" <<'PHP'
<?php $live_only = 'keep this code'; ?>
<img src="assets/fire-safety-bd-logo.png" class="logo">
<img src="assets/another.png">
PHP
cat > "$live/users.php" <<'PHP'
<?php $custom = 123; ?>
<img src='assets/fire-safety-bd-logo.png'>
PHP
cp "$live/$dashboard" "$base/expected"
chmod 640 "$live/$dashboard"
bash scripts/deploy_admin_logo_cache.sh "$live" "$base/backup1"
cmp "$base/expected" "$base/backup1/logo-url-originals/$dashboard"
sed 's|src="assets/fire-safety-bd-logo.png"|src="assets/fire-safety-bd-logo.png?v=177"|' "$base/expected" > "$base/expected-new"
cmp "$base/expected-new" "$live/$dashboard"
grep -Fq "src='assets/fire-safety-bd-logo.png?v=177'" "$live/users.php"
[[ "$(stat -c %a "$live/$dashboard")" == 640 ]]
bash scripts/deploy_admin_logo_cache.sh "$live" "$base/backup2" | grep -F 'ADMIN_LOGO_CACHE_BUST_OK (0 pages changed)'
# Invalid syntax on a changed page must prevent all pending replacements.
cp "$base/expected" "$live/$dashboard"
printf '%s\n' '<?php syntax broken here ?>' '<img src="assets/fire-safety-bd-logo.png">' > "$live/users.php"
if bash scripts/deploy_admin_logo_cache.sh "$live" "$base/backup3"; then
  echo 'Expected syntax failure' >&2; exit 1
fi
cmp "$base/expected" "$live/$dashboard"
echo 'Logo URL deployment regression tests passed'
