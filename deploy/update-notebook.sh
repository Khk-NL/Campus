#!/usr/bin/env bash
# Additive upgrade of the existing Campulse installation. Run from a verified source staging directory.
set -euo pipefail
test "$EUID" -eq 0 || { echo 'Run with sudo.' >&2; exit 1; }
source_dir=$(realpath "${1:?Pass the verified staging directory}")
test -f "$source_dir/apps/ai-gateway/src/notebook.mjs"
test -f "$source_dir/apps/ai-gateway/package-lock.json"
test -f /opt/campus/pocketbase/pb_data/data.db
export PATH=/opt/campus/runtime/node-v22.23.3-linux-x64/bin:$PATH
stage=$(mktemp -d /opt/campus/notebook-upgrade.XXXXXX)
cp -R "$source_dir/apps/ai-gateway/"* "$stage/"
cd "$stage"
npm ci --omit=dev --no-audit --no-fund
node --test test/*.test.mjs
backup="/opt/campus/backups/notebook-runtime-$(date +%Y%m%d-%H%M%S)"
install -d -m 700 "$backup"
cp -a /opt/campus/ai-gateway "$backup/ai-gateway"
systemctl stop campus-pocketbase
trap 'systemctl start campus-pocketbase' EXIT
cp -a /opt/campus/pocketbase/pb_data "$backup/pb_data"
cmp /opt/campus/pocketbase/pb_data/data.db "$backup/pb_data/data.db"
install -m 644 "$source_dir/deploy/pocketbase/pb_migrations/1790210008_course_artifacts.js" /opt/campus/pocketbase/pb_migrations/
install -m 644 "$source_dir/deploy/pocketbase/pb_migrations/1790210009_note_full_text.js" /opt/campus/pocketbase/pb_migrations/
cd /opt/campus/pocketbase
sudo -u campus ./pocketbase migrate up
systemctl start campus-pocketbase
trap - EXIT
systemctl stop campus-ai
cp -R "$stage/"* /opt/campus/ai-gateway/
chown -R root:campus /opt/campus/ai-gateway
systemctl start campus-ai
systemctl is-active campus-pocketbase campus-ai
curl --fail --silent http://127.0.0.1:8090/api/health
printf '\nBackup: %s\n' "$backup"
