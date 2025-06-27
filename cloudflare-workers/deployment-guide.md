# Cloudflare Workers Deployment Guide

This guide provides step-by-step instructions for deploying and configuring Cloudflare Workers with your n8n instance.

## Prerequisites

Before starting, ensure you have:

- [x] Cloudflare account (free tier works)
- [x] Domain managed by Cloudflare (optional but recommended)
- [x] Node.js 18+ installed
- [x] n8n instance running (local or remote)
- [x] Basic familiarity with command line

## Step 1: Install Wrangler CLI

```bash
# Install globally
npm install -g wrangler

# Verify installation
wrangler --version

# Login to Cloudflare
wrangler login
```

## Step 2: Set Up Worker Project

```bash
# Navigate to the worker directory
cd /path/to/n8n/cloudflare-workers/notion-webhook-worker

# Install dependencies
npm install

# Copy environment template
cp .env.example .env
```

## Step 3: Configure Environment Variables

### Option A: Using Wrangler Secrets (Recommended for Production)

```bash
# Set n8n webhook URL
wrangler secret put N8N_WEBHOOK_URL
# Enter: http://localhost:5678/webhook/notion-project-done-cf
# or: https://your-n8n-instance.com/webhook/notion-project-done-cf

# Set optional API key for n8n authentication
wrangler secret put N8N_API_KEY
# Enter your n8n API key if using authentication

# Set Notion webhook secret for signature validation
wrangler secret put NOTION_WEBHOOK_SECRET
# Enter a strong secret that you'll also configure in Notion
```

### Option B: Using .env File (Development Only)

```bash
# Edit .env file
nano .env
```

Add your values:
```env
N8N_WEBHOOK_URL=http://localhost:5678/webhook/notion-project-done-cf
N8N_API_KEY=your-n8n-api-key
NOTION_WEBHOOK_SECRET=your-webhook-secret
```

## Step 4: Test Locally

```bash
# Start local development server
npm run dev

# In another terminal, test the webhook
curl -X POST http://localhost:8787 \\
  -H "Content-Type: application/json" \\
  -H "X-Notion-Signature: test-signature" \\
  -d '{
    "id": "test-123",
    "properties": {
      "Name": {
        "title": [{"plain_text": "Test Project"}]
      },
      "Status": {
        "select": {"name": "Done"}
      },
      "Description": {
        "rich_text": [{"plain_text": "Test project description"}]
      }
    }
  }'
```

Expected response:
```json
{
  "success": true,
  "message": "Webhook processed successfully",
  "timestamp": "2024-06-24T12:00:00.000Z"
}
```

## Step 5: Deploy to Staging

```bash
# Deploy to staging environment
npm run deploy:staging

# Test staging deployment
curl -X POST https://notion-webhook-worker-staging.your-subdomain.workers.dev \\
  -H "Content-Type: application/json" \\
  -d '{"projectName": "Staging Test", "notionId": "test-123"}'
```

## Step 6: Import Enhanced n8n Workflow

1. Open your n8n instance (http://localhost:5678)
2. Go to **Workflows** → **Import from File**
3. Select `/test-workflows/notion-cloudflare-to-slack-workflow.json`
4. Configure credentials:
   - **OpenAI**: Add your API key
   - **Slack**: Set up OAuth2 integration
5. Update the Slack channel ID in the workflow
6. **Activate** the workflow

## Step 7: Update Webhook URL in n8n

1. Open the imported workflow
2. Click on the **"Cloudflare Webhook"** node
3. Update the path to match your Worker endpoint:
   - **Local testing**: Use the original n8n webhook
   - **Production**: Update to point to your Cloudflare Worker

## Step 8: Production Deployment

### Pre-deployment Checklist

- [x] Staging tests passing
- [x] n8n workflow configured and active
- [x] OpenAI and Slack credentials working
- [x] Environment variables set correctly
- [x] Monitoring alerts configured

### Deploy

```bash
# Deploy to production
npm run deploy:production

# Verify deployment
wrangler list

# Check worker status
curl -X GET https://notion-webhook-worker.your-subdomain.workers.dev/health
```

## Step 9: Configure Custom Domain (Optional)

### Method 1: Using Wrangler

```bash
# Add custom domain
wrangler route add "webhook.yourdomain.com/*" notion-webhook-worker

# Verify routing
wrangler route list
```

### Method 2: Using Cloudflare Dashboard

1. Go to **Workers & Pages** → **your-worker**
2. Click **Settings** → **Triggers**
3. Click **Add Custom Domain**
4. Enter your domain: `webhook.yourdomain.com`
5. Click **Add Custom Domain**

## Step 10: Set Up Notion Integration

### Option A: Using Notion API + Automation Platform

1. **Create Notion Integration**:
   - Go to https://developers.notion.com/
   - Create a new integration
   - Get the integration token

2. **Set up automation** (using Zapier, Make.com, or custom script):
   - **Trigger**: When page status changes to "Done"
   - **Action**: Send POST request to your Cloudflare Worker
   - **URL**: `https://your-worker.workers.dev` or `https://webhook.yourdomain.com`

### Option B: Manual Testing

```bash
# Test with sample Notion webhook payload
curl -X POST https://your-worker.workers.dev \\
  -H "Content-Type: application/json" \\
  -H "X-Notion-Signature: $(echo -n 'webhook-body' | openssl dgst -sha256 -hmac 'your-secret' -binary | base64)" \\
  -d '{
    "id": "notion-page-id-123",
    "properties": {
      "Name": {
        "title": [{"plain_text": "My Completed Project"}]
      },
      "Status": {
        "select": {"name": "Done"}
      },
      "Description": {
        "rich_text": [{"plain_text": "Project completed successfully with all deliverables met."}]
      },
      "Team Members": {
        "multi_select": [
          {"name": "Alice Johnson"},
          {"name": "Bob Smith"}
        ]
      },
      "Deliverables": {
        "multi_select": [
          {"name": "Frontend Implementation"},
          {"name": "API Documentation"},
          {"name": "User Testing"}
        ]
      }
    },
    "url": "https://notion.so/notion-page-id-123"
  }'
```

## Step 11: Monitor and Test

### View Real-time Logs

```bash
# Monitor worker logs
npm run tail

# Filter for errors only
wrangler tail --grep "error"

# Pretty formatted logs
wrangler tail --format=pretty
```

### Performance Monitoring

1. **Cloudflare Dashboard**:
   - Go to **Workers & Pages** → **your-worker**
   - Check **Analytics** tab for performance metrics

2. **n8n Monitoring**:
   - View **Executions** tab for workflow runs
   - Check for any failed executions

### Test Complete Flow

1. **Trigger webhook** (manual or via Notion)
2. **Check Worker logs** for processing confirmation
3. **Verify n8n execution** in the executions panel
4. **Confirm Slack message** in your designated channel

## Step 12: Additional Workflows (Optional)

Import additional Cloudflare workflows:

```bash
# Import Cloudflare automation suite
# File: /test-workflows/cloudflare-automation-workflows.json

# Import security monitoring
# File: /test-workflows/cloudflare-security-monitoring.json
```

## Troubleshooting

### Common Issues

#### 1. Worker Not Receiving Requests

**Symptoms**: No logs in `wrangler tail`

**Solutions**:
- Verify worker URL is correct
- Check DNS propagation (if using custom domain)
- Ensure worker is deployed: `wrangler list`

#### 2. n8n Webhook Failing

**Symptoms**: Worker logs show n8n request failures

**Solutions**:
- Verify n8n URL is accessible from internet
- Check n8n webhook endpoint is correct
- Ensure n8n workflow is activated

#### 3. Authentication Errors

**Symptoms**: 401/403 errors in logs

**Solutions**:
- Verify environment variables: `wrangler secret list`
- Check Notion webhook signature validation
- Ensure API keys are correct

#### 4. Memory or CPU Limits

**Symptoms**: Worker timeouts or memory errors

**Solutions**:
- Optimize worker code for efficiency
- Increase limits in `wrangler.toml`
- Reduce payload size

### Debug Commands

```bash
# Check worker configuration
wrangler show

# Validate wrangler.toml
wrangler validate

# View environment variables (names only)
wrangler secret list

# Rollback to previous version
wrangler rollback
```

### Performance Optimization

```bash
# Analyze worker performance
wrangler analytics --days 7

# Check request patterns
wrangler analytics --days 1 --format json

# Monitor resource usage
wrangler tail --grep "cpu\\|memory"
```

## Security Considerations

### 1. Environment Variables

- Use `wrangler secret` for sensitive data
- Never commit secrets to version control
- Rotate secrets regularly

### 2. Webhook Validation

- Always validate Notion webhook signatures
- Implement rate limiting for public endpoints
- Log security events for monitoring

### 3. Network Security

- Use HTTPS only for all endpoints
- Implement proper CORS headers
- Consider IP allowlisting if possible

## Scaling Considerations

### Current Limits (Beta)

- 40 GiB total memory across all Workers
- 40 total vCPUs across all Workers
- 50ms CPU time per request (configurable)

### Optimization Strategies

1. **Minimize processing time**
2. **Use caching for repeated operations**
3. **Implement proper error handling**
4. **Monitor performance metrics**

## Next Steps

After successful deployment:

1. **Set up monitoring alerts** in Cloudflare Dashboard
2. **Create backup automation** for critical workflows
3. **Document custom configurations** for your team
4. **Plan for container migration** (when available in June 2025)

## Support

If you encounter issues:

1. Check the [troubleshooting guide](#troubleshooting)
2. Review [Cloudflare Workers documentation](https://developers.cloudflare.com/workers/)
3. Join the [n8n community](https://community.n8n.io/)
4. Open an issue in the project repository