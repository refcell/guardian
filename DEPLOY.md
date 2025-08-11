# Deploying to Vercel with Custom Domain

## Prerequisites
- Vercel account (free at vercel.com)
- Access to your domain's DNS settings (refcell.org)

## Step 1: Deploy to Vercel

### Option A: Using Vercel CLI
```bash
# Install Vercel CLI if you haven't
npm i -g vercel

# Deploy from the guardian directory
cd guardian
vercel

# Follow the prompts:
# - Login/signup if needed
# - Choose the scope
# - Link to existing project? No
# - Project name: guardian
# - Directory: ./
# - Override settings? No
```

### Option B: Using GitHub Integration
1. Push this repository to GitHub
2. Go to [vercel.com](https://vercel.com)
3. Click "Import Project"
4. Import from GitHub repository
5. Select the `guardian` repository
6. Keep default settings and deploy

## Step 2: Add Custom Domain

1. In Vercel dashboard, go to your project
2. Go to Settings → Domains
3. Add `guardian.refcell.org`
4. Vercel will provide DNS records to add

## Step 3: Configure DNS

Add these records to your DNS provider for refcell.org:

### If using CNAME (recommended):
```
Type: CNAME
Name: guardian
Value: cname.vercel-dns.com
```

### If using A records:
```
Type: A
Name: guardian
Value: 76.76.21.21
```

## Step 4: Verify

Once DNS propagates (usually within minutes):

```bash
# Test the install redirect
curl -I https://guardian.refcell.org/install

# Should return 308 redirect to GitHub

# Test the actual install
curl -sSL guardian.refcell.org/install | bash
```

## How It Works

The `vercel.json` configuration sets up redirects:
- `/install` and `/install.sh` → GitHub raw install script
- `/test` and `/test.sh` → GitHub raw test script  
- `/` → GitHub repository page

This allows users to use the short, memorable command:
```bash
curl -sSL guardian.refcell.org/install | bash
```

Instead of the longer GitHub URL!