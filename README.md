# VPS Bootstrap

A one-command bootstrap for a fresh Debian or Ubuntu VPS. It runs the host audit, installs Docker, applies the BBR/network tuning script, then deploys Cloudflare DDNS with Docker Compose.

## What it does

1. Updates APT and installs `curl` and CA certificates.
2. Downloads and runs the configured host-audit script.
3. Downloads and runs the configured Docker installer, then checks Docker and Compose.
4. Downloads and runs the configured BBR/network optimization script.
5. Writes the Cloudflare token to `/opt/cloudflare-ddns/.env` with mode `600` and starts `favonia/cloudflare-ddns:1`.

This installer needs root and supports Debian/Ubuntu systems using `apt-get` and systemd. The Docker script only checks the distribution family (`debian` or `ubuntu`), then relies on Docker's convenience installer and an APT Compose package fallback; it does not check release versions itself. The BBR upstream script's support note lists Debian 11/12 and Ubuntu 22.04/24.04/26.04. Debian 13 is detected and allowed to continue with a compatibility warning, but is not confirmed by that upstream support note. On container VPS plans, kernel settings such as BBR may be unavailable.

The host audit script backs up and rewrites `/etc/hosts` with its blocklist. Review that list before use: it maps many domains (including some package tracker hosts) to localhost. The BBR script also applies persistent kernel/network tuning and creates up to 512 MB swap when no swap exists. This combined installer sets `ENABLE_FORWARD=0` while running BBR, since general server initialization does not normally need IP forwarding.

## Run

Replace the example token and domain with your own Cloudflare API token and DNS name:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/USERNAME/vps-bootstrap/main/install.sh) 'cf_xxxxxxxxxxxxxxxxxxx' 'ddns.example.com'
```

To enable IPv6 DNS management, add `ipv6`:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/USERNAME/vps-bootstrap/main/install.sh) 'cf_xxxxxxxxxxxxxxxxxxx' 'ddns.example.com' ipv6
```

Log in as `root` and run the command in Bash. The API token is passed as a command-line argument and may be recorded in shell history or briefly visible in the process list. Use a narrowly scoped Cloudflare API token. Never put a real token in this repository or in a public issue.

The installer replaces `/opt/cloudflare-ddns/.env` when rerun and recreates the DDNS container. Do not use it to update an existing DDNS installation unless you intend to replace its token/domain configuration.

## Manage DDNS

```bash
cd /opt/cloudflare-ddns && docker compose logs -f
cd /opt/cloudflare-ddns && docker compose restart
cd /opt/cloudflare-ddns && docker compose down
```

The installer is intended to be rerunnable: it rewrites the DDNS config and recreates its container. It does not reboot the VPS. Review the source before running it as root, because the script changes system packages and networking settings.

## Publish on GitHub

1. Create a new **public** repository, for example `vps-bootstrap` (or `debian-vps-setup`).
2. Put `install.sh` and `README.md` in the repository root.
3. Replace `USERNAME` in the command above with your GitHub username.
4. Commit and push to the `main` branch. You can use GitHub's web upload, or from a local clone:

   ```bash
   git init
   git add install.sh README.md
   git commit -m "Add VPS bootstrap installer"
   git branch -M main
   git remote add origin https://github.com/USERNAME/vps-bootstrap.git
   git push -u origin main
   ```

5. Confirm the raw file opens at `https://raw.githubusercontent.com/USERNAME/vps-bootstrap/main/install.sh`, then use the command above.

For safer repeatable deployments, create a GitHub Release and pin the command to a tagged version (replace `main` with the tag, such as `v1.0.0`).
