#!/usr/bin/env bash
# Fresh production installation only. Existing sites and Node are left intact.
set -euo pipefail
test "$EUID" -eq 0 || { echo 'Run this installer with sudo.' >&2; exit 1; }
test "$(uname -m)" = x86_64
test -d /opt/campus/source/deploy
test ! -f /opt/campus/pocketbase/pb_data/data.db || { echo 'Production database already exists; do not reinstall.' >&2; exit 1; }
if ss -lnt | grep -Eq ':(8090|8787)[[:space:]]'; then
  echo 'Campus backend ports are already occupied.' >&2; exit 1
fi
cd /opt/campus
printf '%s\n' \
  '9042ec818570e79c3628dadcd0a756c1496d9e1173918ec409d133c02f82e5fa  pocketbase.zip' \
  'df450af89261115ef9f9e3830c3eeb2cc9213b63c720b1af623cb5dcbe2e02de  node-v22.23.3-linux-x64.tar.xz' | sha256sum -c -
id campus >/dev/null 2>&1 || useradd --system --home-dir /opt/campus --shell /usr/sbin/nologin campus
install -d -m 755 /opt/campus/runtime /opt/campus/pocketbase /opt/campus/ai-gateway
install -d -o campus -g campus -m 700 /opt/campus/pocketbase/pb_data
install -d -m 755 /opt/campus/pocketbase/pb_migrations /opt/campus/pocketbase/pb_public
install -d -o root -g campus -m 750 /etc/campus
workdir=$(mktemp -d /opt/campus/install.XXXXXX)
unzip -q /opt/campus/pocketbase.zip -d "$workdir"
install -m 755 "$workdir/pocketbase" /opt/campus/pocketbase/pocketbase
tar -xf /opt/campus/node-v22.23.3-linux-x64.tar.xz -C /opt/campus/runtime
cp /opt/campus/source/experiments/pocketbase/pb_migrations/*.js /opt/campus/pocketbase/pb_migrations/
cp /opt/campus/source/deploy/pocketbase/pb_migrations/*.js /opt/campus/pocketbase/pb_migrations/
cp /opt/campus/source/deploy/pocketbase/pb_public/* /opt/campus/pocketbase/pb_public/
cp -R /opt/campus/source/apps/ai-gateway/src /opt/campus/source/apps/ai-gateway/test /opt/campus/ai-gateway/
install -m 644 /opt/campus/source/apps/ai-gateway/package.json /opt/campus/ai-gateway/package.json
if [[ ! -f /etc/campus/ai.env ]]; then
  install -o root -g campus -m 640 /opt/campus/source/apps/ai-gateway/.env.example /etc/campus/ai.env
fi
cd /opt/campus/ai-gateway
/opt/campus/runtime/node-v22.23.3-linux-x64/bin/node --test
cd /opt/campus/pocketbase
sudo -u campus ./pocketbase migrate up
install -m 644 /opt/campus/source/deploy/campus-pocketbase.service.example /etc/systemd/system/campus-pocketbase.service
sed 's|ExecStart=/usr/bin/node |ExecStart=/opt/campus/runtime/node-v22.23.3-linux-x64/bin/node |' \
  /opt/campus/source/deploy/campus-ai.service.example > /etc/systemd/system/campus-ai.service
systemctl daemon-reload
systemctl enable --now campus-pocketbase campus-ai
systemctl is-active campus-pocketbase campus-ai
echo 'Loopback services installed. Verify health, initialize the administrator, then publish the Caddy route.'
