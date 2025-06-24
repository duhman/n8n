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
```bash
# Fetch and merge upstream changes
git fetch upstream
git merge upstream/master
git push origin master

# Or use rebase for cleaner history
git fetch upstream
git rebase upstream/master
git push origin master
```

See `SYNC_UPSTREAM.md` for detailed sync workflow and conflict resolution.

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