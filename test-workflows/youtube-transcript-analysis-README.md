# YouTube Transcript Analysis & Slack Notification Workflow

This n8n workflow automatically monitors a YouTube channel for new videos, extracts transcripts, analyzes them with OpenAI, and sends a summary to your Slack account as a direct message.

## Workflow Overview

The workflow consists of the following nodes:

1. **Channel Config** - Configuration settings for the workflow
2. **RSS YouTube Channel Monitor** - Monitors YouTube channel RSS feed for new videos
3. **Extract Video ID** - Extracts YouTube video ID from RSS feed data
4. **Clean Transcript** - Preprocesses and cleans raw transcript data
5. **Get Video Transcript** - Fetches transcript using a third-party API
6. **Validate Transcript** - Ensures transcript is valid and meaningful
7. **Analyze with OpenAI** - Uses GPT-4o-mini to analyze and summarize the transcript
8. **Send Slack Summary** - Sends formatted summary as Slack DM

## Setup Instructions

### 1. Configure Channel Settings

In the **Channel Config** node, update these values:

- `channel_id`: Replace `UCJ0-OtVpF0wOKEqT2Z1HEtA` with your target YouTube channel ID
  - Find channel ID: Go to channel page → View source → Search for `"channelId":"` or use tools like [YouTube Channel ID Finder](https://www.streamweasels.com/tools/youtube-channel-id-and-user-id-convertor/)
- `slack_user_id`: Replace `@your-username` with your Slack username (e.g., `@john.doe`)
- `analysis_prompt`: Customize the AI analysis prompt as needed

### 2. Set Up Credentials

You'll need to configure these credentials in n8n:

#### OpenAI Credentials
- Go to n8n Settings → Credentials → Add Credential
- Select "OpenAI"
- Add your OpenAI API key
- The workflow uses GPT-4o-mini (cost-effective for summaries)

#### Slack Credentials  
- Go to n8n Settings → Credentials → Add Credential
- Select "Slack OAuth2 API"
- Follow the OAuth setup process or use a Bot Token
- Required scopes: `chat:write`, `users:read`

### 3. Adjust Monitoring Frequency

The RSS trigger is set to check every 15 minutes. You can modify this in the **RSS YouTube Channel Monitor** node:

- For more frequent checks: Change to every 5-10 minutes
- For less frequent checks: Change to hourly or daily
- Note: YouTube RSS feeds update with some delay after video publication

### 4. Customize Analysis

Modify the analysis prompt in **Channel Config** to focus on specific aspects:

- Technical content: Focus on code examples, tools mentioned
- Educational content: Emphasize learning objectives, key concepts  
- Business content: Highlight insights, actionable advice
- Entertainment: Focus on themes, memorable moments

### 5. Slack Message Format

The workflow sends rich-formatted Slack messages including:

- Video title and publication date
- Direct link to the video
- AI-generated summary with key insights
- Professional formatting with emojis and dividers

## How It Works

1. **Monitoring**: RSS feed is polled at regular intervals for new video entries
2. **Processing**: When a new video is detected, the video ID is extracted
3. **Transcript Retrieval**: Uses `youtubetranscript.com` API to get video transcript
4. **Data Validation**: Ensures transcript is meaningful (>50 characters) 
5. **AI Analysis**: Sends transcript to OpenAI with custom prompt for analysis
6. **Notification**: Formatted summary is sent to your Slack DM

## Troubleshooting

### No Transcripts Available
- Not all YouTube videos have transcripts (auto-generated or manual)
- The transcript API may not work for very new videos
- Private or restricted videos won't have accessible transcripts

### Workflow Not Triggering
- Verify the YouTube channel ID is correct
- Check that the channel regularly publishes new content
- Ensure RSS feed URL is accessible: `https://www.youtube.com/feeds/videos.xml?channel_id=YOUR_CHANNEL_ID`

### OpenAI Errors
- Verify API key is valid and has sufficient credits
- Check if transcript is too long (>4000 tokens) - may need chunking
- Ensure the model (gpt-4o-mini) is accessible with your API key

### Slack Delivery Issues
- Verify Slack credentials have correct scopes
- Ensure your username format is correct (`@username` or user ID)
- Check that the bot/app has permission to send you DMs

## Cost Considerations

- **OpenAI**: GPT-4o-mini is very cost-effective (~$0.00015 per 1K tokens)
- **Transcript API**: Free tier available, paid plans for higher volume
- **n8n**: This workflow uses minimal executions - suitable for all plans

## Customization Ideas

- **Multiple Channels**: Duplicate the workflow for different channels
- **Content Filtering**: Add keywords filtering before analysis
- **Team Notifications**: Send to Slack channels instead of DMs
- **Database Storage**: Add nodes to store summaries in a database
- **Email Notifications**: Alternative/additional notification method
- **Social Media**: Auto-post summaries to Twitter/LinkedIn

## File Location

- Workflow file: `/test-workflows/youtube-transcript-analysis-workflow.json`
- Import this into your n8n instance via the workflow import feature

## Support

For issues with the workflow:
1. Check n8n execution logs for error details
2. Test each node individually to isolate issues  
3. Verify all credentials are properly configured
4. Ensure external APIs (transcript service) are accessible

The workflow is designed to be robust with proper error handling and validation at each step.