![n8n.io - Workflow Automation](https://user-images.githubusercontent.com/65276001/173571060-9f2f6d7b-bac0-43b6-bdb2-001da9694058.png)

# n8n-core

The core execution engine and foundational components for n8n workflow automation.

This package contains the essential building blocks that power n8n's workflow execution, including the execution engine, credential management, node loading, and core utilities.

## 🏗️ Architecture Overview

The n8n-core package serves as the backbone of the n8n workflow automation platform, providing:

- **Workflow Execution Engine**: Orchestrates the execution of workflows with proper error handling and data flow
- **Node Management**: Dynamic loading and instantiation of workflow nodes
- **Credential System**: Secure credential storage and retrieval with encryption support
- **Binary Data Handling**: Efficient processing of binary data (files, images, etc.)
- **Expression Resolution**: JavaScript expression evaluation within workflow contexts
- **Webhook Management**: HTTP webhook endpoints for external integrations
- **Queue Management**: Background job processing with Bull queue system

## 📦 Installation

```bash
npm install n8n-core
```

## 🚀 Key Components

### WorkflowExecute

The main workflow execution engine that processes workflow definitions:

```typescript
import { WorkflowExecute } from 'n8n-core';

const workflowExecute = new WorkflowExecute(
  additionalData,
  mode
);

const result = await workflowExecute.run(
  workflow,
  startNode,
  destinationNode
);
```

### LoadNodesAndCredentials

Manages dynamic loading of nodes and credentials:

```typescript
import { LoadNodesAndCredentials } from 'n8n-core';

const loadNodesAndCredentials = new LoadNodesAndCredentials();
await loadNodesAndCredentials.init();

// Access loaded nodes
const nodeTypes = loadNodesAndCredentials.nodeTypes;
```

### CredentialsHelper

Handles credential management and encryption:

```typescript
import { CredentialsHelper } from 'n8n-core';

const credentialsHelper = new CredentialsHelper(encryptionKey);
const decryptedData = credentialsHelper.decrypt(
  credentialType,
  encryptedData
);
```

### BinaryDataManager

Manages binary data storage and retrieval:

```typescript
import { BinaryDataManager } from 'n8n-core';

const binaryDataManager = BinaryDataManager.getInstance();
const binaryData = await binaryDataManager.retrieveBinaryData(
  binaryDataId
);
```

## 🔧 Core Features

### Workflow Execution

The execution engine supports multiple execution modes:

- **Manual**: Interactive execution triggered by user
- **Trigger**: Automated execution from external triggers
- **Webhook**: HTTP-triggered execution
- **Error**: Recovery execution after failures
- **Retry**: Automatic retry of failed executions

### Node System

Nodes are the building blocks of workflows:

- **Regular Nodes**: Standard data processing nodes
- **Trigger Nodes**: Nodes that start workflow execution
- **Webhook Nodes**: HTTP endpoint nodes
- **Poll Nodes**: Nodes that periodically check for changes

### Expression System

Dynamic value resolution using JavaScript expressions:

```javascript
// Access current item data
{{ $json.fieldName }}

// Access workflow variables
{{ $workflow.name }}

// Access execution data
{{ $execution.id }}

// Use built-in functions
{{ $now }}
{{ $today }}
{{ $uuid() }}
```

### Binary Data

Efficient handling of files and binary content:

- Automatic file type detection
- Stream processing for large files
- Multiple storage backends (filesystem, S3, etc.)
- Memory optimization for binary operations

## 🛠️ Development

### Building

```bash
# Build the package
pnpm build

# Watch for changes during development
pnpm watch

# Run type checking
pnpm typecheck
```

### Testing

```bash
# Run unit tests
pnpm test

# Run tests in watch mode
pnpm test:dev
```

### Configuration

The core package is configured through environment variables and the global n8n configuration system:

```typescript
import { config } from 'n8n-core';

// Access configuration values
const encryptionKey = config.getEnv('N8N_ENCRYPTION_KEY');
const executionTimeout = config.getEnv('EXECUTIONS_TIMEOUT');
```

## 🔐 Security

### Credential Encryption

All credentials are encrypted using AES-256-GCM:

- Encryption key must be set via `N8N_ENCRYPTION_KEY`
- Keys are automatically generated if not provided
- Different environments should use different keys

### Expression Sandbox

JavaScript expressions run in a sandboxed environment:

- No access to Node.js built-in modules
- Restricted global object access
- Timeout protection for long-running expressions

## 📊 Performance

### Memory Management

- Streaming binary data processing
- Efficient garbage collection
- Memory usage monitoring and limits

### Execution Optimization

- Parallel node execution where possible
- Smart data passing between nodes
- Execution plan optimization

## 🔗 Integration with Other Packages

### Dependencies

- **n8n-workflow**: Core workflow interfaces and types
- **@n8n/config**: Configuration management
- **@n8n/decorators**: Dependency injection decorators

### Used By

- **n8n-cli**: Main CLI application
- **n8n-nodes-base**: Base node implementations
- **@n8n/task-runner**: External task execution

## 📋 API Reference

### WorkflowExecute

Main execution class for running workflows.

#### Constructor

```typescript
constructor(
  additionalData: IWorkflowExecuteAdditionalData,
  mode: WorkflowExecuteMode,
  runExecutionData?: IRunExecutionData
)
```

#### Methods

- `run()`: Execute a complete workflow
- `runNode()`: Execute a single node
- `runPartialWorkflow()`: Execute part of a workflow

### NodeHelpers

Utility functions for node operations:

- `getNodeParameter()`: Get parameter values from nodes
- `getNodeCredentials()`: Retrieve node credentials
- `getBinaryData()`: Access binary data from items

## 🐛 Debugging

Enable debug logging:

```bash
DEBUG=n8n:core:* npm start
```

Common debug categories:
- `n8n:core:execution`: Workflow execution
- `n8n:core:credentials`: Credential operations
- `n8n:core:binary`: Binary data handling

## 🤝 Contributing

This package is part of the n8n monorepo. See the main [CLAUDE.md](../../../CLAUDE.md) for development guidelines.

### Code Style

- TypeScript strict mode enabled
- ESLint and Prettier formatting
- Comprehensive unit tests required
- JSDoc documentation for public APIs

## 📄 License

You can find the license information [here](https://github.com/n8n-io/n8n/blob/master/README.md#license)
