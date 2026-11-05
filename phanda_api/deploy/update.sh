#!/bin/bash
#
# Kuphanda API — update an existing install.
#
# deploy.sh is the first-run script: it creates the database, writes .env and
# copies the document root. This is the everyday one: pull, refresh the
# autoloader, migrate, sync the catalogue, fix the two .env values a script
# cannot guess, and report what is live.
#
# Safe to re-run. Refuses to continue past a failed pull or migration rather
# than leaving a half-updated checkout.
#
#   bash deploy/update.sh
#
# Override the path if the account layout differs:
#   REPO_DIR=/home/kuphanda/kuphanda bash deploy/update.sh

set -uo pipefail

REPO_DIR=${REPO_DIR:-/home/kuphanda/kuphanda}
API_DIR="$REPO_DIR/phanda_api"
APP_URL_=${APP_URL_:-https://app.kuphanda.com}

# The Web client from the Firebase project: the audience the app sends when it
# signs in with Google. Without it /auth/google answers 503.
GOOGLE_CLIENT_ID_=${GOOGLE_CLIENT_ID_:-239327365893-1725f6in8f6nnmc85836eqhrets9hfes.apps.googleusercontent.com}

say() { printf '\n== %s\n' "$*"; }
die() { printf '\nFATAL: %s\n' "$*"; exit 1; }

cd "$REPO_DIR" 2>/dev/null || die "$REPO_DIR not found"

say "pull"
git pull origin main || die "git pull failed — nothing else was changed"

cd "$API_DIR" || die "$API_DIR not found"

say "composer"
composer install --no-dev --optimize-autoloader --no-interaction 2>&1 | tail -3

say "env"
if ! grep -q '^GOOGLE_CLIENT_ID=' .env 2>/dev/null; then
  printf '\nGOOGLE_CLIENT_ID=%s\n' "$GOOGLE_CLIENT_ID_" >> .env
  echo "added GOOGLE_CLIENT_ID"
else
  echo "GOOGLE_CLIENT_ID already set"
fi

# WhatsApp sign-in codes. The values come from the operator, never from the
# script: a missing token means phone sign-in answers 503 and email/Google keep
# working, which is a safe default but a silent one — so it is said out loud.
if ! grep -q '^WHATSAPP_PHONE_NUMBER_ID=' .env 2>/dev/null; then
  if [ -n "${WHATSAPP_PHONE_NUMBER_ID_:-}" ] && [ -n "${WHATSAPP_TOKEN_:-}" ]; then
    {
      printf '\n# WhatsApp Cloud API — phone sign-in codes\n'
      printf 'WHATSAPP_PHONE_NUMBER_ID=%s\n' "$WHATSAPP_PHONE_NUMBER_ID_"
      printf 'WHATSAPP_TOKEN=%s\n' "$WHATSAPP_TOKEN_"
      printf 'WHATSAPP_OTP_TEMPLATE=%s\n' "${WHATSAPP_OTP_TEMPLATE_:-kuphanda_auth_code}"
      printf 'WHATSAPP_OTP_LANGUAGE=%s\n' "${WHATSAPP_OTP_LANGUAGE_:-en_US}"
      printf 'WHATSAPP_API_VERSION=%s\n' "${WHATSAPP_API_VERSION_:-v21.0}"
      printf 'WHATSAPP_OTP_CODE_BUTTON=%s\n' "${WHATSAPP_OTP_CODE_BUTTON_:-true}"
    } >> .env
    echo "added WhatsApp credentials"
  else
    echo "WHATSAPP_* not set — phone sign-in will answer 503 (email and Google still work)"
  fi
else
  echo "WHATSAPP_* already set"
fi

# Mailtrap's sandbox is not reachable from this host, so an smtp mailer with
# empty credentials makes every sign-up wait for a timeout and then 500.
if grep -q '^MAIL_MAILER=smtp$' .env 2>/dev/null; then
  sed -i 's/^MAIL_MAILER=smtp$/MAIL_MAILER=log/' .env
  echo "MAIL_MAILER=smtp -> log (no credentials file to send with)"
fi

say "migrate"
php artisan config:clear >/dev/null 2>&1
php artisan migrate --force 2>&1 | tail -5 || die "migration failed"

say "catalogue"
php artisan library:sync --prune 2>&1 | tail -8

say "record what is live"
git -C "$REPO_DIR" rev-parse --short HEAD > storage/app/current-commit

say "caches"
php artisan config:cache 2>&1 | tail -1

say "health"
curl -s --max-time 20 "$APP_URL_/api/v1/health"
printf '\n'

say "done — $(date -u '+%Y-%m-%d %H:%M:%SZ')"
