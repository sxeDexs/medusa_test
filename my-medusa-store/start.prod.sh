#!/bin/sh
set -e

echo "Running database migrations..."
npx medusa db:migrate

if [ -n "$MEDUSA_ADMIN_EMAIL" ] && [ -n "$MEDUSA_ADMIN_PASSWORD" ]; then
  echo "Ensuring admin user exists..."
  npx medusa user -e "$MEDUSA_ADMIN_EMAIL" -p "$MEDUSA_ADMIN_PASSWORD" || true
fi

echo "Copying admin build to expected location..."
mkdir -p /server/build/admin
cp -r /server/.medusa/server/public/admin/* /server/build/admin/ 2>/dev/null || true

echo "Starting Medusa production server..."
exec npm run start
