![n8n.io - Workflow Automation](https://user-images.githubusercontent.com/65276001/173571060-9f2f6d7b-bac0-43b6-bdb2-001da9694058.png)

# n8n-workflow

Core workflow interfaces, types, and utilities shared between frontend and backend.

This package contains the fundamental building blocks that define how workflows, nodes, and data flow work in n8n. It provides type definitions, interfaces, and utilities that are used across the entire n8n ecosystem.

## 🏗️ Architecture Overview

The n8n-workflow package serves as the foundation for:

- **Workflow Definition**: JSON schema and interfaces for workflow structure
- **Node Interfaces**: Type definitions for creating custom nodes
- **Data Models**: Standardized data structures for workflow execution
- **Expression Evaluation**: JavaScript expression parsing and evaluation
- **Utility Functions**: Common helpers for workflow operations
- **Type Safety**: Comprehensive TypeScript types for the entire system

## 📦 Installation

```bash
npm install n8n-workflow
```

## 🔧 Core Interfaces

### IWorkflowDb

Defines the structure of a workflow stored in the database:

```typescript
interface IWorkflowDb {
  id: string;
  name: string;
  active: boolean;
  nodes: INode[];
  connections: IConnections;
  settings?: IWorkflowSettings;
  staticData?: IDataObject;
  tags?: ITag[];
}
```

### INode

Represents a single node in a workflow:

```typescript
interface INode {
  id: string;
  name: string;
  type: string;
  typeVersion: number;
  position: [number, number];
  parameters: INodeParameters;
  credentials?: INodeCredentials;
  webhookId?: string;
  disabled?: boolean;
}
```

### INodeType

Interface that all node implementations must follow:

```typescript
interface INodeType {
  description: INodeTypeDescription;
  execute?(
    this: IExecuteFunctions,
    items: INodeExecutionData[]
  ): Promise<INodeExecutionData[][]>;
  poll?(
    this: IPollFunctions
  ): Promise<INodeExecutionData[][]>;
  trigger?(
    this: ITriggerFunctions
  ): Promise<ITriggerResponse>;
  webhook?(
    this: IWebhookFunctions
  ): Promise<IWebhookResponseData>;
}
```

### IExecuteFunctions

Context object provided to nodes during execution:

```typescript
interface IExecuteFunctions {
  getNodeParameter(
    parameterName: string,
    itemIndex: number,
    fallbackValue?: any
  ): any;
  
  getCredentials(
    type: string,
    itemIndex?: number
  ): Promise<ICredentialDataDecryptedObject>;
  
  helpers: {
    request(options: IHttpRequestOptions): Promise<any>;
    prepareBinaryData(buffer: Buffer, fileName?: string): Promise<IBinaryData>;
    getBinaryData(itemIndex: number, propertyName: string): Promise<Buffer>;
  };
}
```

## 🚀 Workflow Structure

### Nodes and Connections

Workflows consist of nodes connected by edges:

```typescript
// Example workflow with two connected nodes
const workflow = {
  nodes: [
    {
      id: "start",
      name: "Start",
      type: "n8n-nodes-base.manualTrigger",
      position: [250, 300],
      parameters: {}
    },
    {
      id: "set",
      name: "Set",
      type: "n8n-nodes-base.set",
      position: [450, 300],
      parameters: {
        values: {
          string: [
            {
              name: "message",
              value: "Hello World"
            }
          ]
        }
      }
    }
  ],
  connections: {
    "Start": {
      main: [
        [
          {
            node: "Set",
            type: "main",
            index: 0
          }
        ]
      ]
    }
  }
};
```

### Data Flow

Data flows between nodes as `INodeExecutionData` objects:

```typescript
interface INodeExecutionData {
  json: IDataObject;        // Main JSON data
  binary?: IBinaryKeyData;  // Binary data attachments
  pairedItem?: IPairedItemData; // Connection to input items
  error?: NodeApiError;     // Error information
}

// Example data structure
const nodeData: INodeExecutionData = {
  json: {
    id: 123,
    name: "John Doe",
    email: "john@example.com"
  },
  binary: {
    photo: {
      data: "base64EncodedImageData",
      mimeType: "image/jpeg",
      fileName: "profile.jpg"
    }
  }
};
```

## 🔤 Expression System

### Expression Syntax

n8n uses a mustache-like syntax for dynamic values:

```javascript
// Access current item data
{{ $json.fieldName }}
{{ $binary.fileName }}

// Access workflow context
{{ $workflow.name }}
{{ $workflow.id }}

// Access execution context
{{ $execution.id }}
{{ $execution.mode }}

// Access environment variables
{{ $env.API_KEY }}

// Use built-in functions
{{ $now }}
{{ $today }}
{{ $uuid() }}
{{ $randomInt(1, 100) }}

// JavaScript expressions
{{ $json.items.length > 5 }}
{{ $json.createdAt.split('T')[0] }}
{{ ['apple', 'banana', 'cherry'][$json.index] }}
```

### Expression Resolution

The workflow package provides utilities for resolving expressions:

```typescript
import { 
  resolveExpression,
  getWorkflowResolveMethods 
} from 'n8n-workflow';

const resolved = resolveExpression(
  '{{ $json.name.toUpperCase() }}',
  executionData,
  additionalKeys
);
```

## 🛠️ Node Development

### Creating a Node Type

Implement the `INodeType` interface to create custom nodes:

```typescript
import {
  IExecuteFunctions,
  INodeExecutionData,
  INodeType,
  INodeTypeDescription,
  NodeOperationError,
} from 'n8n-workflow';

export class MyCustomNode implements INodeType {
  description: INodeTypeDescription = {
    displayName: 'My Custom Node',
    name: 'myCustomNode',
    icon: 'file:myCustomNode.svg',
    group: ['transform'],
    version: 1,
    subtitle: '={{$parameter["operation"] + ": " + $parameter["resource"]}}',
    description: 'Performs custom operations',
    defaults: {
      name: 'My Custom Node',
    },
    inputs: ['main'],
    outputs: ['main'],
    credentials: [
      {
        name: 'myCustomNodeApi',
        required: true,
      },
    ],
    properties: [
      {
        displayName: 'Operation',
        name: 'operation',
        type: 'options',
        noDataExpression: true,
        options: [
          {
            name: 'Get Data',
            value: 'getData',
            description: 'Retrieve data from the service',
            action: 'Get data',
          },
        ],
        default: 'getData',
      },
    ],
  };

  async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
    const items = this.getInputData();
    const returnData: INodeExecutionData[] = [];
    const operation = this.getNodeParameter('operation', 0);

    for (let i = 0; i < items.length; i++) {
      try {
        if (operation === 'getData') {
          // Perform the operation
          const responseData = await this.helpers.request({
            method: 'GET',
            url: 'https://api.example.com/data',
          });

          returnData.push({
            json: responseData,
            pairedItem: { item: i },
          });
        }
      } catch (error) {
        if (this.continueOnFail()) {
          returnData.push({
            json: { error: error.message },
            pairedItem: { item: i },
          });
          continue;
        }
        throw new NodeOperationError(this.getNode(), error);
      }
    }

    return [returnData];
  }
}
```

### Node Properties

Define node parameters using property definitions:

```typescript
// Text input
{
  displayName: 'API URL',
  name: 'apiUrl',
  type: 'string',
  default: '',
  placeholder: 'https://api.example.com',
  description: 'The URL of the API endpoint',
}

// Dropdown selection
{
  displayName: 'Operation',
  name: 'operation',
  type: 'options',
  options: [
    { name: 'Create', value: 'create' },
    { name: 'Read', value: 'read' },
    { name: 'Update', value: 'update' },
    { name: 'Delete', value: 'delete' },
  ],
  default: 'read',
}

// Multi-select
{
  displayName: 'Fields to Include',
  name: 'fields',
  type: 'multiOptions',
  options: [
    { name: 'ID', value: 'id' },
    { name: 'Name', value: 'name' },
    { name: 'Email', value: 'email' },
  ],
  default: ['id', 'name'],
}

// JSON editor
{
  displayName: 'JSON Data',
  name: 'jsonData',
  type: 'json',
  default: '{}',
  description: 'JSON data to send',
}
```

## 🔄 Workflow Execution

### Execution Modes

Workflows can be executed in different modes:

- **manual**: User-triggered execution from the editor
- **trigger**: Automatic execution from triggers
- **webhook**: HTTP webhook execution
- **error**: Error recovery execution
- **retry**: Retry after failure
- **dry-run**: Test execution without side effects

### Error Handling

The workflow system provides comprehensive error handling:

```typescript
import { NodeOperationError, NodeApiError } from 'n8n-workflow';

// Throw operation errors
throw new NodeOperationError(
  this.getNode(),
  'Failed to process data',
  { itemIndex: i }
);

// Handle API errors
catch (error) {
  throw new NodeApiError(this.getNode(), error);
}
```

## 🧪 Testing

### Unit Testing

Test node implementations using the workflow utilities:

```typescript
import { WorkflowTestData } from 'n8n-workflow';

describe('MyCustomNode', () => {
  it('should process data correctly', async () => {
    const workflow = new WorkflowTestData({
      nodes: [
        {
          name: 'My Custom Node',
          type: 'myCustomNode',
          parameters: {
            operation: 'getData'
          }
        }
      ]
    });

    const result = await workflow.execute();
    expect(result.data.main[0]).toHaveLength(1);
  });
});
```

## 🔧 Utilities

### Data Transformation

```typescript
import { 
  deepCopy,
  flattenKeys,
  unflattenKeys,
  standardizeArray 
} from 'n8n-workflow';

// Deep copy objects
const copy = deepCopy(originalObject);

// Flatten nested objects
const flat = flattenKeys(nestedObject);

// Convert to array format
const array = standardizeArray(data);
```

### Validation

```typescript
import { validateFieldType } from 'n8n-workflow';

// Validate field types
const isValid = validateFieldType(
  'email',
  'user@example.com',
  'string'
);
```

## 🔗 Integration

This package is used by:

- **n8n-core**: Execution engine
- **n8n-editor-ui**: Frontend interface
- **n8n-nodes-base**: Core node implementations
- **n8n-cli**: Command-line interface

## 📋 Type Definitions

The package exports comprehensive TypeScript definitions:

```typescript
// Import specific types
import {
  INodeExecutionData,
  INodeType,
  IWorkflowExecuteAdditionalData,
  IRunExecutionData
} from 'n8n-workflow';

// Import all types
import * as WorkflowTypes from 'n8n-workflow';
```

## 🤝 Contributing

This package is part of the n8n monorepo. See the main [CLAUDE.md](../../../CLAUDE.md) for development guidelines.

### Development Commands

```bash
# Build the package
pnpm build

# Watch for changes
pnpm watch

# Run type checking
pnpm typecheck

# Run tests
pnpm test
```

## 📄 License

You can find the license information [here](https://github.com/n8n-io/n8n/blob/master/README.md#license)
