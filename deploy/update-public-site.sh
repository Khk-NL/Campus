#!/usr/bin/env bash
set -euo pipefail

# Update website files only; PocketBase data and other sites stay in place.
commit="${1:?Usage: update-public-site.sh SOURCE_COMMIT}"
[[ "$commit" =~ ^[0-9a-f]{40}$ ]] || { echo 'Expected a full source commit'; exit 1; }
target=/opt/campus/pocketbase/pb_public
[[ -d "$target/assets" ]] || { echo 'Expected the existing PocketBase public directory'; exit 1; }
staging=$(mktemp -d /tmp/campulse-public.XXXXXX)
backup="/opt/campus/backups/public-$(date +%Y%m%d-%H%M%S)"
files=(index.html about.html community.html download.html features.html privacy.html admin.html assets/admin.css assets/admin.mjs assets/admin-client.mjs)

for file in "${files[@]}"; do
  mkdir -p "$staging/$(dirname "$file")"
  curl --fail --silent --show-error --retry 2 --connect-timeout 15 --max-time 60 \
    "https://raw.githubusercontent.com/Khk-NL/Campus/$commit/deploy/pocketbase/pb_public/$file" -o "$staging/$file"
done
/opt/campus/runtime/node-v22.23.3-linux-x64/bin/node --check "$staging/assets/admin.mjs"
/opt/campus/runtime/node-v22.23.3-linux-x64/bin/node --check "$staging/assets/admin-client.mjs"
for file in "${files[@]}"; do
  mkdir -p "$backup/$(dirname "$file")"
  if [[ -f "$target/$file" ]]; then cp -p "$target/$file" "$backup/$file"; fi
  install -o campus -g campus -m 0644 "$staging/$file" "$target/$file.next"
  mv "$target/$file.next" "$target/$file"
done
printf 'Published commit %s\nBackup: %s\nStaging: %s\n' "$commit" "$backup" "$staging"
