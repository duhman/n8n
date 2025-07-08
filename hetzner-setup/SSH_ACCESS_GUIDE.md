# SSH Access Guide - Fixing "Connection Refused"

## Problem
The security hardening script has disabled root login and password authentication for SSH, which is blocking your access.

## Solution Options

### Option 1: Use Hetzner Console (Recommended for Recovery)

1. **Log into Hetzner Cloud Console**
   - Go to https://console.hetzner.cloud/
   - Select your server
   - Click on "Console" button

2. **Run the fix script**
   ```bash
   cd /opt/setup/hetzner-setup
   ./fix-ssh-access.sh
   ```

3. **Choose option 1** to temporarily enable root login, or better yet, **choose option 2** to create a new sudo user

### Option 2: Best Practice - Create a Sudo User

If you can access the server through Hetzner console:

```bash
# Create a new user
adduser yourusername

# Add to sudo group
usermod -aG sudo yourusername

# Set up SSH key for the new user
su - yourusername
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Add your public key
echo "your-public-ssh-key" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Then SSH as:
```bash
ssh yourusername@157.180.112.66
```

### Option 3: Temporary Fix - Enable Root Login

If you need quick access through Hetzner console:

```bash
# Edit the SSH hardening config
nano /etc/ssh/sshd_config.d/99-n8n-hardening.conf

# Change or comment out:
# PermitRootLogin no
# to:
PermitRootLogin yes

# Restart SSH
systemctl restart ssh
```

### Option 4: Use Existing User

If you created a user during initial setup, you might already have a non-root user. Try:
```bash
ssh ubuntu@157.180.112.66
# or
ssh admin@157.180.112.66
```

## Security Best Practices

1. **Never leave root login enabled** - It's a security risk
2. **Use SSH keys** instead of passwords
3. **Create a sudo user** for administrative tasks
4. **Keep the hardening in place** after setting up proper access

## Prevent Future Lockouts

Before running security scripts:
1. Create a sudo user first
2. Test SSH access with the new user
3. Only then disable root login

## Emergency Access

If completely locked out:
1. Use Hetzner's web console
2. Boot into recovery mode if needed
3. Mount the system and edit SSH config directly

## Modified Deployment Process

For future deployments, run scripts in this order:
```bash
./initial-setup.sh
./deploy-n8n.sh

# Create user BEFORE security hardening
adduser myuser
usermod -aG sudo myuser
# Set up SSH keys for myuser

# Then run security hardening
./secure-server.sh
```