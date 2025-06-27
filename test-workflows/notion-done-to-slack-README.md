# Notion Done Projects to Slack Workflow

This workflow automatically sends a Slack notification when a project in Notion reaches the "done" stage.

## Workflow Overview

1. **Webhook Trigger**: Receives POST requests from Notion when a project status changes to "done"
2. **OpenAI Processing**: Analyzes project details and creates a professional summary
3. **Slack Notification**: Sends the formatted summary to your designated Slack channel
4. **Response**: Returns a success message to Notion

## Setup Instructions

### 1. Import the Workflow

After starting your n8n instance:

```bash
# Option 1: Via CLI (if you have n8n CLI installed)
n8n import:workflow --input=test-workflows/notion-done-to-slack-workflow.json

# Option 2: Via UI
# 1. Go to your n8n instance (http://localhost:5678)
# 2. Click "Add workflow" → "Import from File"
# 3. Select the notion-done-to-slack-workflow.json file
```

### 2. Configure Credentials

You'll need to set up the following credentials in n8n:

#### OpenAI API Key
1. In n8n, go to Credentials → Add Credential → OpenAI
2. Enter your OpenAI API key
3. Name it "OpenAI API" (or update the workflow to match your credential name)

#### Slack OAuth2
1. Go to https://api.slack.com/apps and create a new app
2. Add OAuth scopes: `chat:write`, `chat:write.public`
3. Install the app to your workspace
4. In n8n, go to Credentials → Add Credential → Slack OAuth2
5. Enter your Client ID, Client Secret, and complete the OAuth flow

### 3. Configure the Workflow

Open the workflow in n8n and update:

1. **Slack Channel**: In the "Send to Slack" node, replace `YOUR_CHANNEL_ID` with your actual Slack channel ID
2. **OpenAI Model**: Optionally change from `gpt-4` to `gpt-3.5-turbo` for cost savings

### 4. Set Up Notion Webhook

The webhook URL will be: `https://your-n8n-instance.com/webhook/notion-project-done`

In Notion, you'll need to set up an automation or use Notion's API to send a POST request when a project status changes to "done".

#### Expected Webhook Payload

The workflow expects a JSON payload with the following structure:

```json
{
  "projectName": "Project Alpha",
  "projectDescription": "Implementation of new customer portal with React and Node.js",
  "completionDate": "2024-01-15",
  "teamMembers": ["John Doe", "Jane Smith", "Bob Johnson"],
  "deliverables": [
    "Customer portal frontend",
    "API documentation", 
    "User authentication system",
    "Admin dashboard"
  ]
}
```

### 5. Notion Automation Setup

To automatically trigger this webhook from Notion:

1. **Using Notion API + Zapier/Make**:
   - Create a database view filtered by Status = "Done"
   - Use Zapier/Make to monitor this view
   - Send webhook to n8n when new items appear

2. **Using Notion API directly**:
   - Create a script that monitors your Notion database
   - When status changes to "done", format and send the payload

3. **Manual trigger for testing**:
   - Use a tool like Postman or curl to test:
   ```bash
   curl -X POST https://your-n8n-instance.com/webhook/notion-project-done \
     -H "Content-Type: application/json" \
     -d '{
       "projectName": "Test Project",
       "projectDescription": "This is a test project",
       "completionDate": "2024-01-15",
       "teamMembers": ["Alice", "Bob"],
       "deliverables": ["Feature A", "Feature B"]
     }'
   ```

## Customization Options

### Modify the OpenAI Prompt
Edit the system message in the "OpenAI Process" node to change how summaries are formatted.

### Add Additional Processing
- Add a Filter node to only process certain types of projects
- Add a Code node to transform data before sending to OpenAI
- Add multiple Slack nodes to send to different channels based on project type

### Enhanced Slack Formatting
The workflow includes Slack Block Kit formatting for rich messages. You can customize the blocks in the "Send to Slack" node.

## Troubleshooting

1. **Webhook not receiving data**: 
   - Ensure the workflow is activated (toggle the Active switch)
   - Check the webhook URL is correct
   - Verify n8n is accessible from the internet (use ngrok for local testing)

2. **OpenAI errors**:
   - Verify your API key is valid
   - Check you have credits in your OpenAI account
   - Try using a different model if rate limited

3. **Slack posting fails**:
   - Ensure the bot has access to the channel
   - Verify OAuth scopes are correct
   - Check the channel ID is valid (not the channel name)

## Testing the Workflow

1. Activate the workflow in n8n
2. Use the test curl command above
3. Check your Slack channel for the notification
4. View execution history in n8n for debugging

## Production Considerations

- Set up error handling nodes for failed API calls
- Add logging for audit trails
- Consider rate limiting for high-volume projects
- Use n8n's built-in monitoring for workflow health