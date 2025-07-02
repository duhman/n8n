# Linear-Notion Sync Setup Guide

This guide walks you through setting up the complete Linear-Notion synchronization system.

## Step 1: Credential Setup in n8n

### Linear API Credential

1. **Get Linear API Key**:
   - Go to [Linear Settings → API](https://linear.app/settings/api)
   - Click "Create API Key"
   - Name: "n8n Sync Integration"
   - Copy the generated API key

2. **Add to n8n**:
   - In n8n, go to Credentials
   - Create new "Linear API" credential
   - Paste your API key
   - Test connection
   - Save as "Linear - Project Sync"

### Notion Integration Credential

1. **Create Notion Integration**:
   - Go to [Notion Integrations](https://www.notion.so/my-integrations)
   - Click "New integration"
   - Name: "Linear Project Sync"
   - Capabilities: Read content, Update content, Insert content
   - Copy the "Internal Integration Token"

2. **Add to n8n**:
   - In n8n, go to Credentials
   - Create new "Notion API" credential
   - Paste your integration token
   - Save as "Notion - Project Database"

## Step 2: Get Required IDs

### Linear Project ID

Execute this in your browser console on the Linear project page:

```javascript
// Navigate to your Linear project page first
// Then run this in browser console:
console.log("Project ID:", window.location.pathname.match(/\/project\/([^\/]+)/)?.[1]);
```

Or use the Linear API:

```bash
curl -X POST https://api.linear.app/graphql \
  -H "Authorization: YOUR_LINEAR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query { projects { nodes { id name } } }"
  }'
```

### Linear Team ID

```bash
curl -X POST https://api.linear.app/graphql \
  -H "Authorization: YOUR_LINEAR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query { teams { nodes { id name key } } }"
  }'
```

### Notion Database ID

1. Open your Notion database
2. Click "Share" → "Copy link"
3. Extract ID from URL: `https://notion.so/workspace/DatabaseName-{DATABASE_ID}?v=...`
4. The DATABASE_ID is the 32-character string after the last dash

## Step 3: Create Notion Database Schema

Run this script to create the database with proper schema:

```javascript
// Notion API script to create database
const NOTION_TOKEN = "your_notion_integration_token";
const PARENT_PAGE_ID = "your_parent_page_id"; // Where to create the database

const databaseSchema = {
  "parent": {
    "type": "page_id",
    "page_id": PARENT_PAGE_ID
  },
  "title": [
    {
      "type": "text",
      "text": {
        "content": "Linear Project Issues"
      }
    }
  ],
  "properties": {
    "Title": {
      "title": {}
    },
    "Linear ID": {
      "rich_text": {}
    },
    "Linear URL": {
      "url": {}
    },
    "Status": {
      "select": {
        "options": [
          { "name": "Backlog", "color": "gray" },
          { "name": "Todo", "color": "blue" },
          { "name": "In Progress", "color": "yellow" },
          { "name": "In Review", "color": "orange" },
          { "name": "Done", "color": "green" },
          { "name": "Cancelled", "color": "red" }
        ]
      }
    },
    "Assignee": {
      "people": {}
    },
    "Priority": {
      "select": {
        "options": [
          { "name": "No priority", "color": "default" },
          { "name": "Low", "color": "blue" },
          { "name": "Medium", "color": "yellow" },
          { "name": "High", "color": "orange" },
          { "name": "Urgent", "color": "red" }
        ]
      }
    },
    "Description": {
      "rich_text": {}
    },
    "Created Date": {
      "date": {}
    },
    "Updated Date": {
      "date": {}
    },
    "Cycle": {
      "rich_text": {}
    },
    "Team": {
      "rich_text": {}
    },
    "External ID": {
      "rich_text": {}
    },
    "Last Sync": {
      "date": {}
    },
    "Progress": {
      "formula": {
        "expression": "if(prop(\"Status\") == \"Done\", 100, if(prop(\"Status\") == \"In Progress\", 50, 0))"
      }
    }
  }
};

// Create the database
fetch('https://api.notion.com/v1/databases', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${NOTION_TOKEN}`,
    'Content-Type': 'application/json',
    'Notion-Version': '2022-06-28'
  },
  body: JSON.stringify(databaseSchema)
})
.then(response => response.json())
.then(data => {
  console.log('Database created:', data.id);
  console.log('Use this ID in your n8n workflows:', data.id);
});
```

### Manual Database Creation

If you prefer to create manually:

1. Create a new database in Notion
2. Add these properties exactly:

| Property Name | Type | Configuration |
|---------------|------|---------------|
| Title | Title | Default |
| Linear ID | Rich Text | - |
| Linear URL | URL | - |
| Status | Select | Options: Backlog, Todo, In Progress, In Review, Done, Cancelled |
| Assignee | Person | - |
| Priority | Select | Options: No priority, Low, Medium, High, Urgent |
| Description | Rich Text | - |
| Created Date | Date | - |
| Updated Date | Date | - |
| Cycle | Rich Text | - |
| Team | Rich Text | - |
| External ID | Rich Text | - |
| Last Sync | Date | - |
| Progress | Formula | `if(prop("Status") == "Done", 100, if(prop("Status") == "In Progress", 50, 0))` |

3. **Share database with integration**:
   - Click "Share" in top-right
   - Click "Invite"
   - Search for your integration name
   - Give "Full access"

## Step 4: Configure Workflow Variables

Before importing workflows, create this configuration:

```javascript
// Configuration object for all workflows
const CONFIG = {
  // Linear Configuration
  linear: {
    projectId: "YOUR_LINEAR_PROJECT_ID",
    teamId: "YOUR_LINEAR_TEAM_ID", 
    teamKey: "ELA", // Your team prefix (e.g., ELA-123)
    apiUrl: "https://api.linear.app/graphql"
  },
  
  // Notion Configuration
  notion: {
    databaseId: "YOUR_NOTION_DATABASE_ID",
    apiUrl: "https://api.notion.com/v1"
  },
  
  // Sync Configuration
  sync: {
    interval: 300, // 5 minutes
    batchSize: 50,
    maxRetries: 3,
    conflictResolution: "linear_wins" // or "notion_wins" or "manual"
  },
  
  // Field Mappings
  mappings: {
    status: {
      "Backlog": "Backlog",
      "Todo": "Todo",
      "In Progress": "In Progress", 
      "In Review": "In Review",
      "Done": "Done",
      "Canceled": "Cancelled"
    },
    priority: {
      0: "No priority",
      1: "Urgent", 
      2: "High",
      3: "Medium",
      4: "Low"
    }
  }
};
```

## Step 5: Import n8n Workflows

1. **Download workflow files**:
   - `linear-to-notion-sync.json`
   - `notion-to-linear-sync.json` 
   - `initial-import.json`

2. **Import each workflow**:
   - In n8n, click "+" → "Import from file"
   - Select workflow file
   - Update credentials to use the ones you created
   - Update configuration variables with your IDs

3. **Update webhook URLs**:
   - In Linear webhook workflow, note the webhook URL
   - Update any hardcoded IDs with your actual IDs

## Step 6: Configure Linear Webhook

1. **In Linear**:
   - Go to Settings → API → Webhooks
   - Click "Create webhook"
   - URL: Your n8n webhook URL from the Linear-to-Notion workflow
   - Label: "n8n Notion Sync"
   - Team: Select your team
   - Resources: Select "Issues" and "Comments"
   - Events: Create, Update, Remove

2. **Test webhook**:
   - Create a test issue in Linear
   - Check n8n execution log
   - Verify issue appears in Notion

## Step 7: Test the Complete System

### Test 1: Linear → Notion
1. Create a new issue in Linear
2. Check that it appears in Notion within seconds
3. Update the issue status in Linear
4. Verify status updates in Notion

### Test 2: Notion → Linear  
1. Change an issue status in Notion
2. Wait up to 5 minutes (polling interval)
3. Verify the status updated in Linear
4. Check that timestamps prevent infinite loops

### Test 3: Initial Import
1. Run the "Initial Import" workflow manually
2. Verify all existing Linear issues are imported
3. Check that no duplicates are created
4. Confirm sync relationships are established

## Step 8: Monitoring Setup

### n8n Monitoring
1. Enable workflow execution history
2. Set up error notifications:
   - Add email/Slack notifications to error handling nodes
   - Configure retry policies
   - Set up health check schedules

### Notion Monitoring  
1. Create database views to monitor sync:
   - "Recently Synced" (Last Sync within 1 hour)
   - "Sync Issues" (Last Sync older than 1 day)
   - "Missing External ID" (No Linear ID)

### Linear Monitoring
1. Check webhook delivery in Linear settings
2. Monitor for failed webhook deliveries
3. Set up alerts for webhook downtime

## Troubleshooting Setup Issues

### Credential Issues
- **Linear API**: Test with a simple GraphQL query
- **Notion Integration**: Verify database sharing permissions
- **n8n Credentials**: Use "Test" button to validate

### Webhook Issues
- **Not receiving**: Check Linear webhook settings and URL
- **Invalid payload**: Verify webhook signature validation
- **Network issues**: Ensure n8n is accessible from Linear

### Database Schema Issues
- **Property mismatch**: Verify exact property names and types
- **Permission denied**: Ensure integration has database access
- **Formula errors**: Check Progress formula syntax

### Mapping Issues
- **Status not updating**: Verify status option names match
- **Users not found**: Check that Notion users exist and have access
- **Priority mismatch**: Confirm priority value mappings

## Production Deployment

### Performance Optimization
1. **Batch Processing**: Group Notion updates to reduce API calls
2. **Caching**: Store user mappings to avoid repeated lookups  
3. **Rate Limiting**: Implement delays to respect API limits
4. **Parallel Processing**: Use sub-workflows for concurrent operations

### Security Hardening
1. **Webhook Security**: Implement signature verification
2. **Credential Rotation**: Regularly update API keys
3. **Access Control**: Limit integration permissions
4. **Audit Logging**: Track all sync operations

### Monitoring & Alerting
1. **Health Checks**: Monitor workflow execution success rates
2. **Performance Metrics**: Track sync latency and throughput
3. **Error Alerting**: Set up notifications for failures
4. **Data Integrity**: Regular validation of sync accuracy

## Support & Maintenance

### Regular Tasks
- Monitor sync performance and accuracy
- Update API credentials before expiration
- Review and optimize workflow logic
- Clean up old execution logs

### Updates & Changes
- Test changes in development environment first
- Update field mappings when Linear/Notion schemas change
- Document any customizations or modifications
- Maintain backup copies of working workflows

This completes the setup process. Your Linear project should now be automatically synchronized with your Notion database!