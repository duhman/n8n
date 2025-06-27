/**
 * Cloudflare Worker for processing Notion webhooks
 * This worker receives webhooks from Notion, validates them, 
 * processes the data, and forwards to n8n instance
 */

// Environment variables expected:
// - N8N_WEBHOOK_URL: The URL of your n8n webhook endpoint
// - N8N_API_KEY: Optional API key for n8n authentication
// - NOTION_WEBHOOK_SECRET: Secret for validating Notion webhooks

export default {
  async fetch(request, env, ctx) {
    try {
      // Only handle POST requests
      if (request.method !== 'POST') {
        return new Response('Method not allowed', { status: 405 });
      }

      // Get request body
      const body = await request.text();
      let notionData;
      
      try {
        notionData = JSON.parse(body);
      } catch (error) {
        return new Response('Invalid JSON payload', { status: 400 });
      }

      // Validate webhook signature if secret is provided
      if (env.NOTION_WEBHOOK_SECRET) {
        const signature = request.headers.get('x-notion-signature');
        if (!signature || !await validateNotionSignature(body, signature, env.NOTION_WEBHOOK_SECRET)) {
          return new Response('Invalid signature', { status: 401 });
        }
      }

      // Process Notion webhook data
      const processedData = await processNotionWebhook(notionData);
      
      // Forward to n8n if processing was successful
      if (processedData) {
        const n8nResponse = await forwardToN8n(processedData, env);
        
        // Log the interaction
        console.log('Notion webhook processed:', {
          notionId: notionData.id,
          projectName: processedData.projectName,
          n8nStatus: n8nResponse.status
        });

        // Return success response to Notion
        return new Response(JSON.stringify({
          success: true,
          message: 'Webhook processed successfully',
          timestamp: new Date().toISOString()
        }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        });
      }

      // If processing failed but no error was thrown
      return new Response(JSON.stringify({
        success: false,
        message: 'Webhook processing failed'
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      });

    } catch (error) {
      // Log error for debugging
      console.error('Worker error:', error);
      
      // Return error response
      return new Response(JSON.stringify({
        success: false,
        error: error.message
      }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      });
    }
  }
};

/**
 * Validate Notion webhook signature
 */
async function validateNotionSignature(body, signature, secret) {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  
  const signatureBuffer = await crypto.subtle.sign('HMAC', key, encoder.encode(body));
  const expectedSignature = btoa(String.fromCharCode(...new Uint8Array(signatureBuffer)));
  
  return signature === expectedSignature;
}

/**
 * Process Notion webhook data and extract relevant information
 */
async function processNotionWebhook(notionData) {
  try {
    // Check if this is a project completion event
    if (!isProjectCompletionEvent(notionData)) {
      console.log('Not a project completion event, skipping');
      return null;
    }

    // Extract project information from Notion data
    const projectInfo = extractProjectInfo(notionData);
    
    // Validate required fields
    if (!projectInfo.projectName) {
      throw new Error('Project name is required');
    }

    return {
      projectName: projectInfo.projectName || 'Unnamed Project',
      projectDescription: projectInfo.projectDescription || 'No description provided',
      completionDate: projectInfo.completionDate || new Date().toISOString().split('T')[0],
      teamMembers: projectInfo.teamMembers || [],
      deliverables: projectInfo.deliverables || [],
      notionId: notionData.id,
      notionUrl: projectInfo.notionUrl,
      priority: projectInfo.priority || 'medium',
      category: projectInfo.category || 'general'
    };
  } catch (error) {
    console.error('Error processing Notion webhook:', error);
    throw error;
  }
}

/**
 * Check if the webhook represents a project completion event
 */
function isProjectCompletionEvent(notionData) {
  // Check various Notion webhook structures for "done" status
  
  // Option 1: Direct status property
  if (notionData.properties?.Status?.select?.name === 'Done' || 
      notionData.properties?.Status?.status?.name === 'Done') {
    return true;
  }
  
  // Option 2: Check in data object
  if (notionData.data?.properties?.Status?.select?.name === 'Done') {
    return true;
  }
  
  // Option 3: Check event type and status change
  if (notionData.event_type === 'page.updated' && 
      notionData.changes?.some(change => 
        change.property === 'Status' && 
        change.value?.select?.name === 'Done'
      )) {
    return true;
  }
  
  // Option 4: Generic status check
  const statusFields = ['status', 'Status', 'state', 'State'];
  for (const field of statusFields) {
    if (notionData.properties?.[field]?.select?.name?.toLowerCase() === 'done' ||
        notionData.properties?.[field]?.status?.name?.toLowerCase() === 'done') {
      return true;
    }
  }
  
  return false;
}

/**
 * Extract project information from Notion data
 */
function extractProjectInfo(notionData) {
  const properties = notionData.properties || notionData.data?.properties || {};
  
  return {
    projectName: getPropertyValue(properties, ['Name', 'Title', 'Project Name', 'name', 'title']),
    projectDescription: getPropertyValue(properties, ['Description', 'Summary', 'Details', 'description']),
    completionDate: getDateValue(properties, ['Completion Date', 'Done Date', 'End Date', 'completion_date']),
    teamMembers: getMultiSelectValue(properties, ['Team Members', 'Assignees', 'team', 'assignees']),
    deliverables: getMultiSelectValue(properties, ['Deliverables', 'Tasks', 'deliverables', 'tasks']),
    notionUrl: notionData.url || `https://notion.so/${notionData.id}`,
    priority: getSelectValue(properties, ['Priority', 'priority']),
    category: getSelectValue(properties, ['Category', 'Type', 'category', 'type'])
  };
}

/**
 * Helper function to get property value from various field names
 */
function getPropertyValue(properties, fieldNames) {
  for (const fieldName of fieldNames) {
    const prop = properties[fieldName];
    if (prop) {
      // Handle different Notion property types
      if (prop.title && prop.title[0]) return prop.title[0].plain_text;
      if (prop.rich_text && prop.rich_text[0]) return prop.rich_text[0].plain_text;
      if (prop.plain_text) return prop.plain_text;
      if (typeof prop === 'string') return prop;
    }
  }
  return null;
}

/**
 * Helper function to get date value
 */
function getDateValue(properties, fieldNames) {
  for (const fieldName of fieldNames) {
    const prop = properties[fieldName];
    if (prop?.date?.start) return prop.date.start;
    if (prop?.start) return prop.start;
  }
  return null;
}

/**
 * Helper function to get select value
 */
function getSelectValue(properties, fieldNames) {
  for (const fieldName of fieldNames) {
    const prop = properties[fieldName];
    if (prop?.select?.name) return prop.select.name;
    if (prop?.status?.name) return prop.status.name;
  }
  return null;
}

/**
 * Helper function to get multi-select values
 */
function getMultiSelectValue(properties, fieldNames) {
  for (const fieldName of fieldNames) {
    const prop = properties[fieldName];
    if (prop?.multi_select) {
      return prop.multi_select.map(item => item.name);
    }
    if (prop?.people) {
      return prop.people.map(person => person.name || person.email);
    }
    if (Array.isArray(prop)) {
      return prop.map(item => typeof item === 'string' ? item : item.name || item.value);
    }
  }
  return [];
}

/**
 * Forward processed data to n8n webhook
 */
async function forwardToN8n(processedData, env) {
  const n8nUrl = env.N8N_WEBHOOK_URL || env.N8N_URL;
  
  if (!n8nUrl) {
    throw new Error('N8N_WEBHOOK_URL environment variable is required');
  }

  const headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'Cloudflare-Worker-Notion-Processor/1.0'
  };

  // Add API key if provided
  if (env.N8N_API_KEY) {
    headers['Authorization'] = `Bearer ${env.N8N_API_KEY}`;
  }

  const response = await fetch(n8nUrl, {
    method: 'POST',
    headers,
    body: JSON.stringify(processedData)
  });

  if (!response.ok) {
    throw new Error(`n8n webhook failed: ${response.status} ${response.statusText}`);
  }

  return response;
}