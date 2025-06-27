#!/bin/bash

# n8n Cloudflare Containers Deployment Script
set -e

echo "🚀 Deploying n8n to Cloudflare Containers..."

# Check if wrangler is installed
if ! command -v wrangler &> /dev/null; then
    echo "❌ Wrangler CLI not found. Installing..."
    npm install -g wrangler
fi

# Login to Cloudflare (if not already authenticated)
echo "🔐 Checking Cloudflare authentication..."
if ! wrangler whoami &> /dev/null; then
    echo "Please login to Cloudflare:"
    wrangler login
fi

# Set up secrets
echo "🔑 Setting up secrets..."
echo "You'll need to provide the following secrets:"

read -p "Enter your database host: " DB_HOST
wrangler secret put DB_HOST <<< "$DB_HOST"

read -p "Enter your database name: " DB_NAME
wrangler secret put DB_NAME <<< "$DB_NAME"

read -p "Enter your database user: " DB_USER
wrangler secret put DB_USER <<< "$DB_USER"

read -s -p "Enter your database password: " DB_PASSWORD
echo
wrangler secret put DB_PASSWORD <<< "$DB_PASSWORD"

# Generate encryption key if not provided
read -s -p "Enter n8n encryption key (leave empty to generate): " ENCRYPTION_KEY
echo
if [ -z "$ENCRYPTION_KEY" ]; then
    ENCRYPTION_KEY=$(openssl rand -base64 32)
    echo "Generated encryption key: $ENCRYPTION_KEY"
fi
wrangler secret put ENCRYPTION_KEY <<< "$ENCRYPTION_KEY"

read -p "Enter your domain (e.g., your-app.workers.dev): " HOST_URL
wrangler secret put HOST_URL <<< "$HOST_URL"

WEBHOOK_URL="https://$HOST_URL/webhook"
wrangler secret put WEBHOOK_URL <<< "$WEBHOOK_URL"

# Optional email configuration
read -p "Configure email? (y/n): " CONFIGURE_EMAIL
if [ "$CONFIGURE_EMAIL" = "y" ]; then
    read -p "SMTP Host: " SMTP_HOST
    wrangler secret put SMTP_HOST <<< "$SMTP_HOST"
    
    read -p "SMTP Port: " SMTP_PORT
    wrangler secret put SMTP_PORT <<< "$SMTP_PORT"
    
    read -p "SMTP User: " SMTP_USER
    wrangler secret put SMTP_USER <<< "$SMTP_USER"
    
    read -s -p "SMTP Password: " SMTP_PASS
    echo
    wrangler secret put SMTP_PASS <<< "$SMTP_PASS"
    
    read -p "Default Email: " DEFAULT_EMAIL
    wrangler secret put DEFAULT_EMAIL <<< "$DEFAULT_EMAIL"
fi

# Deploy the container
echo "🚀 Deploying container..."
wrangler deploy

echo "✅ Deployment complete!"
echo "🌍 Your n8n instance should be available at: https://$HOST_URL"
echo ""
echo "📝 Next steps:"
echo "1. Set up your external PostgreSQL database"
echo "2. Configure DNS for your custom domain (if using one)"
echo "3. Set up workflows in n8n"
echo ""
echo "💡 Useful commands:"
echo "  wrangler tail         # View logs"
echo "  wrangler secret list  # List secrets"
echo "  wrangler deploy       # Redeploy"
