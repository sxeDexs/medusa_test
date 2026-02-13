#!/bin/sh
set -e

cd /server/.medusa/server || { echo ".medusa/server not found"; exit 1; }

echo "Running database migrations..."
npx medusa db:migrate

if [ -n "$MEDUSA_ADMIN_EMAIL" ] && [ -n "$MEDUSA_ADMIN_PASSWORD" ]; then
  echo "Ensuring admin user exists..."
  npx medusa user -e "$MEDUSA_ADMIN_EMAIL" -p "$MEDUSA_ADMIN_PASSWORD" || true
fi

echo "Starting Medusa production server..."
exec npm run start
