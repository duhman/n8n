# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Version Information
- **Current Version**: 1.94.0 (as of codebase)
- **Latest Available**: 1.94.1 (patch release with bug fixes)
- **2025 Status**: Active development with $60M funding round, 66k+ GitHub stars

## Essential Commands

### Development
```bash
# Install dependencies (requires pnpm 10.2.1+)
pnpm install

# Run the full development environment (backend + frontend)
pnpm dev

# Run only backend services
pnpm dev:be

# Run only frontend editor
pnpm dev:fe

# Run with AI/LangChain nodes
pnpm dev:ai

# Run specific services
pnpm start        # Start n8n server
pnpm webhook      # Start webhook server
pnpm worker       # Start worker process
```

### Build
```bash
# Build all packages
pnpm build

# Build specific parts
pnpm build:backend
pnpm build:frontend
pnpm build:nodes
```

### Testing
```bash
# Run all tests
pnpm test

# Run specific test suites
pnpm test:backend
pnpm test:frontend
pnpm test:nodes

# Run tests in watch mode (in specific package)
pnpm test:dev

# Run E2E tests
cd cypress && pnpm run test:e2e:dev
```

### Code Quality
```bash
# Type checking
pnpm typecheck

# Linting
pnpm lint
pnpm lintfix

# Format code
pnpm format
pnpm format:check

# Run both lint and typecheck (recommended before commits)
pnpm lint && pnpm typecheck
```

### Utility Commands
```bash
# Clean build artifacts
pnpm clean

# Reset the project (clean install)
pnpm reset

# Watch mode for development
pnpm watch
```

## Architecture Overview

n8n is a monorepo using pnpm workspaces and Turbo for build orchestration. The codebase is organized into several key packages:

### Core Packages

**`packages/cli`** - Main n8n CLI application and server
- Entry point for the n8n application
- Handles HTTP server, webhooks, and worker processes
- Contains API endpoints, controllers, and services
- Database migrations and models

**`packages/core`** - Core workflow execution engine
- Node execution logic
- Workflow runner and execution handling
- Credential management
- Binary data handling

**`packages/workflow`** - Workflow data structures and utilities
- Workflow and node type definitions
- Expression evaluation engine
- Data transformation utilities
- Type validation

**`packages/nodes-base`** - Built-in node implementations
- All standard n8n nodes (400+ integrations)
- Credential types for services
- Node versioning system

### Frontend Packages

**`packages/editor-ui`** - Vue.js workflow editor UI
- Main visual workflow editor
- Node configuration panels
- Execution history and debugging tools
- Uses Vue 3, Pinia for state management, and Vue Flow for canvas

**`packages/design-system`** - Shared UI components
- Reusable Vue components
- n8n's design tokens and styling
- Based on Element Plus

### Supporting Packages

**`packages/@n8n/*`** - Shared utilities and configurations
- `api-types` - TypeScript interfaces for API
- `config` - Configuration management
- `client-oauth2` - OAuth2 client implementation
- `permissions` - RBAC permission system
- `nodes-langchain` - AI/LangChain integration nodes

### Key Technical Details

1. **Database Support**: SQLite (default), PostgreSQL, MySQL/MariaDB
2. **Node.js Requirements**: >=20.15 (supports v20 and v22 LTS - recommended for 2025)
3. **Build System**: Turbo for parallel builds, TypeScript for all packages
4. **Testing**: Jest for unit tests, Cypress for E2E tests
5. **Code Style**: ESLint for linting, Biome + Prettier for formatting
6. **State Management**: Pinia stores in frontend (official Vue.js state management)
7. **Workflow Canvas**: Vue Flow (based on React Flow concepts)
8. **Frontend Stack**: Vue 3.5+, Vite 6+, TypeScript 5.8+
9. **AI Integration**: LangChain support with 400+ integrations

### Development Workflow

1. Most development work involves:
   - Adding/modifying nodes in `packages/nodes-base`
   - Implementing API endpoints in `packages/cli/src`
   - Creating UI features in `packages/editor-ui`
   - Core execution changes in `packages/core` or `packages/workflow`

2. The build system uses Turbo, which handles dependencies automatically:
   - Running `pnpm build` builds all packages in correct order
   - Development mode (`pnpm dev`) watches for changes

3. When working with nodes:
   - Node definitions are in `packages/nodes-base/nodes/`
   - Credentials are in `packages/nodes-base/credentials/`
   - Each node can have multiple versions for backward compatibility

4. Frontend development:
   - Vue 3 Composition API is preferred
   - Components use TypeScript with proper typing
   - Pinia stores handle global state
   - Design system components should be used when available

### Testing Guidelines

- Unit tests are colocated with source files
- E2E tests are in the `cypress/` directory
- Run tests before submitting changes
- Mock external services in tests
- Use `jest.mock()` for module mocking

### Important Configuration Files

- `turbo.json` - Build pipeline configuration
- `pnpm-workspace.yaml` - Workspace package definitions
- `tsconfig.json` - Base TypeScript configuration
- `jest.config.js` - Jest test configuration
- `biome.jsonc` - Code formatting rules