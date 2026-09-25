#!/bin/bash
set -e

REPO_URL="https://github.com/linuxebug/Pure-Theme-Pterodactyl.git"
PTERODACTYL_DIR="/var/www/pterodactyl"
BACKUP_DIR="/var/backups/pure-theme"

echo "========================================"
echo "       Pure Theme - Pterodactyl"
echo "========================================"

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo bash install.sh"
    exit 1
fi

if [ ! -d "$PTERODACTYL_DIR" ]; then
    read -rp "Pterodactyl directory [$PTERODACTYL_DIR]: " CUSTOM_DIR
    [ -n "$CUSTOM_DIR" ] && PTERODACTYL_DIR="$CUSTOM_DIR"
fi

if [ ! -f "$PTERODACTYL_DIR/artisan" ]; then
    echo "Error: Pterodactyl installation not found at $PTERODACTYL_DIR"
    exit 1
fi

command -v git >/dev/null 2>&1 || {
    echo "Git is required. Install with: apt update && apt install -y git"
    exit 1
}

echo "[1/5] Creating backup..."
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/pterodactyl-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf "$BACKUP_FILE" -C "$PTERODACTYL_DIR" resources public package.json 2>/dev/null || true
echo "Backup: $BACKUP_FILE"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "[2/5] Downloading Pure Theme..."
git clone --depth 1 "$REPO_URL" "$TMP_DIR/repo"

THEME_DIR="$TMP_DIR/repo/theme"

if [ ! -d "$THEME_DIR" ]; then
    echo "Error: The GitHub repository must contain a 'theme/' directory."
    echo "Put the Pterodactyl theme files inside:"
    echo "Pure-Theme-Pterodactyl/theme/"
    exit 1
fi

echo "[3/5] Installing theme files..."
cp -a "$THEME_DIR"/. "$PTERODACTYL_DIR"/

cd "$PTERODACTYL_DIR"

echo "[4/5] Building frontend..."
if command -v yarn >/dev/null 2>&1; then
    yarn install --frozen-lockfile 2>/dev/null || yarn install
    yarn build:production
elif command -v npm >/dev/null 2>&1; then
    npm install
    npm run build:production
else
    echo "Warning: npm/yarn not found. Frontend was not rebuilt."
fi

echo "[5/5] Clearing cache..."
php artisan view:clear || true
php artisan config:clear || true
php artisan cache:clear || true

systemctl restart pteroq 2>/dev/null || true
systemctl restart nginx 2>/dev/null || true

echo ""
echo "========================================"
echo "       Pure Theme Installed!"
echo "========================================"
echo "Refresh your Pterodactyl panel."
echo "Backup: $BACKUP_FILE"
echo ""
