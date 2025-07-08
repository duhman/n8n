# Copilot Instructions for n8n Monorepo

This guide provides essential context and actionable rules for AI coding agents working in the n8n codebase. It is tailored for this fork, which includes custom production, deployment, and integration features.

## Architecture Overview
- **Monorepo** managed with pnpm workspaces and Turbo.
- **Backend:** `/packages/cli` (entrypoint), `/packages/core` (engine), `/packages/workflow` (shared types), `/packages/nodes-base` (built-in nodes), `/packages/@n8n/db` (ORM/database).
- **Frontend:** `/packages/editor-ui` (Vue 3, Pinia, SCSS), `/packages/@n8n/design-system` (UI components).
- **Nodes:** Each node is a TypeScript class in `/packages/nodes-base/nodes/[Service]/`, implements `INodeType`.
- **Production:** `/n8n-production/` (Docker Compose, PostgreSQL, backup/restore scripts, setup wizard).
- **Integrations:** `/linear-notion-sync/` (real-time Linear↔Notion sync), `/cloudflare-workers/` (serverless edge integrations).

## Key Workflows & Commands
- **Setup:** `pnpm install` → `pnpm build` (always after pulling changes)
- **Dev:** `pnpm dev` (full stack), `pnpm dev:be`, `pnpm dev:fe`
- **Test:** `pnpm test`, `pnpm test:backend`, `pnpm test:frontend`, `pnpm test:e2e:dev`
- **Lint/Format:** `pnpm lint`, `pnpm lintfix`, `pnpm typecheck`, `pnpm format`
- **Production:** See `/n8n-production/README.md` and run `./setup.sh`
- **Sync with upstream:** See `SYNC_UPSTREAM.md` for safe merge/rebase steps

## Project-Specific Patterns
- **Node Development:**
  - Reference `/packages/nodes-base/nodes/Github/` for structure.
  - Register new nodes in `nodes-base/package.json`.
  - Run `pnpm build:nodes` after changes.
- **Testing:**
  - Unit tests: `*.test.ts` near source.
  - E2E: `/cypress/e2e/`.
  - Use `pnpm test -- path/to/file.test.ts` for single tests.
- **Database:**
  - Use TypeORM via `@n8n/db`.
  - Migrations: `/packages/cli/src/databases/migrations/`.
- **Frontend:**
  - State: Pinia stores in `/editor-ui/src/stores/`.
  - API: Use `/editor-ui/src/api/` service.
- **Credentials:**
  - Encrypted, managed separately from workflows.
- **Events/Queues:**
  - Event emitters for workflow lifecycle.
  - Bull for job queues.

## Conventions & Gotchas
- **TypeScript strict mode** enforced.
- **Dependency injection** preferred for services.
- **No direct DB queries** outside repositories.
- **Keep nodes self-contained and testable.**
- **Always run lint, typecheck, and build before PRs.**
- **Production config is isolated in `/n8n-production/` and not present upstream.**

## Integration & Deployment
- **Hetzner:** Automated scripts in `/hetzner-setup/` for secure VPS deployment.
- **Cloudflare:** `/cloudflare-workers/` for edge/serverless automation.
- **API:** REST API with `X-N8N-API-KEY` header, see CLAUDE.md for usage.

## References
- Main docs: `README.md`, `CLAUDE.md`, `/n8n-production/README.md`, `/linear-notion-sync/README.md`, `/cloudflare-workers/README.md`
- Upstream sync: `SYNC_UPSTREAM.md`
- Node/Workflow types: `/packages/workflow/README.md`

---

**Agents:** Use this file as your primary onboarding reference. When in doubt, prefer patterns and commands documented here and in referenced files. If a workflow or convention is unclear, ask for clarification or check the latest documentation in the repo.
