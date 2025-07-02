/**
 * Linear-Notion Sync Configuration
 * 
 * This file contains all the configuration needed for the Linear-Notion sync workflows.
 * Update the values below with your specific IDs and settings.
 */

const CONFIG = {
  // ===================
  // LINEAR CONFIGURATION
  // ===================
  linear: {
    // Your Linear project ID - get this from the project URL or API
    projectId: "YOUR_LINEAR_PROJECT_ID",
    
    // Your Linear team ID - get this from the team settings or API  
    teamId: "YOUR_LINEAR_TEAM_ID",
    
    // Your team's key prefix (e.g., "ELA" for ELA-123 issues)
    teamKey: "ELA",
    
    // Linear GraphQL API endpoint (usually doesn't change)
    apiUrl: "https://api.linear.app/graphql",
    
    // Webhook configuration
    webhook: {
      // This will be filled in when you import the workflow
      url: "YOUR_N8N_WEBHOOK_URL",
      secret: "YOUR_WEBHOOK_SECRET" // Optional but recommended
    }
  },

  // ===================
  // NOTION CONFIGURATION  
  // ===================
  notion: {
    // Your Notion database ID - get this from the database URL
    databaseId: "YOUR_NOTION_DATABASE_ID",
    
    // Notion API endpoint (usually doesn't change)
    apiUrl: "https://api.notion.com/v1",
    
    // Database schema property names (must match exactly)
    properties: {
      title: "Title",
      linearId: "Linear ID", 
      linearUrl: "Linear URL",
      status: "Status",
      priority: "Priority",
      assignee: "Assignee",
      description: "Description",
      createdDate: "Created Date",
      updatedDate: "Updated Date",
      cycle: "Cycle",
      team: "Team",
      externalId: "External ID",
      lastSync: "Last Sync",
      progress: "Progress"
    }
  },

  // ===================
  // SYNC CONFIGURATION
  // ===================
  sync: {
    // How often to poll Notion for changes (in seconds)
    pollInterval: 300, // 5 minutes
    
    // Maximum number of items to process in each batch
    batchSize: 50,
    
    // Maximum number of retry attempts for failed operations
    maxRetries: 3,
    
    // Delay between retries (in seconds)
    retryDelay: 15,
    
    // Conflict resolution strategy: "linear_wins", "notion_wins", or "manual"
    conflictResolution: "linear_wins",
    
    // Enable bidirectional sync (Notion → Linear)
    enableBidirectionalSync: true,
    
    // Sync historical data on first run
    includeHistoricalData: true
  },

  // ===================
  // FIELD MAPPINGS
  // ===================
  mappings: {
    // Linear workflow states → Notion status options
    status: {
      "Backlog": "Backlog",
      "Todo": "Todo", 
      "In Progress": "In Progress",
      "In Review": "In Review",
      "Done": "Done",
      "Canceled": "Cancelled",
      "Cancelled": "Cancelled"
    },
    
    // Linear priority levels → Notion priority options
    priority: {
      0: "No priority",
      1: "Urgent",
      2: "High", 
      3: "Medium",
      4: "Low"
    },
    
    // Reverse mappings for Notion → Linear sync
    statusReverse: {
      "Backlog": "Backlog",
      "Todo": "Todo",
      "In Progress": "In Progress", 
      "In Review": "In Review",
      "Done": "Done",
      "Cancelled": "Canceled" // Linear uses "Canceled"
    },
    
    priorityReverse: {
      "No priority": 0,
      "Low": 4,
      "Medium": 3,
      "High": 2,
      "Urgent": 1
    }
  },

  // ===================
  // MONITORING & ALERTS
  // ===================
  monitoring: {
    // Enable health monitoring
    enabled: true,
    
    // Health check frequency (in hours)
    healthCheckInterval: 1,
    
    // Daily report time (24-hour format)
    dailyReportTime: "09:00",
    
    // Error thresholds for alerts
    thresholds: {
      errorRate24h: 10,      // Alert if more than 10 errors in 24h
      responseTimeMs: 5000,   // Alert if API response > 5 seconds
      syncDelayMinutes: 15    // Alert if no successful sync in 15 minutes
    },
    
    // Notification channels
    notifications: {
      slack: {
        enabled: true,
        channelId: "YOUR_SLACK_CHANNEL_ID",
        webhookUrl: "YOUR_SLACK_WEBHOOK_URL"
      },
      email: {
        enabled: false,
        alertEmail: "admin@yourdomain.com",
        fromEmail: "noreply@yourdomain.com"
      }
    },
    
    // Database IDs for logging (optional)
    databases: {
      errorLog: "YOUR_ERROR_LOG_DATABASE_ID",
      healthLog: "YOUR_HEALTH_LOG_DATABASE_ID"
    }
  },

  // ===================
  // SECURITY SETTINGS
  // ===================
  security: {
    // Enable webhook signature verification
    verifyWebhookSignature: true,
    
    // Rate limiting (requests per minute)
    rateLimits: {
      linear: 120,   // Linear API limit
      notion: 60     // Notion API limit (conservative)
    },
    
    // Data retention (in days)
    dataRetention: {
      executionLogs: 30,
      errorLogs: 90,
      healthLogs: 365
    }
  }
};

// ===================
// HELPER FUNCTIONS
// ===================

/**
 * Get Linear workflow state mapping for the team
 */
function getLinearStateMappings() {
  // This would be populated by the workflow that fetches team states
  return CONFIG.mappings.status;
}

/**
 * Validate configuration completeness
 */
function validateConfig() {
  const errors = [];
  
  if (!CONFIG.linear.projectId || CONFIG.linear.projectId === "YOUR_LINEAR_PROJECT_ID") {
    errors.push("Linear project ID not configured");
  }
  
  if (!CONFIG.linear.teamId || CONFIG.linear.teamId === "YOUR_LINEAR_TEAM_ID") {
    errors.push("Linear team ID not configured");
  }
  
  if (!CONFIG.notion.databaseId || CONFIG.notion.databaseId === "YOUR_NOTION_DATABASE_ID") {
    errors.push("Notion database ID not configured");
  }
  
  return {
    isValid: errors.length === 0,
    errors
  };
}

/**
 * Get mapping for Linear priority to Notion priority
 */
function mapLinearToNotionPriority(linearPriority) {
  return CONFIG.mappings.priority[linearPriority] || "No priority";
}

/**
 * Get mapping for Linear status to Notion status
 */
function mapLinearToNotionStatus(linearStatus) {
  return CONFIG.mappings.status[linearStatus] || "Backlog";
}

/**
 * Get mapping for Notion priority to Linear priority
 */
function mapNotionToLinearPriority(notionPriority) {
  return CONFIG.mappings.priorityReverse[notionPriority] || 0;
}

/**
 * Get mapping for Notion status to Linear status
 */
function mapNotionToLinearStatus(notionStatus) {
  return CONFIG.mappings.statusReverse[notionStatus] || "Backlog";
}

/**
 * Generate webhook URL for Linear
 */
function generateWebhookUrl(baseUrl) {
  return `${baseUrl}/webhook/linear-notion-sync`;
}

/**
 * Check if sync should be retried based on error
 */
function shouldRetrySync(error) {
  const retryableErrors = [
    'timeout',
    'network',
    'rate limit',
    '503',
    '502', 
    '500'
  ];
  
  const errorMsg = error.message.toLowerCase();
  return retryableErrors.some(keyword => errorMsg.includes(keyword));
}

// Export configuration and helpers
if (typeof module !== 'undefined' && module.exports) {
  // Node.js environment
  module.exports = {
    CONFIG,
    validateConfig,
    mapLinearToNotionPriority,
    mapLinearToNotionStatus,
    mapNotionToLinearPriority,
    mapNotionToLinearStatus,
    generateWebhookUrl,
    shouldRetrySync,
    getLinearStateMappings
  };
} else {
  // Browser/n8n environment - attach to global
  if (typeof globalThis !== 'undefined') {
    globalThis.LinearNotionConfig = {
      CONFIG,
      validateConfig,
      mapLinearToNotionPriority,
      mapLinearToNotionStatus,
      mapNotionToLinearPriority,
      mapNotionToLinearStatus,
      generateWebhookUrl,
      shouldRetrySync,
      getLinearStateMappings
    };
  }
}

// ===================
// WORKFLOW-SPECIFIC CONFIGS
// ===================

// Configuration for the Linear → Notion sync workflow
const LINEAR_TO_NOTION_CONFIG = {
  workflowName: "Linear to Notion Sync",
  webhookPath: "linear-webhook",
  retryAttempts: CONFIG.sync.maxRetries,
  batchSize: CONFIG.sync.batchSize
};

// Configuration for the Notion → Linear sync workflow  
const NOTION_TO_LINEAR_CONFIG = {
  workflowName: "Notion to Linear Sync",
  pollInterval: CONFIG.sync.pollInterval,
  retryAttempts: CONFIG.sync.maxRetries,
  batchSize: CONFIG.sync.batchSize
};

// Configuration for the initial import workflow
const INITIAL_IMPORT_CONFIG = {
  workflowName: "Initial Linear to Notion Import",
  batchSize: 25, // Smaller batches for initial import
  includeArchived: false,
  skipExisting: true
};

// ===================
// ENVIRONMENT VARIABLES
// ===================

/**
 * Environment variables that should be set in n8n or your hosting environment
 * These are referenced in the workflows but defined here for documentation
 */
const ENVIRONMENT_VARIABLES = {
  // API Credentials (set these in n8n credentials manager)
  LINEAR_API_KEY: "your-linear-api-key",
  NOTION_INTEGRATION_TOKEN: "your-notion-integration-token",
  
  // Webhook security
  WEBHOOK_SECRET: "your-webhook-secret",
  
  // Notification settings
  SLACK_WEBHOOK_URL: "your-slack-webhook-url",
  SLACK_CHANNEL_ID: "your-slack-channel-id",
  
  // SMTP settings (if using email notifications)
  SMTP_HOST: "your-smtp-host",
  SMTP_PORT: "587",
  SMTP_USER: "your-smtp-username", 
  SMTP_PASS: "your-smtp-password",
  
  // n8n API (for health monitoring)
  N8N_API_KEY: "your-n8n-api-key",
  N8N_BASE_URL: "your-n8n-instance-url"
};

// Export specific configs if in Node.js environment
if (typeof module !== 'undefined' && module.exports) {
  module.exports.LINEAR_TO_NOTION_CONFIG = LINEAR_TO_NOTION_CONFIG;
  module.exports.NOTION_TO_LINEAR_CONFIG = NOTION_TO_LINEAR_CONFIG;
  module.exports.INITIAL_IMPORT_CONFIG = INITIAL_IMPORT_CONFIG;
  module.exports.ENVIRONMENT_VARIABLES = ENVIRONMENT_VARIABLES;
}