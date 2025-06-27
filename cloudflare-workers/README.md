# Cloudflare Workers Integration for n8n

This directory contains Cloudflare Workers that enhance your n8n workflows with edge computing capabilities, providing 0ms cold start times and global distribution.

## Architecture Overview

```
Notion Webhook → Cloudflare Worker → n8n → OpenAI → Slack
     ↓              ↓                 ↓       ↓       ↓
  Validates     Processes         Formats   AI      Team
  Signature     Data              Data    Summary  Notify
```

## Features

### 🚀 **High Performance**
- 0ms cold start (vs 500ms-10s for traditional serverless)
- Global edge distribution (155+ data centers)
- Automatic scaling with no configuration

### 🔒 **Security**
- Webhook signature validation
- Rate limiting capabilities
- CORS handling
- Request sanitization

### 🌍 **Global Reach**
- Deploy to "Region:Earth" automatically
- No regional configuration needed
- Consistent performance worldwide

### 💰 **Cost Effective**
- Pay-per-use billing (per 10ms of runtime)
- 3x cheaper per CPU-cycle than AWS Lambda
- Free tier includes generous allowances

## Directory Structure

```
cloudflare-workers/
├── README.md                           # This file
├── notion-webhook-worker/              # Main webhook processor
│   ├── src/
│   │   └── index.js                   # Worker code
│   ├── package.json                   # Dependencies
│   ├── wrangler.toml                  # Worker configuration
│   └── .env.example                   # Environment variables template
└── docs/                              # Additional documentation
    ├── deployment.md                  # Deployment guide
    ├── testing.md                     # Testing instructions
    └── troubleshooting.md             # Common issues
```

## Quick Start

### 1. Prerequisites

- Cloudflare account with Workers enabled
- Node.js 18+ installed
- Wrangler CLI installed: `npm install -g wrangler`

### 2. Setup

```bash
# Navigate to worker directory
cd cloudflare-workers/notion-webhook-worker

# Install dependencies
npm install

# Login to Cloudflare
wrangler login

# Set environment variables
wrangler secret put N8N_WEBHOOK_URL
wrangler secret put N8N_API_KEY
wrangler secret put NOTION_WEBHOOK_SECRET
```

### 3. Deploy

```bash
# Deploy to staging
npm run deploy:staging

# Deploy to production
npm run deploy:production
```

### 4. Configure n8n

1. Import the enhanced workflow: `/test-workflows/notion-cloudflare-to-slack-workflow.json`
2. Update webhook URL to use Cloudflare Worker endpoint
3. Configure OpenAI and Slack credentials

## Worker Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `N8N_WEBHOOK_URL` | Your n8n webhook endpoint | Yes |
| `N8N_API_KEY` | n8n API key for authentication | No |
| `NOTION_WEBHOOK_SECRET` | Secret for webhook validation | Recommended |

### Wrangler Configuration

Key settings in `wrangler.toml`:

```toml
name = "notion-webhook-worker"
main = "src/index.js"
compatibility_date = "2024-06-24"

[limits]
cpu_ms = 50        # CPU time limit
memory_mb = 128    # Memory limit
```

## Available Workflows

### 1. Enhanced Notion → Slack Workflow
- **File**: `notion-cloudflare-to-slack-workflow.json`
- **Features**: Data validation, enhanced formatting, error handling
- **Webhook**: `/webhook/notion-project-done-cf`

### 2. Cloudflare Automation Suite
- **File**: `cloudflare-automation-workflows.json`
- **Features**: DNS management, cache purging, zone operations
- **Trigger**: Manual or scheduled

### 3. Security Monitoring
- **File**: `cloudflare-security-monitoring.json`
- **Features**: Threat detection, automated alerts, analytics
- **Schedule**: Every 15 minutes

## Testing

### Local Development

```bash
# Start local development server
npm run dev

# Test webhook endpoint
curl -X POST http://localhost:8787 \\
  -H "Content-Type: application/json" \\
  -d '{"projectName": "Test Project", "notionId": "123"}'
```

### Production Testing

```bash
# View real-time logs
npm run tail

# Test production endpoint
curl -X POST https://notion-webhook-worker.your-subdomain.workers.dev \\
  -H "Content-Type: application/json" \\
  -d '{"projectName": "Test Project", "notionId": "123"}'
```

## Deployment Strategies

### 1. Gradual Rollout (Recommended)

```bash
# Deploy to 5% of traffic
wrangler deploy --compatibility-date 2024-06-24 --percentage 5

# Monitor performance and errors
wrangler tail --format=pretty

# Increase to 100% if stable
wrangler deploy --compatibility-date 2024-06-24 --percentage 100
```

### 2. Blue-Green Deployment

```bash
# Deploy to staging environment
wrangler deploy --env staging

# Test staging thoroughly
curl -X POST https://notion-webhook-worker-staging.your-subdomain.workers.dev

# Switch to production
wrangler deploy --env production
```

## Monitoring & Analytics

### Built-in Metrics

- Request count and response times
- Error rates and status codes
- CPU and memory usage
- Geographic distribution

### Custom Logging

```javascript
// Add to worker code for detailed logging
console.log('Processing webhook:', {
  notionId: data.id,
  timestamp: new Date().toISOString(),
  userAgent: request.headers.get('User-Agent')
});
```

### Alerting

Set up alerts in Cloudflare Dashboard:
- Error rate > 5%
- Response time > 1000ms
- Request rate > 1000/min

## Security Best Practices

### 1. Webhook Validation

```javascript
// Always validate webhook signatures
if (!await validateNotionSignature(body, signature, secret)) {
  return new Response('Invalid signature', { status: 401 });
}
```

### 2. Rate Limiting

```javascript
// Implement basic rate limiting
const rateLimitKey = `rate_limit:${clientIP}`;
const requests = await env.KV.get(rateLimitKey);
if (requests && parseInt(requests) > 100) {
  return new Response('Rate limited', { status: 429 });
}
```

### 3. Input Sanitization

```javascript
// Sanitize all inputs
const sanitizedData = {
  projectName: sanitize(data.projectName),
  description: sanitize(data.description)
};
```

## Cost Optimization

### 1. Efficient Resource Usage

- Keep worker execution time under 50ms
- Use streaming for large responses
- Implement caching for repeated requests

### 2. Monitoring Costs

```bash
# View usage statistics
wrangler analytics --days 30

# Monitor billing
wrangler billing usage
```

### 3. Auto-scaling Configuration

```toml
# In wrangler.toml
[limits]
cpu_ms = 30          # Reduce for simple operations
memory_mb = 64       # Minimize memory usage
```

## Advanced Features

### 1. Container Integration (Future)

When containers become available in June 2025:

```toml
# Container configuration
[containers.image-processor]
image = "n8n-image-processor:latest"
port = 8080
sleep_timeout = 60
```

### 2. Durable Objects (State Management)

```javascript
// For stateful operations
export class WebhookState {
  constructor(state, env) {
    this.state = state;
  }
  
  async fetch(request) {
    // Implement stateful logic
  }
}
```

### 3. KV Storage (Caching)

```javascript
// Cache frequent requests
const cachedResponse = await env.WEBHOOK_CACHE.get(cacheKey);
if (cachedResponse) {
  return new Response(cachedResponse);
}
```

## Troubleshooting

### Common Issues

1. **Worker timeout**: Reduce processing time or increase limits
2. **Memory errors**: Optimize data structures and reduce memory usage
3. **Rate limiting**: Implement proper rate limiting and error handling

### Debug Commands

```bash
# View worker logs
wrangler tail --format=pretty

# Check worker status
wrangler whoami

# Validate configuration
wrangler publish --dry-run
```

### Performance Monitoring

```bash
# Analyze performance metrics
wrangler analytics --days 7

# Monitor error rates
wrangler tail --grep "error"
```

## Migration from Traditional Hosting

### 1. Gradual Migration

1. Deploy Worker alongside existing infrastructure
2. Route 10% of traffic to Worker
3. Monitor performance and errors
4. Gradually increase traffic percentage
5. Fully migrate when confident

### 2. Rollback Strategy

```bash
# Quick rollback to previous version
wrangler rollback

# Route traffic back to original system
# (Update DNS or load balancer)
```

## Support & Resources

- [Cloudflare Workers Documentation](https://developers.cloudflare.com/workers/)
- [n8n Community Forum](https://community.n8n.io/)
- [Wrangler CLI Reference](https://developers.cloudflare.com/workers/wrangler/)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes locally
4. Submit a pull request with detailed description

## License

This project is licensed under the MIT License - see the LICENSE file for details.