# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## n8n Architecture Overview

n8n is a workflow automation platform built as a monorepo using pnpm workspaces and Turbo. The codebase is primarily TypeScript with a Vue.js frontend.

### Key Architectural Components

1. **Frontend (Vue.js)**
   - `/packages/editor-ui` - Main workflow editor UI
   - `/packages/@n8n/design-system` - Reusable Vue components
   - Uses Pinia for state management, Vue Router for routing

2. **Backend (Node.js/TypeScript)**
   - `/packages/cli` - Main CLI that runs both frontend and backend
   - `/packages/core` - Core workflow execution engine
   - `/packages/workflow` - Shared workflow interfaces between frontend/backend
   - Uses TypeORM for database operations, Bull for queue management

3. **Nodes System**
   - `/packages/nodes-base` - 400+ built-in integration nodes
   - `/packages/@n8n/nodes-langchain` - AI/LangChain integration nodes
   - Each node is a self-contained TypeScript class implementing INodeType

4. **Database Layer**
   - `/packages/@n8n/db` - Database abstraction layer
   - Supports PostgreSQL, MySQL, MariaDB, SQLite
   - Uses TypeORM with migrations

## Essential Development Commands

```bash
# Initial setup
pnpm install          # Install all dependencies
pnpm build           # Build all packages (required before first run)

# Development
pnpm dev             # Start full dev environment (frontend + backend)
pnpm dev:be          # Backend only development
pnpm dev:fe          # Frontend only development

# Testing
pnpm test            # Run all tests
pnpm test:backend    # Backend tests only
pnpm test:frontend   # Frontend tests only
pnpm test:e2e:dev    # Interactive E2E tests (Cypress)

# Code quality (ALWAYS run before committing)
pnpm lint            # Run linting
pnpm lintfix         # Auto-fix linting issues
pnpm typecheck       # TypeScript type checking
pnpm format          # Format code with Biome

# Building
pnpm build:backend   # Build backend packages
pnpm build:frontend  # Build frontend packages
pnpm build:nodes     # Build node packages

# Running n8n
pnpm start           # Start n8n normally
pnpm start:tunnel    # Start with tunnel for webhook testing
```

## Creating or Modifying Nodes

1. Node files are in `/packages/nodes-base/nodes/[ServiceName]/`
2. Each node extends `INodeType` interface
3. Use existing nodes as reference (e.g., `/packages/nodes-base/nodes/Github/`)
4. After creating a node:
   - Add it to `/packages/nodes-base/package.json` in the `n8n.nodes` array
   - Run `pnpm build:nodes` to compile
   - Restart n8n to see the new node

## Testing Approach

- **Unit tests**: Located alongside source files as `*.test.ts`
- **E2E tests**: In `/cypress/e2e/` directory
- Test single file: `pnpm test -- path/to/file.test.ts`
- Test with watch: `pnpm test -- --watch path/to/file.test.ts`

## Database Operations

- Migrations are in `/packages/cli/src/databases/migrations/`
- Use TypeORM for database operations
- Access database through `Db` class from `@n8n/db`

## Frontend Development

- State management: Pinia stores in `/packages/editor-ui/src/stores/`
- Components: Vue 3 composition API
- Styling: SCSS modules, design tokens from design-system package
- API calls: Use `api` service from `/packages/editor-ui/src/api/`

## Important Patterns

1. **Workflow Execution**: Workflows are JSON structures executed by the core engine
2. **Node Communication**: Nodes communicate via `INodeExecutionData` interfaces
3. **Credential Handling**: Credentials are encrypted and stored separately from workflows
4. **Event System**: Uses event emitters for workflow lifecycle events
5. **Queue System**: Bull queues for scaling execution across workers

## Environment Setup

- Node.js 22.16+ required
- pnpm 10.2.1+ (use corepack: `corepack enable`)
- Set `N8N_ENCRYPTION_KEY` for credential encryption
- Default port: 5678

## Debugging

VS Code launch configurations available for:

- `Launch n8n with debug` - Full application debugging
- `Launch n8n CLI with debug` - CLI-specific debugging
- `Attach to running n8n` - Attach to existing process

## Common Issues

1. **Build failures**: Always run `pnpm install` and `pnpm build` after pulling changes
2. **Type errors**: Run `pnpm typecheck` to catch TypeScript issues
3. **Linting errors**: Use `pnpm lintfix` to auto-fix most issues
4. **Test failures**: Ensure database migrations are up to date

## Code Style

- TypeScript strict mode enabled
- Follow existing patterns in the codebase
- Use dependency injection where possible
- Avoid direct database queries outside of repositories
- Keep nodes self-contained and testable

## Production Deployment

A production-ready Docker setup with PostgreSQL is available in `/n8n-production/`:

### Production Setup Commands

```bash
# Navigate to production directory
cd n8n-production

# Option 1: Use setup script (recommended)
./setup.sh

# Option 2: Manual setup
cp .env.example .env
# Edit .env with your configuration
docker compose up -d

# Access n8n at http://localhost:5678
```

### Production Features

- **PostgreSQL database** for data persistence and performance
- **Automated backups** with `./backup.sh` script
- **Secure configuration** with generated encryption keys
- **Docker Compose** orchestration for easy deployment
- **Environment-based configuration** for different deployments
- **Resource limits** and health checks for stability

### Production Files

- `docker-compose.yml` - Main orchestration configuration
- `.env` - Environment variables (git-ignored)
- `.env.example` - Configuration template
- `backup.sh` - Automated backup script
- `restore.sh` - Restore from backup script
- `setup.sh` - Interactive setup wizard
- `README.md` - Complete production documentation

### Important Environment Variables

- `N8N_ENCRYPTION_KEY` - Must be consistent across deployments
- `POSTGRES_PASSWORD` - Strong database password
- `N8N_HOST` - Your domain for webhooks
- `WEBHOOK_URL` - Full webhook URL for external services

### Docker Commands (if Docker not in PATH)

Use full path: `/Applications/Docker.app/Contents/Resources/bin/docker`

## Fork and Upstream Sync

This repository is a fork of the original n8n repository. Git remotes are configured as:

- **origin**: `https://github.com/duhman/n8n.git` (this fork)
- **upstream**: `https://github.com/n8n-io/n8n.git` (original n8n repo)

### Regular Sync Commands

**Quick Sync** (when no conflicts expected):

```bash
git fetch upstream
git merge upstream/master
git push origin master
```

**Safe Sync with Review**:

```bash
git fetch upstream
git log --oneline HEAD..upstream/master  # Review changes
git merge upstream/master                 # Merge
git push origin master                   # Push to your fork
```

**Alternative with Rebase** (cleaner history):

```bash
git fetch upstream
git rebase upstream/master
git push origin master
```

### Production Setup Protection

Your `/n8n-production/` directory is safe from conflicts because:

- Isolated custom directory not present in upstream
- Independent Docker configuration
- Custom documentation tracked separately

### Maintenance Schedule

- **Weekly/Monthly**: Sync with upstream for updates
- **After Sync**: Test production setup with `docker compose restart`
- **On Conflicts**: Usually in README.md or docs - keep your production changes

See `SYNC_UPSTREAM.md` for detailed workflow, conflict resolution, and automation scripts.

## Hetzner Cloud Deployment

A complete automated deployment solution for Hetzner Cloud is available in `/hetzner-setup/`:

### Deployment Process

```bash
# On fresh Hetzner Ubuntu server
git clone https://github.com/duhman/n8n.git /opt/setup
cd /opt/setup/hetzner-setup
chmod +x *.sh

# 1. Initial server setup (Docker, firewall, security)
./initial-setup.sh

# 2. Deploy n8n with production configuration
./deploy-n8n.sh

# 3. Configure DNS A record pointing to server IP

# 4. Add SSL certificate and security hardening
./secure-server.sh

# 5. Set up automated backups
./backup-setup.sh
```

### Hetzner Features

- **Complete automation**: One-command server preparation and deployment
- **SSL/TLS**: Automatic Let's Encrypt certificate with auto-renewal
- **Security hardening**: UFW firewall, fail2ban, SSH key-only authentication
- **Monitoring**: Log analysis, intrusion detection, security checks
- **Backups**: Automated daily backups with Hetzner Storage Box integration
- **Production ready**: PostgreSQL, Nginx reverse proxy, systemd services

### Cost: €5.83-11.27/month for VPS + €3.36/month for Storage Box

## n8n API Integration

### API Authentication

n8n provides a REST API for programmatic workflow management:

```bash
# API endpoint: https://your-domain.com/api/v1
# Authentication: X-N8N-API-KEY header

# Example API calls
curl -X GET https://n8n.whatisspeed.com/api/v1/workflows \
  -H "X-N8N-API-KEY: your-api-key-here"
```

### Common API Operations

**Workflow Management:**

- `GET /api/v1/workflows` - List all workflows
- `POST /api/v1/workflows` - Create new workflow
- `PUT /api/v1/workflows/{id}` - Update workflow
- `DELETE /api/v1/workflows/{id}` - Delete workflow
- `POST /api/v1/workflows/{id}/execute` - Execute workflow

**Credentials Management:**

- `GET /api/v1/credentials` - List credentials
- `POST /api/v1/credentials` - Create credential

**Executions:**

- `GET /api/v1/executions` - List executions
- `GET /api/v1/executions/{id}` - Get execution details

### API Key Generation

1. Login to n8n web interface
2. Go to **Settings** → **API Keys**
3. Create new API key with appropriate permissions
4. Use in requests via `X-N8N-API-KEY` header

### Python Integration Example

```python
import requests

class N8nAPI:
    def __init__(self, base_url, api_key):
        self.base_url = base_url
        self.headers = {
            "X-N8N-API-KEY": api_key,
            "Content-Type": "application/json"
        }

    def list_workflows(self):
        response = requests.get(f"{self.base_url}/api/v1/workflows", headers=self.headers)
        return response.json()

    def execute_workflow(self, workflow_id, data=None):
        url = f"{self.base_url}/api/v1/workflows/{workflow_id}/execute"
        response = requests.post(url, headers=self.headers, json=data or {})
        return response.json()

# Usage
api = N8nAPI("https://n8n.whatisspeed.com", "your-api-key")
workflows = api.list_workflows()
```

## Project Context and Memory

- We are working on n8n, an open-source workflow automation platform
- A production deployment setup has been implemented with Docker + PostgreSQL
- The goal is to create a flexible, extensible tool for connecting various services and automating workflows
- Key focus areas include:
  - Expanding node integrations
  - Improving developer experience
  - Enhancing performance and scalability
  - Maintaining high code quality and test coverage
  - Production-ready deployment capabilities

## Recent Actions and Decisions

- Implemented a comprehensive production deployment setup with Docker and PostgreSQL
- Successfully deployed n8n on Hetzner Cloud with complete automation scripts
- Created Cloudflare Containers deployment option for serverless hosting
- Explored strategies for syncing with the upstream n8n repository
- Focused on creating a flexible and extensible workflow automation platform
- Prioritized code quality, testing, and developer experience in the project
- Successfully configured production instance with SSL, security hardening, and backups
- **NEW**: Developed comprehensive Linear-Notion sync solution with real-time bidirectional synchronization

## Linear-Notion Integration

A complete project synchronization system has been implemented in `/linear-notion-sync/`:

### Sync Capabilities

- **Real-time Linear → Notion sync** via webhooks for instant updates
- **Bidirectional Notion → Linear sync** with polling-based change detection
- **Initial data import** for existing Linear project issues
- **Comprehensive error handling** with intelligent retry logic
- **Health monitoring** with daily reports and alerts

### Key Components

1. **Workflows** (`/linear-notion-sync/workflows/`):
   - `linear-to-notion-sync.json` - Real-time webhook-based sync
   - `notion-to-linear-sync.json` - Polling-based reverse sync
   - `initial-import.json` - One-time data backfill
   - `error-handling-subworkflow.json` - Error handling & monitoring
   - `health-monitoring.json` - System health checks

2. **Configuration** (`/linear-notion-sync/config/`):
   - `workflow-config.js` - Centralized configuration management
   - Field mappings for status, priority, and assignee synchronization
   - Environment variable definitions and security settings

3. **Documentation**:
   - `README.md` - Complete feature documentation
   - `setup-guide.md` - Step-by-step implementation guide
   - `IMPLEMENTATION_SUMMARY.md` - Technical overview and architecture

### Features

- **Data Integrity**: Conflict prevention with timestamp-based change detection
- **Performance**: Batch processing, rate limit compliance, incremental sync
- **Reliability**: Automatic retry logic, error classification, and recovery
- **Monitoring**: Real-time health checks, performance metrics, and alerting
- **Security**: Secure credential management and optional webhook verification

### Database Schema

The Notion database includes:

- Project tracking fields (Title, Status, Priority, Assignee)
- Linear integration fields (Linear ID, URL, External ID)
- Sync management fields (Last Sync, Progress calculation)
- Metadata fields (Created/Updated dates, Cycle, Team)

### Usage

After setup, the system provides:

- Instant reflection of Linear changes in Notion
- Progress tracking with calculated completion percentages
- Bidirectional updates maintaining data consistency
- Comprehensive error handling with automatic recovery
- Health monitoring with proactive alerts

## Initial Codebase Analysis and Understanding

- Thoroughly analyzed the n8n monorepo architecture and development workflows
- Recognized the modular design with separate packages for core functionality
- Identified key architectural components like nodes system, frontend, and backend
- Understood the importance of TypeScript, Vue.js, and the plugin-based node integration system
- Appreciated the comprehensive testing and development infrastructure
