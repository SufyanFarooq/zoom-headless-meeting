# Fix GCP Firewall Rule - Authentication Issue

## Problem
`Request had insufficient authentication scopes` error aa raha hai.

## Solution Options

### Option 1: GCP Console se Manually (Easiest) ⭐

**Step-by-step:**

1. **GCP Console open karein:**
   - Go to: https://console.cloud.google.com

2. **Navigate to Firewall:**
   - Left menu → **VPC network** → **Firewall**
   - Ya direct: https://console.cloud.google.com/networking/firewalls

3. **Create Firewall Rule:**
   - Click **"Create Firewall Rule"** button (top)

4. **Fill Details:**
   - **Name**: `allow-bot-server`
   - **Description**: `Allow bot server API on port 3001`
   - **Network**: `default` (ya apna network)
   - **Priority**: `1000` (default)
   - **Direction of traffic**: `Ingress`
   - **Action on match**: `Allow`
   - **Targets**: `All instances in the network`
   - **Source IP ranges**: `0.0.0.0/0` (ya specific Server 1 IP)
   - **Protocols and ports**: 
     - Check **"tcp"**
     - Enter port: `3001`
   - Click **"Create"**

5. **Verify:**
   - Firewall rules list me `allow-bot-server` dikhna chahiye
   - Status: **Enabled**

### Option 2: Fix gcloud Authentication

**Step 1: Login karein**
```bash
gcloud auth login
```

**Step 2: Project set karein**
```bash
# List projects
gcloud projects list

# Set project
gcloud config set project YOUR_PROJECT_ID
```

**Step 3: Application Default Credentials**
```bash
gcloud auth application-default login
```

**Step 4: Retry firewall rule**
```bash
gcloud compute firewall-rules create allow-bot-server \
  --allow tcp:3001 \
  --source-ranges 0.0.0.0/0 \
  --description "Allow bot server API"
```

### Option 3: Using Service Account (Advanced)

Agar service account use kar rahe hain:

```bash
# Service account key file se authenticate
gcloud auth activate-service-account --key-file=path/to/key.json

# Project set
gcloud config set project YOUR_PROJECT_ID

# Create firewall rule
gcloud compute firewall-rules create allow-bot-server \
  --allow tcp:3001 \
  --source-ranges 0.0.0.0/0 \
  --description "Allow bot server API"
```

### Option 4: Check Current Authentication

```bash
# Check current user
gcloud auth list

# Check current project
gcloud config get-value project

# Check permissions
gcloud projects get-iam-policy $(gcloud config get-value project)
```

## Quick Fix Commands

```bash
# 1. Login
gcloud auth login

# 2. Set project
gcloud config set project YOUR_PROJECT_ID

# 3. Application default credentials
gcloud auth application-default login

# 4. Create firewall rule
gcloud compute firewall-rules create allow-bot-server \
  --allow tcp:3001 \
  --source-ranges 0.0.0.0/0 \
  --description "Allow bot server API"
```

## Verify Firewall Rule

```bash
# List firewall rules
gcloud compute firewall-rules list --filter="name~bot-server"

# Check specific rule
gcloud compute firewall-rules describe allow-bot-server
```

## Test Connectivity

**Server 1 se Server 2 test karein:**

```bash
# Server 1 par
curl http://35.227.36.166:3001/health

# Expected: {"status":"ok","timestamp":"..."}
```

## Alternative: Use Specific IP Range (More Secure)

Agar Server 1 ka IP pata hai, to specific IP range use karein:

```bash
# GCP Console se:
# Source IP ranges: SERVER1_IP/32

# Ya gcloud se:
gcloud compute firewall-rules create allow-bot-server \
  --allow tcp:3001 \
  --source-ranges SERVER1_IP/32 \
  --description "Allow bot server API from Server 1"
```

## Troubleshooting

### Still Getting Authentication Error?

1. **Check if you have permissions:**
   - Go to GCP Console → IAM & Admin → IAM
   - Check your user has `Compute Security Admin` or `Owner` role

2. **Try browser-based authentication:**
   ```bash
   gcloud auth login --no-launch-browser
   # Copy URL and open in browser
   ```

3. **Use GCP Console instead:**
   - Console se manually create karein (Option 1)

### Firewall Rule Created But Not Working?

1. **Check rule is enabled:**
   ```bash
   gcloud compute firewall-rules describe allow-bot-server
   ```

2. **Check VM has correct network tags:**
   - VM instance → Edit → Network tags
   - Firewall rule me target tags match karein

3. **Check source IP:**
   - Server 1 ka IP firewall rule me allowed hai?

## Summary

**Easiest Method:**
1. ✅ GCP Console → VPC Network → Firewall
2. ✅ Create Firewall Rule
3. ✅ Port: `tcp:3001`
4. ✅ Source: `0.0.0.0/0` (ya Server 1 IP)
5. ✅ Create

**After Firewall Rule Created:**
- Test: `curl http://35.227.36.166:3001/health`
- Should work from Server 1

