![n8n.io - Workflow Automation](https://user-images.githubusercontent.com/65276001/173571060-9f2f6d7b-bac0-43b6-bdb2-001da9694058.png)

# n8n-editor-ui

The visual workflow editor and frontend interface for n8n workflow automation.

This package contains the complete Vue.js frontend application that provides the intuitive drag-and-drop workflow editor, node configuration interfaces, execution monitoring, and user management features.

## 🏗️ Architecture Overview

The editor-ui is built with modern frontend technologies:

- **Vue 3**: Progressive JavaScript framework with Composition API
- **TypeScript**: Type-safe development with comprehensive type definitions
- **Pinia**: Lightweight state management with excellent TypeScript support
- **Vue Router**: Client-side routing for single-page application
- **Element Plus**: Rich UI component library for consistent design
- **Vue Flow**: Powerful node-based graph visualization
- **Vite**: Fast build tool with hot module replacement

## 🚀 Key Features

### Visual Workflow Editor
- **Drag & Drop Interface**: Intuitive node placement and connection
- **Real-time Canvas**: Live workflow visualization with zoom and pan
- **Node Configuration**: Dynamic parameter forms with validation
- **Expression Editor**: CodeMirror-based expression editing with autocomplete
- **Execution Visualization**: Real-time workflow execution tracking

### User Experience
- **Responsive Design**: Works seamlessly across desktop and tablet devices
- **Dark/Light Theme**: User preference based theming
- **Internationalization**: Multi-language support with Vue i18n
- **Accessibility**: WCAG compliant interface design
- **Keyboard Shortcuts**: Power user functionality

### Development Tools
- **Component Storybook**: Isolated component development and testing
- **Type Safety**: Comprehensive TypeScript coverage
- **Testing Suite**: Unit tests with Vitest and E2E tests with Cypress
- **Hot Reload**: Fast development with instant feedback

## 📦 Installation

```bash
# Install dependencies
pnpm install

# Start development server
pnpm dev
```

## 🛠️ Development

### Development Commands

```bash
# Start development server with hot reload
pnpm serve

# Build for production
pnpm build

# Run type checking
pnpm typecheck

# Watch type checking
pnpm typecheck:watch

# Run linting
pnpm lint

# Fix linting issues
pnpm lintfix

# Format code
pnpm format

# Check formatting
pnpm format:check

# Run unit tests
pnpm test

# Run tests in watch mode
pnpm test:dev
```

### Development Server

The development server runs on `http://localhost:8080` and connects to the n8n backend at `http://localhost:5678` by default.

```bash
# Start with custom backend URL
VUE_APP_URL_BASE_API=http://localhost:5678/ pnpm serve

# Start with custom host and port
pnpm serve --host 0.0.0.0 --port 3000
```

## 🏛️ Architecture Details

### State Management (Pinia)

The application uses Pinia stores for centralized state management:

```typescript
// stores/workflows.store.ts
export const useWorkflowsStore = defineStore('workflows', () => {
  const workflows = ref<IWorkflowShortResponse[]>([]);
  const activeWorkflow = ref<IWorkflowDb | null>(null);

  const fetchWorkflows = async () => {
    const response = await workflowsApi.getWorkflows();
    workflows.value = response;
  };

  const setActiveWorkflow = (workflow: IWorkflowDb) => {
    activeWorkflow.value = workflow;
  };

  return {
    workflows: readonly(workflows),
    activeWorkflow: readonly(activeWorkflow),
    fetchWorkflows,
    setActiveWorkflow,
  };
});
```

#### Core Stores

- **UI Store**: Manages global UI state, theme, and notifications
- **Settings Store**: Application and user settings
- **Users Store**: User authentication and management
- **Workflows Store**: Workflow CRUD operations and caching
- **Executions Store**: Workflow execution history and monitoring
- **Nodes Store**: Node types, credentials, and configuration
- **Canvas Store**: Workflow editor canvas state

### Component Architecture

The application follows a hierarchical component structure:

```
src/
├── components/           # Reusable UI components
│   ├── Node/            # Node-related components
│   ├── MainPanel/       # Main editor panel
│   ├── ParameterInput/  # Node parameter inputs
│   └── ...
├── views/               # Route-level pages
├── composables/         # Vue composition functions
├── stores/              # Pinia state stores
├── api/                 # API client functions
├── utils/               # Utility functions
├── types/               # TypeScript type definitions
└── styles/              # Global styles and themes
```

### Routing Structure

```typescript
// router/index.ts
const routes = [
  {
    path: '/',
    name: 'home',
    component: () => import('@/views/NodeView.vue'),
  },
  {
    path: '/workflow/:workflowId',
    name: 'workflow',
    component: () => import('@/views/NodeView.vue'),
  },
  {
    path: '/workflows',
    name: 'workflows',
    component: () => import('@/views/WorkflowsView.vue'),
  },
  {
    path: '/executions',
    name: 'executions',
    component: () => import('@/views/ExecutionsView.vue'),
  },
  {
    path: '/settings',
    name: 'settings',
    component: () => import('@/views/SettingsView.vue'),
  },
];
```

## 🎨 Theming and Design System

### Design Tokens

The application uses a comprehensive design system with CSS custom properties:

```scss
// styles/variables.scss
:root {
  // Colors
  --color-primary: #ff6d5a;
  --color-secondary: #7c3aed;
  --color-success: #10b981;
  --color-warning: #f59e0b;
  --color-danger: #ef4444;

  // Typography
  --font-family-primary: 'Open Sans', sans-serif;
  --font-family-monospace: 'Monaco', 'Menlo', monospace;

  // Spacing
  --spacing-5xs: 2px;
  --spacing-4xs: 4px;
  --spacing-3xs: 6px;
  --spacing-2xs: 8px;
  --spacing-xs: 12px;
  --spacing-s: 16px;
  --spacing-m: 20px;
  --spacing-l: 24px;
  --spacing-xl: 32px;
}
```

### Component Styling

Components use scoped styles with SCSS modules:

```vue
<template>
  <div :class="$style.container">
    <h2 :class="$style.title">Workflow Editor</h2>
    <div :class="$style.content">
      <!-- Component content -->
    </div>
  </div>
</template>

<style lang="scss" module>
.container {
  display: flex;
  flex-direction: column;
  height: 100vh;
  background: var(--color-background);
}

.title {
  font-size: var(--font-size-xl);
  color: var(--color-text-dark);
  margin-bottom: var(--spacing-s);
}

.content {
  flex: 1;
  overflow: hidden;
}
</style>
```

## 🔧 API Integration

### HTTP Client

The application uses Axios for HTTP requests with type safety:

```typescript
// api/workflows.api.ts
import { makeRestApiRequest } from '@/utils/apiUtils';
import type { IWorkflowShortResponse, IWorkflowDb } from 'n8n-workflow';

export const workflowsApi = {
  async getWorkflows(): Promise<IWorkflowShortResponse[]> {
    return await makeRestApiRequest('GET', '/workflows');
  },

  async getWorkflow(id: string): Promise<IWorkflowDb> {
    return await makeRestApiRequest('GET', `/workflows/${id}`);
  },

  async createWorkflow(workflow: Partial<IWorkflowDb>): Promise<IWorkflowDb> {
    return await makeRestApiRequest('POST', '/workflows', workflow);
  },

  async updateWorkflow(id: string, workflow: Partial<IWorkflowDb>): Promise<IWorkflowDb> {
    return await makeRestApiRequest('PATCH', `/workflows/${id}`, workflow);
  },

  async deleteWorkflow(id: string): Promise<void> {
    return await makeRestApiRequest('DELETE', `/workflows/${id}`);
  },
};
```

### Error Handling

Centralized error handling with user-friendly messages:

```typescript
// composables/useToast.ts
export const useToast = () => {
  const showMessage = (config: {
    title: string;
    message?: string;
    type?: 'success' | 'error' | 'warning' | 'info';
    duration?: number;
  }) => {
    ElNotification({
      title: config.title,
      message: config.message,
      type: config.type || 'info',
      duration: config.duration || 4000,
    });
  };

  const showError = (error: Error | string, title = 'Error') => {
    const message = typeof error === 'string' ? error : error.message;
    showMessage({ title, message, type: 'error' });
  };

  return { showMessage, showError };
};
```

## 🧪 Testing

### Unit Testing with Vitest

```typescript
// components/__tests__/WorkflowCard.test.ts
import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import { createPinia } from 'pinia';
import WorkflowCard from '../WorkflowCard.vue';

describe('WorkflowCard', () => {
  it('renders workflow information correctly', () => {
    const wrapper = mount(WorkflowCard, {
      global: {
        plugins: [createPinia()],
      },
      props: {
        workflow: {
          id: '1',
          name: 'Test Workflow',
          active: true,
          nodes: [],
          connections: {},
        },
      },
    });

    expect(wrapper.find('[data-test-id="workflow-name"]').text()).toBe('Test Workflow');
    expect(wrapper.find('[data-test-id="workflow-status"]').text()).toBe('Active');
  });
});
```

### Component Testing

```typescript
// composables/__tests__/useWorkflowHelpers.test.ts
import { describe, it, expect } from 'vitest';
import { useWorkflowHelpers } from '../useWorkflowHelpers';

describe('useWorkflowHelpers', () => {
  it('should validate workflow correctly', () => {
    const { validateWorkflow } = useWorkflowHelpers();
    
    const validWorkflow = {
      nodes: [
        { id: '1', type: 'n8n-nodes-base.start', name: 'Start' },
        { id: '2', type: 'n8n-nodes-base.set', name: 'Set' },
      ],
      connections: {
        'Start': { main: [[{ node: 'Set', type: 'main', index: 0 }]] },
      },
    };

    const result = validateWorkflow(validWorkflow);
    expect(result.isValid).toBe(true);
  });
});
```

## 📱 Responsive Design

The application adapts to different screen sizes:

```scss
// styles/responsive.scss
@mixin mobile {
  @media (max-width: 768px) {
    @content;
  }
}

@mixin tablet {
  @media (min-width: 769px) and (max-width: 1024px) {
    @content;
  }
}

@mixin desktop {
  @media (min-width: 1025px) {
    @content;
  }
}

// Usage in components
.workflow-editor {
  display: grid;
  grid-template-columns: 300px 1fr 400px;

  @include tablet {
    grid-template-columns: 250px 1fr 300px;
  }

  @include mobile {
    grid-template-columns: 1fr;
    grid-template-rows: auto 1fr auto;
  }
}
```

## 🌐 Internationalization

Multi-language support with Vue i18n:

```typescript
// i18n/locales/en.json
{
  "workflows": {
    "title": "Workflows",
    "create": "Create Workflow",
    "edit": "Edit Workflow",
    "delete": "Delete Workflow",
    "confirmDelete": "Are you sure you want to delete this workflow?"
  },
  "nodes": {
    "addNode": "Add Node",
    "deleteNode": "Delete Node",
    "configureNode": "Configure Node"
  }
}
```

```vue
<template>
  <div>
    <h1>{{ $t('workflows.title') }}</h1>
    <button @click="createWorkflow">
      {{ $t('workflows.create') }}
    </button>
  </div>
</template>
```

## 🔧 Build Configuration

### Vite Configuration

```typescript
// vite.config.ts
export default defineConfig({
  plugins: [
    vue(),
    legacy({
      targets: ['defaults', 'not IE 11'],
    }),
    ViteComponents({
      resolvers: [ElementPlusResolver()],
    }),
    Icons({
      autoInstall: true,
    }),
  ],
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src'),
      '~': resolve(__dirname, 'src'),
    },
  },
  define: {
    // Global constants
    __APP_VERSION__: JSON.stringify(process.env.npm_package_version),
  },
  build: {
    target: 'es2015',
    sourcemap: true,
    rollupOptions: {
      output: {
        manualChunks: {
          'vue-vendor': ['vue', 'vue-router', 'pinia'],
          'ui-vendor': ['element-plus'],
          'utils-vendor': ['lodash', 'axios'],
        },
      },
    },
  },
});
```

### Environment Variables

```bash
# .env.development
VUE_APP_URL_BASE_API=http://localhost:5678/
VUE_APP_MAX_PINNED_DATA_SIZE=16384
VUE_APP_PUBLIC_PATH=/
```

## 🚀 Performance Optimization

### Code Splitting

```typescript
// Lazy loading routes
const routes = [
  {
    path: '/workflows',
    component: () => import('@/views/WorkflowsView.vue'),
  },
  {
    path: '/executions',
    component: () => import('@/views/ExecutionsView.vue'),
  },
];

// Dynamic component loading
const LazyNodeIcon = defineAsyncComponent(
  () => import('@/components/NodeIcon.vue')
);
```

### Virtual Scrolling

For large lists of workflows and executions:

```vue
<template>
  <VirtualList
    :items="workflows"
    :item-height="60"
    :container-height="400"
  >
    <template #default="{ item }">
      <WorkflowCard :workflow="item" />
    </template>
  </VirtualList>
</template>
```

## 🤝 Contributing

### Development Setup

1. **Clone the repository**
2. **Install dependencies**: `pnpm install`
3. **Start backend**: `pnpm start` (in root directory)
4. **Start frontend**: `pnpm serve` (in this directory)

### Code Standards

- Use Vue 3 Composition API
- Follow TypeScript best practices
- Implement comprehensive unit tests
- Use scoped CSS modules
- Follow accessibility guidelines
- Maintain design system consistency

### Component Guidelines

```vue
<!-- Good: Composition API with TypeScript -->
<script setup lang="ts">
import { ref, computed } from 'vue';
import type { IWorkflowShortResponse } from 'n8n-workflow';

interface Props {
  workflow: IWorkflowShortResponse;
  readonly?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  readonly: false,
});

const emit = defineEmits<{
  update: [workflow: IWorkflowShortResponse];
  delete: [id: string];
}>();

const isEditing = ref(false);
const displayName = computed(() => props.workflow.name || 'Untitled');
</script>
```

## 📋 Browser Support

- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

## 🔗 Related Packages

- **@n8n/design-system**: Shared UI components
- **@n8n/stores**: Pinia stores
- **@n8n/composables**: Vue composables
- **n8n-workflow**: Core workflow types

## 📄 License

You can find the license information [here](https://github.com/n8n-io/n8n/blob/master/README.md#license)
