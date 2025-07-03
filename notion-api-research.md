# Notion API Research: Syncing External Project Data

## Overview

This document provides comprehensive research on using the Notion API to sync external project data into Notion databases, based on the official documentation and n8n's existing Notion integration implementation.

## 1. Authentication Methods and Setup

### Authentication Types

1. **Internal Integration (Recommended for single workspace)**
   - Uses a simple API key (Integration Secret)
   - Limited to a single workspace
   - No OAuth flow required
   - Setup process:
     1. Go to https://www.notion.so/my-integrations
     2. Create new integration
     3. Copy the Internal Integration Secret
     4. Share databases/pages with the integration

2. **OAuth 2.0 Integration (For multi-workspace)**
   - Requires OAuth flow implementation
   - Can access multiple workspaces
   - Requires Notion's security review for public distribution

### Authentication Headers

```bash
Authorization: Bearer {INTEGRATION_SECRET}
Notion-Version: 2022-06-28  # Use latest API version
```

### n8n Implementation

n8n supports both authentication methods:
- `NotionApi` credential type for Internal Integration
- `NotionOAuth2Api` credential type for OAuth flow

## 2. Database Operations

### Key Endpoints

1. **Query Database** (Get entries)
   ```
   POST /v1/databases/{database_id}/query
   ```

2. **Create Page** (Add new entry)
   ```
   POST /v1/pages
   ```

3. **Update Page** (Update existing entry)
   ```
   PATCH /v1/pages/{page_id}
   ```

4. **Retrieve Database** (Get schema)
   ```
   GET /v1/databases/{database_id}
   ```

### Query Database Example

```json
POST /v1/databases/{database_id}/query
{
  "filter": {
    "property": "Status",
    "select": {
      "equals": "In Progress"
    }
  },
  "sorts": [
    {
      "property": "Created",
      "direction": "descending"
    }
  ],
  "page_size": 100
}
```

### Create Database Page Example

```json
POST /v1/pages
{
  "parent": {
    "database_id": "DATABASE_ID"
  },
  "properties": {
    "Name": {
      "title": [
        {
          "text": {
            "content": "New Project"
          }
        }
      ]
    },
    "Status": {
      "select": {
        "name": "In Progress"
      }
    }
  }
}
```

### Update Page Properties Example

```json
PATCH /v1/pages/{page_id}
{
  "properties": {
    "Status": {
      "select": {
        "name": "Completed"
      }
    },
    "Progress": {
      "number": 100
    }
  }
}
```

## 3. Database Property Types and Schemas

### Supported Property Types

1. **Title** (required for every database)
2. **Rich Text** - Multi-line text with formatting
3. **Number** - Numeric values
4. **Select** - Single choice from options
5. **Multi-select** - Multiple choices
6. **Date** - Date with optional time
7. **Checkbox** - Boolean value
8. **URL** - Web links
9. **Email** - Email addresses
10. **Phone Number** - Phone numbers
11. **Files** - File attachments
12. **People** - User references
13. **Relation** - Links to other database entries
14. **Status** - Status with groups
15. **Formula** - Computed values (read-only)
16. **Rollup** - Aggregations from relations (read-only)
17. **Created Time** - Auto-generated
18. **Created By** - Auto-generated
19. **Last Edited Time** - Auto-generated
20. **Last Edited By** - Auto-generated

### Property Value Formatting Examples

#### Text Properties (Title/Rich Text)
```json
{
  "Project Name": {
    "title": [
      {
        "text": {
          "content": "My Project"
        }
      }
    ]
  },
  "Description": {
    "rich_text": [
      {
        "text": {
          "content": "Project description"
        }
      }
    ]
  }
}
```

#### Number Property
```json
{
  "Progress": {
    "number": 75.5
  }
}
```

#### Select Property
```json
{
  "Status": {
    "select": {
      "name": "In Progress"
    }
  }
}
```

#### Multi-Select Property
```json
{
  "Tags": {
    "multi_select": [
      {"name": "Frontend"},
      {"name": "Backend"}
    ]
  }
}
```

#### Date Property
```json
{
  "Due Date": {
    "date": {
      "start": "2024-01-15",
      "end": null
    }
  }
}
```

#### Checkbox Property
```json
{
  "Completed": {
    "checkbox": true
  }
}
```

#### People Property
```json
{
  "Assignee": {
    "people": [
      {"id": "USER_ID"}
    ]
  }
}
```

#### Relation Property
```json
{
  "Related Tasks": {
    "relation": [
      {"id": "PAGE_ID_1"},
      {"id": "PAGE_ID_2"}
    ]
  }
}
```

## 4. Rate Limits and Best Practices

### Rate Limits
- **Average**: 3 requests per second per integration
- **Burst**: Some burst requests allowed above average
- **Response**: HTTP 429 with "rate_limited" error when exceeded
- **Retry-After**: Header indicates wait time in seconds

### Best Practices for Syncing

1. **Batch Operations**
   - Use bulk queries with filters instead of individual requests
   - Maximum page size is 100 items per request
   - Implement cursor-based pagination for large datasets

2. **Error Handling**
   ```javascript
   async function makeNotionRequest(url, options) {
     try {
       const response = await fetch(url, options);
       if (response.status === 429) {
         const retryAfter = response.headers.get('Retry-After') || 5;
         await sleep(retryAfter * 1000);
         return makeNotionRequest(url, options);
       }
       return response;
     } catch (error) {
       // Handle network errors
     }
   }
   ```

3. **Sync Strategy**
   - Query existing entries before creating duplicates
   - Use unique identifiers (external IDs) in a property
   - Implement incremental sync using "last_edited_time"
   - Handle pagination for large databases

4. **Request Optimization**
   - Cache database schemas to avoid repeated retrieval
   - Queue requests to stay within rate limits
   - Use filters to minimize data transfer

## 5. Syncing External Project Data - Implementation Pattern

### Recommended Sync Workflow

1. **Initial Setup**
   - Create Notion database with required properties
   - Add an "External ID" property for mapping
   - Share database with integration

2. **Sync Process**
   ```javascript
   async function syncProjectToNotion(project, notionDatabaseId) {
     // 1. Check if project exists in Notion
     const existingPage = await queryDatabase(notionDatabaseId, {
       filter: {
         property: "External ID",
         rich_text: {
           equals: project.id
         }
       }
     });

     // 2. Prepare property values
     const properties = {
       "Name": { title: [{ text: { content: project.name } }] },
       "Status": { select: { name: project.status } },
       "Progress": { number: project.progress },
       "Due Date": { date: { start: project.dueDate } },
       "External ID": { rich_text: [{ text: { content: project.id } }] }
     };

     // 3. Create or update
     if (existingPage.results.length > 0) {
       await updatePage(existingPage.results[0].id, { properties });
     } else {
       await createPage({
         parent: { database_id: notionDatabaseId },
         properties
       });
     }
   }
   ```

3. **Batch Sync Implementation**
   ```javascript
   async function batchSyncProjects(projects, databaseId) {
     const queue = [];
     const BATCH_SIZE = 10;
     
     for (let i = 0; i < projects.length; i += BATCH_SIZE) {
       const batch = projects.slice(i, i + BATCH_SIZE);
       const promises = batch.map(project => 
         syncProjectToNotion(project, databaseId)
       );
       await Promise.all(promises);
       
       // Rate limit compliance
       if (i + BATCH_SIZE < projects.length) {
         await sleep(3500); // ~3 requests/second
       }
     }
   }
   ```

## 6. n8n-Specific Implementation

### Using n8n's Notion Node

n8n provides built-in Notion integration with:
- Simplified authentication setup
- Property mapping UI
- Error handling
- Rate limit management

### Key Functions in n8n's Implementation

1. **notionApiRequest** - Handles authenticated requests
2. **mapProperties** - Converts n8n property format to Notion API format
3. **simplifyProperties** - Converts Notion API response to simplified format
4. **notionApiRequestAllItems** - Handles pagination automatically

### Example n8n Workflow for Syncing

1. **Trigger**: Schedule or webhook
2. **Get External Data**: HTTP Request or database query
3. **Notion Database Page**: Create/Update operation
   - Map external fields to Notion properties
   - Use "External ID" for deduplication

## 7. Common Challenges and Solutions

### Challenge 1: Handling Missing Select Options
**Solution**: Pre-create all select options in Notion database or use the database update endpoint to add new options.

### Challenge 2: Large Dataset Sync
**Solution**: Implement incremental sync using timestamps and batch processing.

### Challenge 3: Maintaining Data Consistency
**Solution**: Use transaction-like patterns with error recovery and rollback logic.

### Challenge 4: Complex Data Transformations
**Solution**: Use n8n's transformation nodes or custom code to map complex structures.

## 8. Security Considerations

1. **API Key Management**
   - Store keys securely (environment variables)
   - Use different keys for dev/prod
   - Rotate keys periodically

2. **Access Control**
   - Only share required databases with integration
   - Use read-only integrations where possible
   - Monitor integration activity

3. **Data Privacy**
   - Be mindful of sensitive data in sync
   - Implement data filtering/sanitization
   - Comply with data protection regulations

## Conclusion

The Notion API provides comprehensive capabilities for syncing external project data. Key success factors include:
- Proper authentication setup
- Understanding property types and formatting
- Implementing robust error handling
- Respecting rate limits
- Using efficient sync strategies

n8n's existing Notion integration provides a solid foundation that handles many complexities, making it an excellent choice for implementing project synchronization workflows.