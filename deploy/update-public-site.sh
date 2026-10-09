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
node=/opt/campus/runtime/node-v22.23.3-linux-x64/bin/node

for file in "${files[@]}"; do
  mkdir -p "$staging/$(dirname "$file")"
  curl --fail --silent --show-error --retry 2 --connect-timeout 15 --max-time 60 \
    "https://api.github.com/repos/Khk-NL/Campus/contents/deploy/pocketbase/pb_public/$file?ref=$commit" -o "$staging/$file.json"
  "$node" -e 'const fs=require("node:fs"),crypto=require("node:crypto"); const row=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); if(row.encoding!=="base64") throw Error("Expected base64 file"); const bytes=Buffer.from(row.content,"base64"); const hash=crypto.createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex"); if(hash!==row.sha) throw Error("Git blob hash mismatch"); fs.writeFileSync(process.argv[2],bytes);' "$staging/$file.json" "$staging/$file"
done
"$node" --check "$staging/assets/admin.mjs"
"$node" --check "$staging/assets/admin-client.mjs"
for file in "${files[@]}"; do
  mkdir -p "$backup/$(dirname "$file")"
  if [[ -f "$target/$file" ]]; then cp -p "$target/$file" "$backup/$file"; fi
  install -o campus -g campus -m 0644 "$staging/$file" "$target/$file.next"
  mv "$target/$file.next" "$target/$file"
done
printf 'Published commit %s\nBackup: %s\nStaging: %s\n' "$commit" "$backup" "$staging"
