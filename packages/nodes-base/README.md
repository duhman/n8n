![n8n.io - Workflow Automation](https://user-images.githubusercontent.com/65276001/173571060-9f2f6d7b-bac0-43b6-bdb2-001da9694058.png)

# n8n-nodes-base

The complete collection of built-in nodes and credentials for n8n workflow automation.

This package contains 400+ production-ready integrations with popular services, APIs, databases, and tools. Each node is carefully crafted to provide a consistent and reliable integration experience.

## 🏗️ Architecture Overview

The nodes-base package provides:

- **400+ Integration Nodes**: Pre-built connectors for popular services
- **Credential Management**: Secure authentication for all integrations
- **Consistent API**: Standardized interface across all nodes
- **Type Safety**: Full TypeScript support with comprehensive types
- **Testing Framework**: Extensive test coverage for reliability
- **Documentation**: Built-in help and examples for each node

## 📦 Installation

```bash
npm install n8n-nodes-base
```

## 🔧 Available Integrations

### Communication & Messaging
- **Discord**: Send messages, manage servers, handle webhooks
- **Slack**: Post messages, manage channels, file operations
- **Telegram**: Send messages, handle bot interactions
- **WhatsApp**: Business API integration for messaging
- **Matrix**: Decentralized chat protocol support
- **Mattermost**: Team collaboration platform

### Cloud Services & Storage
- **AWS**: S3, Lambda, SES, SQS, SNS, and more AWS services
- **Google Cloud**: Storage, BigQuery, Natural Language, Firebase
- **Microsoft Azure**: Storage, Cosmos DB, Monitor
- **Dropbox**: File storage and sharing
- **Box**: Enterprise file storage
- **OneDrive**: Microsoft cloud storage

### Databases & Data Stores
- **PostgreSQL**: Full SQL database operations
- **MySQL**: Relational database management
- **MongoDB**: Document database operations
- **Redis**: In-memory data structure store
- **Elasticsearch**: Search and analytics engine
- **InfluxDB**: Time series database

### CRM & Sales
- **HubSpot**: Complete CRM and marketing automation
- **Salesforce**: Enterprise CRM platform
- **Pipedrive**: Sales pipeline management
- **Airtable**: Collaborative database platform
- **Notion**: All-in-one workspace
- **Copper**: Google Workspace native CRM

### Marketing & Analytics
- **Mailchimp**: Email marketing campaigns
- **SendGrid**: Email delivery service
- **Google Analytics**: Web analytics
- **Facebook**: Social media marketing
- **Twitter**: Social media automation
- **LinkedIn**: Professional networking

### Developer Tools & APIs
- **GitHub**: Git repository management
- **GitLab**: DevOps platform
- **Jenkins**: Continuous integration
- **HTTP Request**: Generic API calls
- **Webhook**: HTTP webhook handling
- **GraphQL**: GraphQL API queries

### E-commerce & Payments
- **Shopify**: E-commerce platform
- **WooCommerce**: WordPress e-commerce
- **Stripe**: Payment processing
- **PayPal**: Online payments
- **QuickBooks**: Accounting software

### Productivity & Project Management
- **Trello**: Kanban-style project management
- **Asana**: Team task management
- **Monday.com**: Work operating system
- **ClickUp**: All-in-one productivity
- **Jira**: Issue tracking and project management
- **Linear**: Modern issue tracking

## 🛠️ Node Development

### Creating a New Node

1. **Create the node directory structure**:
```
nodes/
  YourService/
    YourService.node.ts
    YourService.node.json
    yourService.svg
    YourServiceTrigger.node.ts (if needed)
```

2. **Implement the node class**:
```typescript
import {
  IExecuteFunctions,
  INodeExecutionData,
  INodeType,
  INodeTypeDescription,
  NodeOperationError,
} from 'n8n-workflow';

export class YourService implements INodeType {
  description: INodeTypeDescription = {
    displayName: 'Your Service',
    name: 'yourService',
    icon: 'file:yourService.svg',
    group: ['communication'],
    version: 1,
    subtitle: '={{$parameter["operation"] + ": " + $parameter["resource"]}}',
    description: 'Interact with Your Service API',
    defaults: {
      name: 'Your Service',
    },
    inputs: ['main'],
    outputs: ['main'],
    credentials: [
      {
        name: 'yourServiceApi',
        required: true,
      },
    ],
    properties: [
      {
        displayName: 'Resource',
        name: 'resource',
        type: 'options',
        noDataExpression: true,
        options: [
          {
            name: 'User',
            value: 'user',
          },
          {
            name: 'Message',
            value: 'message',
          },
        ],
        default: 'user',
      },
      {
        displayName: 'Operation',
        name: 'operation',
        type: 'options',
        noDataExpression: true,
        displayOptions: {
          show: {
            resource: ['user'],
          },
        },
        options: [
          {
            name: 'Create',
            value: 'create',
            description: 'Create a new user',
            action: 'Create a user',
          },
          {
            name: 'Get',
            value: 'get',
            description: 'Get a user',
            action: 'Get a user',
          },
        ],
        default: 'create',
      },
    ],
  };

  async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
    const items = this.getInputData();
    const returnData: INodeExecutionData[] = [];
    
    const resource = this.getNodeParameter('resource', 0);
    const operation = this.getNodeParameter('operation', 0);

    for (let i = 0; i < items.length; i++) {
      try {
        if (resource === 'user') {
          if (operation === 'create') {
            // Implementation for creating a user
            const name = this.getNodeParameter('name', i) as string;
            const email = this.getNodeParameter('email', i) as string;
            
            const responseData = await this.helpers.request({
              method: 'POST',
              url: 'https://api.yourservice.com/users',
              body: {
                name,
                email,
              },
              json: true,
            });

            returnData.push({
              json: responseData,
              pairedItem: { item: i },
            });
          }
        }
      } catch (error) {
        if (this.continueOnFail()) {
          returnData.push({
            json: { error: error.message },
            pairedItem: { item: i },
          });
          continue;
        }
        throw new NodeOperationError(this.getNode(), error, {
          itemIndex: i,
        });
      }
    }

    return [returnData];
  }
}
```

3. **Create credential file**:
```typescript
// credentials/YourServiceApi.credentials.ts
import {
  IAuthenticateGeneric,
  ICredentialType,
  INodeProperties,
} from 'n8n-workflow';

export class YourServiceApi implements ICredentialType {
  name = 'yourServiceApi';
  displayName = 'Your Service API';
  documentationUrl = 'https://docs.yourservice.com/api';
  properties: INodeProperties[] = [
    {
      displayName: 'API Key',
      name: 'apiKey',
      type: 'string',
      typeOptions: { password: true },
      default: '',
    },
  ];

  authenticate: IAuthenticateGeneric = {
    type: 'generic',
    properties: {
      headers: {
        'Authorization': '=Bearer {{$credentials.apiKey}}',
      },
    },
  };
}
```

4. **Register the node and credentials**:
Add entries to `package.json`:
```json
{
  "n8n": {
    "nodes": [
      "dist/nodes/YourService/YourService.node.js"
    ],
    "credentials": [
      "dist/credentials/YourServiceApi.credentials.js"
    ]
  }
}
```

### Node Development Best Practices

#### Error Handling
```typescript
try {
  const responseData = await this.helpers.request(options);
} catch (error) {
  if (this.continueOnFail()) {
    returnData.push({
      json: { error: error.message },
      pairedItem: { item: i },
    });
    continue;
  }
  throw new NodeOperationError(this.getNode(), error, {
    itemIndex: i,
  });
}
```

#### Pagination Support
```typescript
let responseData;
const returnData: IDataObject[] = [];

do {
  responseData = await this.helpers.request({
    method: 'GET',
    url: `https://api.service.com/data?page=${page}`,
    json: true,
  });
  
  returnData.push(...responseData.items);
  page++;
} while (responseData.hasMore);
```

#### Binary Data Handling
```typescript
// Downloading files
const binaryData = await this.helpers.request({
  method: 'GET',
  url: downloadUrl,
  encoding: null,
});

const fileName = 'downloaded-file.pdf';
const binaryDataBuffer = await this.helpers.prepareBinaryData(
  binaryData,
  fileName
);

returnData.push({
  json: { fileName },
  binary: {
    data: binaryDataBuffer,
  },
});
```

#### OAuth 2.0 Authentication
```typescript
// In credentials file
export class ServiceOAuth2Api implements ICredentialType {
  name = 'serviceOAuth2Api';
  extends = ['oAuth2Api'];
  properties: INodeProperties[] = [
    {
      displayName: 'Grant Type',
      name: 'grantType',
      type: 'hidden',
      default: 'authorizationCode',
    },
    {
      displayName: 'Authorization URL',
      name: 'authUrl',
      type: 'hidden',
      default: 'https://api.service.com/oauth/authorize',
    },
    {
      displayName: 'Access Token URL',
      name: 'accessTokenUrl',
      type: 'hidden',
      default: 'https://api.service.com/oauth/token',
    },
  ];
}
```

## 🧪 Testing

### Unit Tests
Create comprehensive tests for your nodes:

```typescript
// test/nodes/YourService/YourService.node.test.ts
import { testWorkflows, getWorkflowFilenames } from '@test/nodes/Helpers';

const workflows = getWorkflowFilenames(__dirname);

describe('Test YourService Node', () => testWorkflows(workflows));
```

### Integration Tests
Test with real API responses:

```typescript
describe('YourService Integration', () => {
  it('should create user successfully', async () => {
    const workflow = {
      nodes: [
        {
          parameters: {
            resource: 'user',
            operation: 'create',
            name: 'Test User',
            email: 'test@example.com',
          },
          id: 'yourservice-node',
          name: 'Your Service',
          type: 'n8n-nodes-base.yourService',
          typeVersion: 1,
          position: [250, 300],
        },
      ],
      connections: {},
    };

    const response = await executeWorkflow(workflow);
    expect(response.data.main[0][0].json).toHaveProperty('id');
  });
});
```

## 🔧 Development Commands

```bash
# Build all nodes
pnpm build

# Watch for changes during development
pnpm watch

# Run linting
pnpm lint

# Fix linting issues
pnpm lintfix

# Run tests
pnpm test

# Type checking
pnpm typecheck

# Generate metadata
pnpm n8n-generate-metadata
```

## 📁 Project Structure

```
nodes-base/
├── credentials/           # Authentication configurations
├── nodes/                # Node implementations
│   ├── ServiceName/
│   │   ├── ServiceName.node.ts
│   │   ├── ServiceName.node.json
│   │   ├── serviceName.svg
│   │   └── ServiceNameTrigger.node.ts
├── test/                 # Test files
├── utils/                # Shared utilities
└── package.json          # Package configuration
```

## 🔐 Security Guidelines

### Credential Security
- Never log credential data
- Use proper TypeScript types for credentials
- Implement credential validation
- Use secure defaults for authentication methods

### API Security
- Validate all input parameters
- Implement proper rate limiting respect
- Handle API errors gracefully
- Use HTTPS for all external requests

### Data Privacy
- Respect user data privacy
- Implement data sanitization
- Follow GDPR and privacy guidelines
- Provide clear data usage documentation

## 📊 Performance Guidelines

### Memory Optimization
- Stream large files instead of loading into memory
- Use pagination for large datasets
- Implement proper cleanup for resources
- Monitor memory usage in tests

### API Efficiency
- Use bulk operations when available
- Implement proper caching strategies
- Batch API requests where possible
- Respect API rate limits

## 🤝 Contributing

### Adding New Nodes

1. **Check existing nodes** for similar functionality
2. **Follow naming conventions** (PascalCase for classes, camelCase for files)
3. **Implement comprehensive error handling**
4. **Add proper TypeScript types**
5. **Include unit and integration tests**
6. **Add proper documentation**
7. **Follow the existing code style**

### Code Review Checklist

- [ ] Follows TypeScript best practices
- [ ] Implements proper error handling
- [ ] Includes comprehensive tests
- [ ] Has proper documentation
- [ ] Follows security guidelines
- [ ] Respects API rate limits
- [ ] Uses consistent naming conventions

### Node Guidelines

- Use clear, descriptive parameter names
- Implement `continueOnFail` support
- Provide helpful error messages
- Add tooltips and descriptions for parameters
- Support both simple and advanced use cases
- Follow the existing UI patterns

## 📋 Available Node Types

### Regular Nodes
Standard data processing nodes that execute when triggered.

### Trigger Nodes
Nodes that start workflow execution based on external events.

### Poll Nodes
Nodes that periodically check for changes and trigger workflows.

### Webhook Nodes
Nodes that create HTTP endpoints for external integrations.

### Transform Nodes
Utility nodes for data manipulation and transformation.

## 🔗 Related Packages

- **n8n-workflow**: Core interfaces and types
- **n8n-core**: Execution engine
- **n8n-editor-ui**: Frontend interface
- **@n8n/design-system**: UI components

## 📄 License

You can find the license information [here](https://github.com/n8n-io/n8n/blob/master/README.md#license)
