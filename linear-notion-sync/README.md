# Linear-Notion Project Sync

This project provides automated synchronization between Linear projects and Notion databases, enabling real-time tracking of project progress across both platforms.

## Features

- **Real-time sync**: Linear changes are instantly reflected in Notion via webhooks
- **Bidirectional updates**: Changes in Notion can be synced back to Linear  
- **Progress tracking**: Automatic calculation of project completion percentages
- **State mapping**: Linear workflow states are mapped to Notion status properties
- **Conflict prevention**: Intelligent timestamp-based change detection
- **Error handling**: Robust retry mechanisms and failure notifications

## Architecture

### Workflows

1. **Linear → Notion Sync** (`linear-to-notion-sync.json`)
   - Triggered by Linear webhooks for real-time updates
   - Maps Linear issues to Notion database pages
   - Handles create, update, and status change events

2. **Notion → Linear Sync** (`notion-to-linear-sync.json`)
   - Polls Notion database every 5 minutes for changes
   - Updates Linear issues based on Notion modifications
   - Prevents infinite loops with change tracking

3. **Initial Data Import** (`initial-import.json`)
   - One-time setup workflow to import existing Linear project data
   - Creates corresponding Notion database entries
   - Establishes sync relationships

## Prerequisites

### Linear Setup
1. Linear API key with project access
2. Admin permissions to create webhooks
3. Project ID for the specific project to sync

### Notion Setup  
1. Notion integration token
2. Database ID for the target Notion database
3. Properly configured database schema (see Database Schema section)

## Installation

### Step 1: Authentication Setup

#### Linear API Key
1. Go to Linear Settings → API → Personal API keys
2. Create new API key with appropriate scopes
3. Copy the API key for n8n credential setup

#### Notion Integration Token
1. Go to https://www.notion.so/my-integrations
2. Create new integration with "Read content", "Update content", and "Insert content" capabilities
3. Copy the Internal Integration Token
4. Share your target database with the integration

### Step 2: Database Schema Setup

Create a Notion database with the following properties:

| Property Name | Property Type | Description |
|---------------|---------------|-------------|
| Title | Title | Issue title from Linear |
| Linear ID | Rich Text | Linear issue identifier (e.g., ELA-123) |
| Linear URL | URL | Direct link to Linear issue |
| Status | Select | Mapped from Linear workflow state |
| Assignee | Person | Issue assignee |
| Priority | Select | Issue priority (No priority, Low, Medium, High, Urgent) |
| Description | Rich Text | Issue description |
| Created Date | Date | Issue creation timestamp |
| Updated Date | Date | Last modification timestamp |
| Cycle | Rich Text | Linear cycle/sprint information |
| Team | Rich Text | Linear team name |
| Progress | Formula | Calculated completion percentage |
| External ID | Rich Text | Hidden field for sync tracking |
| Last Sync | Date | Hidden field for conflict prevention |

#### Status Property Options
Configure the Status select property with options matching your Linear workflow states:
- Backlog
- Todo  
- In Progress
- In Review
- Done
- Cancelled

#### Priority Property Options
- No priority
- Low
- Medium  
- High
- Urgent

### Step 3: n8n Workflow Import

1. Import the workflow files into your n8n instance
2. Configure credentials for Linear and Notion
3. Update workflow variables with your specific IDs:
   - Linear Project ID
   - Notion Database ID
   - Webhook URLs

### Step 4: Initial Data Import

1. Run the "Initial Data Import" workflow manually
2. Verify all existing Linear issues are created in Notion
3. Check that sync relationships are properly established

## Configuration

### Environment Variables

The workflows use the following configurable parameters:

```javascript
// Linear Configuration
const LINEAR_PROJECT_ID = "your-linear-project-id";
const LINEAR_TEAM_KEY = "ELA"; // Your team's key prefix

// Notion Configuration  
const NOTION_DATABASE_ID = "your-notion-database-id";

// Sync Configuration
const SYNC_INTERVAL = 300; // 5 minutes in seconds
const MAX_RETRIES = 3;
const BATCH_SIZE = 50;
```

### Field Mapping

The sync workflows use the following field mappings:

| Linear Field | Notion Property | Transformation |
|--------------|-----------------|----------------|
| `title` | Title | Direct mapping |
| `identifier` | Linear ID | Direct mapping |
| `url` | Linear URL | Direct mapping |
| `state.name` | Status | State name mapping |
| `assignee.displayName` | Assignee | User lookup/creation |
| `priority` | Priority | Priority level mapping |
| `description` | Description | Rich text conversion |
| `createdAt` | Created Date | ISO date conversion |
| `updatedAt` | Updated Date | ISO date conversion |
| `cycle.name` | Cycle | Direct mapping |
| `team.name` | Team | Direct mapping |

### State Mapping

Linear workflow states are mapped to Notion status options:

```javascript
const STATE_MAPPING = {
  // Linear State → Notion Status
  "Backlog": "Backlog",
  "Todo": "Todo", 
  "In Progress": "In Progress",
  "In Review": "In Review",
  "Done": "Done",
  "Cancelled": "Cancelled"
};
```

### Priority Mapping

```javascript
const PRIORITY_MAPPING = {
  0: "No priority",
  1: "Urgent",
  2: "High", 
  3: "Medium",
  4: "Low"
};
```

## Usage

### Real-time Sync

Once configured, the workflows will automatically:

1. **Linear → Notion**: When issues are created, updated, or have status changes in Linear, they're immediately reflected in the Notion database

2. **Notion → Linear**: Every 5 minutes, the system checks for changes in Notion and updates corresponding Linear issues

### Manual Operations

- **Force Sync**: Run any workflow manually to trigger immediate synchronization
- **Refresh Import**: Re-run the initial import workflow to add newly created issues
- **Reset Sync**: Clear sync timestamps to force full re-synchronization

## Monitoring

### Workflow Execution Logs

Monitor sync health through n8n's execution logs:
- Check for failed executions
- Review error messages and retry attempts
- Monitor sync frequency and performance

### Notion Database Monitoring

Track sync status in Notion:
- **Last Sync** property shows when each item was last updated
- **External ID** property contains the Linear issue ID for tracking
- Use database views to filter by sync status

## Troubleshooting

### Common Issues

#### Webhook Not Receiving Data
- Verify Linear webhook URL is correct
- Check webhook security settings in Linear
- Ensure n8n webhook endpoint is accessible

#### Notion Updates Not Syncing
- Verify Notion integration has proper permissions
- Check database sharing settings
- Validate property mappings match schema

#### Duplicate Entries
- Check External ID field population
- Verify deduplication logic in workflows
- Review conflict prevention timestamps

#### Missing Assignees  
- Ensure Notion database is shared with integration
- Verify user email addresses match between systems
- Check user creation/lookup logic

### Debug Mode

Enable debug mode in workflows by:
1. Adding "Edit Fields (Set)" nodes to log intermediate data
2. Using "Stop and Error" nodes to pause execution for inspection
3. Enabling workflow execution data retention

## Workflow Details

### Linear to Notion Sync Workflow

**Trigger**: Linear Webhook
**Operations**:
1. Receive Linear webhook payload
2. Extract issue data and event type
3. Check if Notion page exists (by External ID)
4. Create or update Notion database page
5. Update sync timestamps
6. Handle errors and retries

### Notion to Linear Sync Workflow

**Trigger**: Schedule (every 5 minutes)
**Operations**:
1. Query Notion database for recent changes
2. For each changed page, extract Linear ID
3. Fetch current Linear issue data
4. Compare and detect actual changes
5. Update Linear issue if changes detected
6. Update Notion sync timestamps

### Initial Import Workflow

**Trigger**: Manual
**Operations**:
1. Fetch all issues from Linear project
2. Query existing Notion pages
3. Identify missing issues
4. Batch create Notion pages
5. Establish sync relationships

## Security Considerations

- Store API credentials securely in n8n credential manager
- Use webhook signature validation for Linear webhooks
- Implement rate limiting to respect API limits
- Encrypt sensitive data in workflow storage

## Performance Optimization

- Use GraphQL field selection to minimize Linear API payload
- Implement pagination for large datasets
- Batch Notion operations where possible
- Use incremental sync with timestamps
- Cache frequently accessed data

## Support

For issues or questions:
1. Check workflow execution logs in n8n
2. Verify API credentials and permissions
3. Review this documentation
4. Check Linear and Notion API documentation
5. Contact system administrator

## License

This project is provided as-is for internal use. Ensure compliance with Linear and Notion API terms of service.