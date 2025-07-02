![Banner image](https://user-images.githubusercontent.com/10284570/173569848-c624317f-42b1-45a6-ab09-f0ea3c247648.png)

# n8n - Secure Workflow Automation for Technical Teams

n8n is a workflow automation platform that gives technical teams the flexibility of code with the speed of no-code. With 400+ integrations, native AI capabilities, and a fair-code license, n8n lets you build powerful automations while maintaining full control over your data and deployments.

![n8n.io - Screenshot](https://raw.githubusercontent.com/n8n-io/n8n/master/assets/n8n-screenshot-readme.png)

## Key Capabilities

- **Code When You Need It**: Write JavaScript/Python, add npm packages, or use the visual interface
- **AI-Native Platform**: Build AI agent workflows based on LangChain with your own data and models
- **Full Control**: Self-host with our fair-code license or use our [cloud offering](https://app.n8n.cloud/login)
- **Enterprise-Ready**: Advanced permissions, SSO, and air-gapped deployments
- **Active Community**: 400+ integrations and 900+ ready-to-use [templates](https://n8n.io/workflows)

## Quick Start

Try n8n instantly with [npx](https://docs.n8n.io/hosting/installation/npm/) (requires [Node.js](https://nodejs.org/en/)):

```
npx n8n
```

Or deploy with [Docker](https://docs.n8n.io/hosting/installation/docker/):

```
docker volume create n8n_data
docker run -it --rm --name n8n -p 5678:5678 -v n8n_data:/home/node/.n8n docker.n8n.io/n8nio/n8n
```

Access the editor at http://localhost:5678

## Production Deployment

### Local/VPS Production Setup

For production environments with data persistence and PostgreSQL:

```bash
cd n8n-production
./setup.sh
docker compose up -d
```

See [`n8n-production/README.md`](./n8n-production/README.md) for complete production setup documentation.

### Cloud Deployment - Hetzner

For automated deployment on Hetzner Cloud with SSL, security hardening, and backups:

```bash
# On your Hetzner server
git clone https://github.com/duhman/n8n.git /opt/setup
cd /opt/setup/hetzner-setup
chmod +x *.sh
./initial-setup.sh    # Prepare server
./deploy-n8n.sh       # Deploy n8n
./secure-server.sh     # Add SSL & security
./backup-setup.sh      # Configure backups
```

See [`hetzner-setup/README.md`](./hetzner-setup/README.md) for complete Hetzner deployment guide.

### Cloudflare Containers (Beta)

For serverless deployment on Cloudflare's global edge network:

```bash
cd cloudflare-containers
./deploy.sh
```

See [`cloudflare-containers/`](./cloudflare-containers/) for serverless deployment options.

## Workflow Solutions

### Linear-Notion Project Sync

Comprehensive real-time synchronization between Linear projects and Notion databases:

```bash
# Import ready-to-use workflows
cd linear-notion-sync
# See setup-guide.md for complete instructions
```

**Features:**
- 🔄 Real-time bidirectional sync between Linear and Notion
- 📊 Automatic progress tracking and completion percentages  
- 🛡️ Robust error handling with intelligent retry logic
- 📈 Health monitoring with daily reports and alerts
- 🔧 Production-ready with comprehensive configuration

**Use Cases:**
- Project management teams using both Linear and Notion
- Progress tracking across platforms
- Unified project visibility and reporting
- Cross-team collaboration and communication

See [`linear-notion-sync/README.md`](./linear-notion-sync/README.md) for complete setup documentation.

## Resources

- 📚 [Documentation](https://docs.n8n.io)
- 🔧 [400+ Integrations](https://n8n.io/integrations)
- 💡 [Example Workflows](https://n8n.io/workflows)
- 🤖 [AI & LangChain Guide](https://docs.n8n.io/langchain/)
- 👥 [Community Forum](https://community.n8n.io)
- 📖 [Community Tutorials](https://community.n8n.io/c/tutorials/28)

## Support

Need help? Our community forum is the place to get support and connect with other users:
[community.n8n.io](https://community.n8n.io)

## License

n8n is [fair-code](https://faircode.io) distributed under the [Sustainable Use License](https://github.com/n8n-io/n8n/blob/master/LICENSE.md) and [n8n Enterprise License](https://github.com/n8n-io/n8n/blob/master/LICENSE_EE.md).

- **Source Available**: Always visible source code
- **Self-Hostable**: Deploy anywhere
- **Extensible**: Add your own nodes and functionality

[Enterprise licenses](mailto:license@n8n.io) available for additional features and support.

Additional information about the license model can be found in the [docs](https://docs.n8n.io/reference/license/).

## Contributing

Found a bug 🐛 or have a feature idea ✨? Check our [Contributing Guide](https://github.com/n8n-io/n8n/blob/master/CONTRIBUTING.md) to get started.

## Join the Team

Want to shape the future of automation? Check out our [job posts](https://n8n.io/careers) and join our team!

## What does n8n mean?

**Short answer:** It means "nodemation" and is pronounced as n-eight-n.

**Long answer:** "I get that question quite often (more often than I expected) so I decided it is probably best to answer it here. While looking for a good name for the project with a free domain I realized very quickly that all the good ones I could think of were already taken. So, in the end, I chose nodemation. 'node-' in the sense that it uses a Node-View and that it uses Node.js and '-mation' for 'automation' which is what the project is supposed to help with. However, I did not like how long the name was and I could not imagine writing something that long every time in the CLI. That is when I then ended up on 'n8n'." - **Jan Oberhauser, Founder and CEO, n8n.io**
