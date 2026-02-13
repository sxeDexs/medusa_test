#!/bin/sh

# Run migrations and start server
echo "Running database migrations..."
npx medusa db:migrate

echo "Ensuring admin user exists..."
npx medusa user -e admin@test.com -p supersecret 2>/dev/null || echo "Admin already exists"

echo "Seeding database..."
npm run seed || echo "Seeding failed, continuing..."

echo "Starting Medusa development server..."
npm run dev