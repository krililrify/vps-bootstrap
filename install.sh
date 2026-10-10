#!/usr/bin/env bash
set -Eeuo pipefail

# Combined VPS setup: host audit, Docker, BBR/network tuning, Cloudflare DDNS.
# Usage: bash install.sh <Cloudflare_API_Token> <domain> [ipv6]

readonly AUDIT_URL="https://raw.githubusercontent.com/krililrify/jinzhi/main/audit-hosts.sh"
readonly DOCKER_URL="https://raw.githubusercontent.com/newxqkjfenxiang/docker-install/main/install-docker.sh"
readonly BBR_URL="https://raw.githubusercontent.com/krililrify/bbr/main/init.sh"
readonly DDNS_IMAGE="favonia/cloudflare-ddns:1"
readonly DDNS_DIR="/opt/cloudflare-ddns"

log() { printf '[INFO] %s\n' "$*"; }
ok() { printf '[ OK ] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die() { printf '[ERR ] %s\n' "$*" >&2; exit 1; }
usage() {
    cat <<'USAGE'
Usage:
  bash install.sh <Cloudflare_API_Token> <domain> [ipv6]

Example:
  bash install.sh 'cf_xxxxxxxxxxxxxxxxxxx' 'ddns.example.com'
  bash install.sh 'cf_xxxxxxxxxxxxxxxxxxx' 'ddns.example.com' ipv6
USAGE
}

[[ $# -ge 2 && $# -le 3 ]] || { usage; exit 2; }
readonly CF_API_TOKEN="$1"
readonly DDNS_DOMAIN="$2"
readonly IPV6_OPTION="${3:-}"
[[ -n "$CF_API_TOKEN" && "$CF_API_TOKEN" != *$'\n'* && "$CF_API_TOKEN" != *$'\r'* ]] || die 'Invalid API token.'
[[ "$DDNS_DOMAIN" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]] || die 'Invalid domain name.'
[[ -z "$IPV6_OPTION" || "$IPV6_OPTION" == ipv6 ]] || { usage; die "Unknown option: $IPV6_OPTION"; }
readonly ENABLE_IPV6=$([[ "$IPV6_OPTION" == ipv6 ]] && printf true || printf false)

[[ $EUID -eq 0 ]] || die 'Run as root (or use sudo).'
[[ -r /etc/os-release ]] || die 'Cannot identify OS: /etc/os-release is missing.'
# shellcheck disable=SC1091
source /etc/os-release
case "${ID:-}" in
    debian|ubuntu) ;;
    *) die "Unsupported OS '${ID:-unknown}'. This installer supports Debian/Ubuntu only." ;;
esac
command -v apt-get >/dev/null 2>&1 || die 'apt-get not found.'
command -v systemctl >/dev/null 2>&1 || die 'systemd/systemctl is required.'

case "${ID:-}:${VERSION_ID:-}" in
    debian:13*) warn 'Debian 13 is not listed as supported by the upstream BBR script; continuing, but compatibility is not confirmed.' ;;
esac
log "Detected ${PRETTY_NAME:-${ID} ${VERSION_ID:-}}"

TMP_DIR="$(mktemp -d)"
chmod 700 "$TMP_DIR"
cleanup() { rm -rf -- "$TMP_DIR"; }
trap cleanup EXIT

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

log 'Updating apt and installing curl/CA certificates...'
apt-get update
apt-get install -y curl ca-certificates

fetch_and_run() {
    local label="$1" url="$2" target="$3"
    log "Downloading ${label} script..."
    curl --fail --show-error --silent --location --retry 3 "$url" -o "$target" || die "Failed to download ${label} script."
    [[ -s "$target" ]] || die "Downloaded ${label} script is empty."
    log "Running ${label} script..."
    if [[ "$label" == 'BBR/network optimization' ]]; then
        # BBR tuning does not require forwarding; keep it off for a general-purpose server.
        ENABLE_FORWARD="${ENABLE_FORWARD:-0}" bash "$target" || die "${label} step failed."
    else
        bash "$target" || die "${label} step failed."
    fi
    ok "${label} completed."
}

fetch_and_run 'Host audit' "$AUDIT_URL" "$TMP_DIR/audit-hosts.sh"
fetch_and_run 'Docker installation' "$DOCKER_URL" "$TMP_DIR/install-docker.sh"
command -v docker >/dev/null 2>&1 || die 'Docker command not found after installation.'
systemctl enable --now docker || die 'Could not enable/start Docker service.'
docker info >/dev/null 2>&1 || die 'Docker daemon is not responding.'
docker compose version >/dev/null 2>&1 || die "Docker Compose plugin ('docker compose') is missing."
ok "Docker ready: $(docker --version)"

# The upstream BBR installer supports configuration through environment variables.
log 'Running BBR/network optimization...'
fetch_and_run 'BBR/network optimization' "$BBR_URL" "$TMP_DIR/bbr-init.sh"

log 'Configuring Cloudflare DDNS...'
mkdir -p "$DDNS_DIR"
chmod 700 "$DDNS_DIR"
ENV_TMP="$TMP_DIR/ddns.env"
{
    printf 'CLOUDFLARE_API_TOKEN=%s\n' "$CF_API_TOKEN"
    printf 'DOMAINS=%s\n' "$DDNS_DOMAIN"
    printf 'UPDATE_INTERVAL=120\n'
    [[ "$ENABLE_IPV6" == true ]] || printf 'IP6_PROVIDER=none\n'
} > "$ENV_TMP"
chmod 600 "$ENV_TMP"
install -m 600 "$ENV_TMP" "$DDNS_DIR/.env"
cat > "$DDNS_DIR/docker-compose.yml" <<'COMPOSE'
services:
  cloudflare-ddns:
    image: favonia/cloudflare-ddns:1
    container_name: cloudflare-ddns
    network_mode: host
    restart: unless-stopped
    env_file:
      - .env
COMPOSE
chmod 600 "$DDNS_DIR/docker-compose.yml"
(
    cd "$DDNS_DIR"
    docker compose pull
    docker compose up -d --force-recreate --remove-orphans
) || die 'Failed to deploy Cloudflare DDNS container.'
ok "Cloudflare DDNS is running for ${DDNS_DOMAIN}."

printf '\n==============================================\n'
printf 'Setup complete\n'
printf 'Docker: '
docker --version
printf 'BBR congestion control: '
sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || true
printf 'DDNS directory: %s\n' "$DDNS_DIR"
printf 'DDNS IPv6: %s\n' "$([[ "$ENABLE_IPV6" == true ]] && printf enabled || printf disabled)"
printf '==============================================\n'
