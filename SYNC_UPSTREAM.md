# Syncing with Upstream n8n Repository

This document explains how to keep your fork (`duhman/n8n`) synchronized with the original n8n repository (`n8n-io/n8n`) while maintaining your custom production setup.

## Git Remote Setup

Your repository has two remotes configured:
- **origin**: `https://github.com/duhman/n8n.git` (your fork)
- **upstream**: `https://github.com/n8n-io/n8n.git` (original n8n repo)

## Regular Sync Workflow

### 1. Fetch Latest Changes from Upstream

```bash
# Fetch the latest changes from the original n8n repository
git fetch upstream

# Switch to your master branch
git checkout master

# View what changes are coming
git log --oneline master..upstream/master
```

### 2. Merge Upstream Changes

```bash
# Option A: Merge (preserves your custom commits)
git merge upstream/master

# Option B: Rebase (cleaner history, but may require conflict resolution)
git rebase upstream/master
```

### 3. Push to Your Fork

```bash
# Push the updated master branch to your fork
git push origin master
```

## Handling Merge Conflicts

When conflicts occur (especially in files you've modified like README.md or CLAUDE.md):

1. **Resolve conflicts manually:**
   ```bash
   # Git will mark conflicted files
   git status
   
   # Edit conflicted files to resolve differences
   # Look for conflict markers: <<<<<<< ======= >>>>>>>
   ```

2. **Prioritize your production setup:**
   - Keep your production-related changes
   - Integrate new features from upstream
   - Update documentation to reflect both

3. **Complete the merge:**
   ```bash
   git add .
   git commit -m "resolve: merge conflicts with upstream changes"
   git push origin master
   ```

## Protecting Your Production Setup

Your production setup is in `/n8n-production/` directory, which is unlikely to conflict with upstream changes. However, to be safe:

### Create a Production Branch (Optional)

```bash
# Create a dedicated branch for production changes
git checkout -b production-setup
git push origin production-setup

# This branch contains only your production modifications
```

### Regular Maintenance Commands

```bash
# Check if your fork is behind upstream
git status
git log --oneline HEAD..upstream/master

# Quick sync (if no conflicts expected)
git fetch upstream && git merge upstream/master && git push origin master

# Force sync (use carefully - will overwrite local changes)
git reset --hard upstream/master && git push --force origin master
```

## Automation Script

Create a sync script for regular maintenance:

```bash
#!/bin/bash
# sync-upstream.sh

echo "🔄 Syncing with upstream n8n repository..."

# Fetch upstream changes
git fetch upstream
git fetch origin

# Check if there are new changes
if git diff --quiet HEAD upstream/master; then
    echo "✅ Already up to date with upstream"
    exit 0
fi

echo "📥 New changes found, syncing..."

# Backup current branch
CURRENT_BRANCH=$(git branch --show-current)
git branch backup-$(date +%Y%m%d-%H%M%S) HEAD

# Merge upstream changes
if git merge upstream/master; then
    echo "✅ Successfully merged upstream changes"
    git push origin $CURRENT_BRANCH
    echo "🚀 Pushed to origin/$CURRENT_BRANCH"
else
    echo "⚠️  Merge conflicts detected. Please resolve manually:"
    echo "   1. Resolve conflicts in marked files"
    echo "   2. git add ."
    echo "   3. git commit"
    echo "   4. git push origin $CURRENT_BRANCH"
fi
```

## Best Practices

1. **Sync regularly** (weekly or when new n8n releases are available)
2. **Always backup** before major syncs
3. **Test your production setup** after syncing
4. **Keep production changes minimal** to reduce conflict potential
5. **Document any customizations** in CLAUDE.md

## Emergency Recovery

If sync goes wrong:

```bash
# Reset to your last known good state
git reflog                           # Find the commit hash before sync
git reset --hard <commit-hash>       # Reset to that point
git push --force origin master       # Force push (use carefully!)

# Or restore from backup branch
git checkout backup-YYYYMMDD-HHMMSS
git branch -D master
git checkout -b master
git push --force origin master
```

## Production Deployment After Sync

After syncing with upstream:

1. **Test the development setup:**
   ```bash
   pnpm install
   pnpm build
   pnpm dev
   ```

2. **Update production if needed:**
   ```bash
   cd n8n-production
   docker compose down
   docker compose pull
   docker compose up -d
   ```

3. **Verify everything works:**
   - Check n8n is accessible at http://localhost:5678
   - Test a simple workflow
   - Verify database connectivity

This workflow ensures you get the latest n8n features while maintaining your production setup!