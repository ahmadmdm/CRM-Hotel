#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
backend_dir="$(cd "${script_dir}/.." && pwd)"

deploy_domain="${CRMHOTEL_DEPLOY_DOMAIN:-crm.clo0.net}"
frontend_port="${FRONTEND_PORT:-3810}"
api_port="${APP_PORT:-3811}"
skip_build=false
verify_only=false
image_tag=""

usage() {
  cat <<'EOF'
Usage: ./deploy/deploy-prod.sh [options] [image-tag]

Options:
  --skip-build   Run docker compose without --build.
  --verify-only  Skip deploy steps and run verification checks only.
  -h, --help     Show this help message.
EOF
}

purge_cloudflare_frontend_cache() {
  local token="${CLOUDFLARE_API_TOKEN:-}"
  local env_file="/etc/caddy/caddy.env"

  if [[ -z "$token" ]] && [[ -r "$env_file" ]]; then
    token="$(sudo python3 - <<'PY'
from pathlib import Path

for line in Path('/etc/caddy/caddy.env').read_text().splitlines():
    if line.startswith('CLOUDFLARE_API_TOKEN='):
        print(line.split('=', 1)[1].strip().strip('"').strip("'"))
        break
PY
)"
  fi

  if [[ -z "$token" ]]; then
    echo "Cloudflare cache purge skipped: token not available."
    return 0
  fi

  if ! CLOUDFLARE_API_TOKEN="$token" python3 - <<'PY'
import json
import os
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

zone_name = 'clo0.net'
purge_urls = [
    'https://crm.clo0.net/',
    'https://crm.clo0.net/index.html',
    'https://crm.clo0.net/flutter_bootstrap.js',
    'https://crm.clo0.net/main.dart.js',
    'https://crm.clo0.net/flutter.js',
    'https://crm.clo0.net/flutter_service_worker.js',
    'https://crm.clo0.net/push/onesignal/OneSignalSDKWorker.js',
    'https://crm.clo0.net/manifest.json',
]
token = os.environ['CLOUDFLARE_API_TOKEN']

try:
  zone_req = Request(
    f'https://api.cloudflare.com/client/v4/zones?name={zone_name}',
    headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
  )
  with urlopen(zone_req, timeout=30) as resp:
    zone_data = json.load(resp)

  if not zone_data.get('result'):
    raise SystemExit(f'Unable to resolve Cloudflare zone id: {json.dumps(zone_data)}')

  zone_id = zone_data['result'][0]['id']
  purge_req = Request(
    f'https://api.cloudflare.com/client/v4/zones/{zone_id}/purge_cache',
    data=json.dumps({'files': purge_urls}).encode(),
    headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
    method='POST',
  )
  with urlopen(purge_req, timeout=30) as resp:
    purge_data = json.load(resp)
except HTTPError as exc:
  raise SystemExit(f'Cloudflare purge request failed with HTTP {exc.code}.') from None
except URLError as exc:
  raise SystemExit(f'Cloudflare purge request failed: {exc.reason}.') from None

if not purge_data.get('success'):
    raise SystemExit(json.dumps(purge_data))

print('Cloudflare frontend cache purged.')
PY
  then
    echo "Cloudflare cache purge skipped: request failed or token lacks permission."
    return 0
  fi
}

verify_deployment() {
  local public_base="https://${deploy_domain}"
  local local_frontend="http://127.0.0.1:${frontend_port}"
  local local_api="http://127.0.0.1:${api_port}/api/v1/health"
  local public_api="${public_base}/api/v1/health"
  local local_worker="${local_frontend}/push/onesignal/OneSignalSDKWorker.js"
  local public_worker="${public_base}/push/onesignal/OneSignalSDKWorker.js"

  echo "Verifying local API health..."
  curl --fail --silent --show-error "$local_api" | grep -q '"status":"ok"'

  echo "Verifying local frontend bootstrap..."
  curl --fail --silent --show-error "${local_frontend}/index.html" | grep -q 'flutter_bootstrap.js'
  curl --fail --silent --show-error "${local_frontend}/index.html" | grep -q 'crmHotelOneSignal'

  echo "Verifying local OneSignal worker..."
  curl --fail --silent --show-error "$local_worker" | grep -q 'OneSignalSDK.sw.js'

  echo "Verifying public API health..."
  curl --fail --silent --show-error "$public_api" | grep -q '"status":"ok"'

  echo "Verifying public frontend bootstrap..."
  curl --fail --silent --show-error "${public_base}/index.html" | grep -q 'flutter_bootstrap.js'
  curl --fail --silent --show-error "${public_base}/index.html" | grep -q 'crmHotelOneSignal'

  echo "Verifying public OneSignal worker..."
  curl --fail --silent --show-error "$public_worker" | grep -q 'OneSignalSDK.sw.js'

  echo "Deployment verification passed."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build)
      skip_build=true
      ;;
    --verify-only)
      verify_only=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        if [[ -n "$image_tag" ]]; then
          echo "Only one image tag may be provided." >&2
          exit 1
        fi
        image_tag="$1"
        shift
      done
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "$image_tag" ]]; then
        echo "Only one image tag may be provided." >&2
        exit 1
      fi
      image_tag="$1"
      ;;
  esac
  shift
done

cd "$backend_dir"

if [[ -n "$image_tag" ]]; then
  export CRMHOTEL_IMAGE_TAG="$image_tag"
fi

if [[ "$verify_only" == true ]]; then
  echo "Running deployment verification only."
  verify_deployment
  exit 0
fi

compose_args=(compose -f compose.prod.yml up -d --pull always --remove-orphans)
if [[ "$skip_build" == false ]]; then
  compose_args+=(--build)
else
  echo "Skipping build step and reusing existing images/build outputs."
fi

docker "${compose_args[@]}"
docker compose -f compose.prod.yml ps
purge_cloudflare_frontend_cache

if command -v systemctl >/dev/null 2>&1 && systemctl is-active caddy >/dev/null 2>&1; then
  sudo systemctl reload caddy
  SYSTEMD_PAGER=cat sudo journalctl -u caddy -n 20 --no-pager
fi

verify_deployment