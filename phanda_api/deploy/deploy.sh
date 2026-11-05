#!/bin/bash
#
# Kuphanda API — cPanel deploy.
#
# Pulls nothing, pushes nothing: run it inside an existing checkout.
# Safe to re-run; every step is idempotent.
#
# Layout it assumes (shared hosting, no SSH):
#
#   /home/kuphanda/kuphanda/phanda_api       <- this checkout (NOT web-facing)
#   /home/kuphanda/public_html/app.kuphanda.com  <- document root
#
# Override the two paths with env vars if the account changes.
#
# Secrets never live in git. The database password is generated on the
# server the first time this runs, and mail credentials are read from
# deploy/mail.credentials (git-ignored) when that file exists.

set -uo pipefail

APP_DIR=${APP_DIR:-/home/kuphanda/kuphanda/phanda_api}
WEB_DIR=${WEB_DIR:-/home/kuphanda/public_html/app.kuphanda.com}
DB_NAME=${DB_NAME:-kuphanda_phanda}
DB_USER=${DB_USER:-kuphanda_phanda}
APP_URL_=${APP_URL_:-https://app.kuphanda.com}

cd "$APP_DIR" || { echo "FATAL: $APP_DIR not found"; exit 1; }

say() { printf '\n== %s\n' "$*"; }

# ---------------------------------------------------------------- database ---
if [ ! -f "$APP_DIR/.env" ]; then
  say "first run: creating database, user and .env"

  DB_PASSWORD=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 24)

  uapi Mysql create_database name="$DB_NAME" 2>&1 | tail -2
  # create_user fails when the user already exists — reset it instead so the
  # password in .env and the password in MySQL can never drift apart.
  if ! uapi Mysql create_user name="$DB_USER" password="$DB_PASSWORD" >/dev/null 2>&1; then
    uapi Mysql set_password user="$DB_USER" password="$DB_PASSWORD" >/dev/null 2>&1 \
      || echo "WARN: could not set password for $DB_USER"
  fi
  uapi Mysql set_privileges_on_database user="$DB_USER" database="$DB_NAME" privileges=ALL >/dev/null 2>&1

  MAIL_USERNAME=""
  MAIL_PASSWORD=""
  MAIL_HOST="sandbox.smtp.mailtrap.io"
  MAIL_MAILER="log"
  if [ -f "$APP_DIR/deploy/mail.credentials" ]; then
    # shellcheck disable=SC1091
    . "$APP_DIR/deploy/mail.credentials"
    MAIL_MAILER="smtp"
  else
    # No credentials means no SMTP host we can reach. Pointing the mailer at a
    # sandbox that refuses connections made every sign-up wait 23 seconds for a
    # timeout and then answer 500, after the account had already been created.
    # Writing to the log keeps sign-up instant until real credentials arrive.
    echo "WARN: deploy/mail.credentials missing — writing mail to storage/logs/laravel.log"
  fi

  cat > "$APP_DIR/.env" <<ENVEOF
APP_NAME=Kuphanda
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=$APP_URL_
PASSWORD_RESET_URL=$APP_URL_/reset-password
APP_LOCALE=en
APP_FALLBACK_LOCALE=en
APP_FAKER_LOCALE=en_US
APP_MAINTENANCE_DRIVER=file
BCRYPT_ROUNDS=12
LOG_CHANNEL=stack
LOG_STACK=single
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=error
DB_CONNECTION=mysql
DB_HOST=localhost
DB_PORT=3306
DB_DATABASE=$DB_NAME
DB_USERNAME=$DB_USER
DB_PASSWORD=$DB_PASSWORD
SESSION_DRIVER=database
SESSION_LIFETIME=120
SESSION_ENCRYPT=false
SESSION_PATH=/
SESSION_DOMAIN=null
BROADCAST_CONNECTION=log
FILESYSTEM_DISK=public
MEDIA_DISK=public
QUEUE_CONNECTION=database
CACHE_STORE=database
MAIL_MAILER=$MAIL_MAILER
MAIL_HOST=$MAIL_HOST
MAIL_PORT=2525
MAIL_USERNAME=$MAIL_USERNAME
MAIL_PASSWORD=$MAIL_PASSWORD
MAIL_SCHEME=null
MAIL_FROM_ADDRESS="no-reply@kuphanda.com"
MAIL_FROM_NAME="\${APP_NAME}"
VITE_APP_NAME="\${APP_NAME}"
# The Web client from the Firebase project, which is the audience the app sends
# when it signs in with Google. Without it /auth/google answers 503 and the
# phone reports a failure that no amount of retrying can fix.
GOOGLE_CLIENT_ID=239327365893-1725f6in8f6nnmc85836eqhrets9hfes.apps.googleusercontent.com
ENVEOF
  chmod 600 "$APP_DIR/.env"
  echo ".env written ($(wc -c < "$APP_DIR/.env") bytes)"
else
  say "keeping existing .env"
fi

# --------------------------------------------------------------- composer ----
say "composer"
composer install --no-dev --optimize-autoloader --no-interaction 2>&1 | tail -5

# ----------------------------------------------------------------- artisan ---
if ! grep -q '^APP_KEY=base64:' "$APP_DIR/.env"; then
  say "generating app key"
  php artisan key:generate --force
fi

say "migrating"
php artisan migrate --force 2>&1 | tail -15

# The catalogue is code-owned: its records live in the seeders, so a deploy that
# skips this leaves a server running new code against an old library. `--prune`
# removes records with nothing behind them, which is what the empty placeholder
# rows were. Records a learner bought, marked offline or was assigned are
# unpublished instead of deleted.
say "syncing the catalogue"
php artisan library:sync --prune 2>&1 | tail -12

say "permissions"
chmod -R u+rwX storage bootstrap/cache

say "storage link"
php artisan storage:link 2>&1 | tail -2

# --------------------------------------------------------------- web root ----
say "publishing document root"
mkdir -p "$WEB_DIR"
rm -f "$WEB_DIR/index.html" "$WEB_DIR/default.html"
cp -R "$APP_DIR/public/." "$WEB_DIR/"
# The document root sits outside the project, so storage must be bridged by
# hand. Replacing any copied directory with the real symlink keeps uploads
# and generated files in one place.
rm -rf "$WEB_DIR/storage"
ln -sfn "$APP_DIR/storage/app/public" "$WEB_DIR/storage"

# index.php cannot use __DIR__.'/..' from here — it is two levels away from
# the project. This copy points at the checkout explicitly.
cp "$APP_DIR/deploy/webroot-index.php" "$WEB_DIR/index.php"
chmod 644 "$WEB_DIR/index.php"

# ------------------------------------------------------------------ caches ---
say "caching config and routes"
php artisan config:clear >/dev/null 2>&1
php artisan config:cache 2>&1 | tail -2
php artisan route:clear >/dev/null 2>&1

say "smoke test"
# This host serves the API only: the document root is denied and /up is not
# routed, so probing either reports LiteSpeed's 403/404 and reads as a broken
# deploy. The honest signals are the API itself — an unauthenticated GET on a
# guarded route answers 401, and an empty login POST answers 422 (validated,
# never a 500).
probe() {
  local method="$1" url="$2" code body
  body=$(mktemp)
  code=$(curl -s -o "$body" -w '%{http_code}' -X "$method" \
    -H 'Accept: application/json' --max-time 20 "$url" 2>/dev/null)
  printf '%s %s -> %s\n' "$method" "$url" "${code:-no-response}"
  head -c 200 "$body" | tr -d '\n'
  printf '\n'
  rm -f "$body"
}
probe GET  "$APP_URL_/api/v1/plans"
probe POST "$APP_URL_/api/v1/login"

say "done — $(date -u '+%Y-%m-%d %H:%M:%SZ')"

