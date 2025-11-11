# GCP Step-by-Step Guide - 100 Bots

## Complete Step-by-Step Instructions

### Step 1: Create GCP Account (5 minutes)

1. **Go to:** https://cloud.google.com/
2. **Click:** "Get started for free"
3. **Sign in** with Google account
4. **Fill form:**
   - Country: Your country
   - Account type: Individual
   - Accept terms
5. **Add payment:**
   - Credit card (for verification only)
   - Won't be charged if you stay within free tier
6. **Get $300 credits** (valid 90 days)

---

### Step 2: Create Project (2 minutes)

1. **Go to:** https://console.cloud.google.com/
2. **Click:** Project dropdown (top)
3. **Click:** "New Project"
4. **Name:** `zoom-bots-test`
5. **Click:** "Create"
6. **Select** the new project

---

### Step 3: Enable Compute Engine (2 minutes)

1. **Go to:** "APIs & Services" → "Library"
2. **Search:** "Compute Engine API"
3. **Click:** "Enable"
4. **Wait** for activation (30 seconds)

---

### Step 4: Create VM Instance (5 minutes)

1. **Go to:** Compute Engine → VM instances
2. **Click:** "Create Instance"

3. **Fill details:**

   **Name:** `zoom-bots-server`
   
   **Region:** `us-east1` (or closest to you)
   
   **Zone:** `us-east1-b` (any zone is fine)
   
   **Machine type:**
   - Click "Customize"
   - **vCPU:** 4
   - **Memory:** 15GB
   - Or select: `n1-standard-4` (pre-configured)
   
   **Boot disk:**
   - Click "Change"
   - **OS:** Ubuntu
   - **Version:** Ubuntu 22.04 LTS
   - **Size:** 30GB
   - **Click:** "Select"
   
   **Firewall:**
   - ✅ Allow HTTP traffic (optional)
   - ✅ Allow HTTPS traffic (optional)

4. **Click:** "Create"
5. **Wait** for instance to start (1-2 minutes)

---

### Step 5: Connect to Instance (1 minute)

**Option A: Browser SSH (Easiest)**

1. **In VM instances list**, find your instance
2. **Click:** "SSH" button (right side)
3. **Browser window opens** with terminal

**Option B: gcloud CLI**

```bash
# On your local machine
gcloud compute ssh zoom-bots-server --zone=us-east1-b
```

---

### Step 6: Install Docker (5 minutes)

**Copy and paste these commands in SSH terminal:**

```bash
# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Logout and login
exit
```

**Reconnect and verify:**

```bash
# Reconnect (click SSH button again or run gcloud command)
docker --version
docker-compose --version
```

---

### Step 7: Transfer Code (5 minutes)

**Option A: Git (if repo is accessible)**

```bash
# On GCP instance
cd ~
git clone <your-repo-url> meetingsdk-headless-linux-sample
cd meetingsdk-headless-linux-sample
```

**Option B: gcloud scp (from local machine)**

```bash
# On your local machine
gcloud compute scp --recurse ./meetingsdk-headless-linux-sample zoom-bots-server:~/ --zone=us-east1-b

# Then on GCP instance
cd ~/meetingsdk-headless-linux-sample
```

**Option C: Zip and Upload**

```bash
# On local machine
cd /path/to
zip -r meetingsdk.zip meetingsdk-headless-linux-sample
gcloud compute scp meetingsdk.zip zoom-bots-server:~/ --zone=us-east1-b

# On GCP instance
cd ~
unzip meetingsdk.zip
cd meetingsdk-headless-linux-sample
```

---

### Step 8: Deploy Bots (20-30 minutes)

**On GCP instance, run:**

```bash
# Generate compose file for 100 bots
./generate-bots.sh 100

# Build images (takes 15-20 minutes)
docker compose -f compose-50-bots.yaml build

# Start bots
docker compose -f compose-50-bots.yaml up -d

# Check status
docker compose -f compose-50-bots.yaml ps
```

**Or use automated script:**

```bash
./GCP_QUICK_START.sh 100
```

---

### Step 9: Verify Deployment (2 minutes)

```bash
# Check running bots
docker ps | grep zoom-bot | wc -l

# Should show: 100

# View logs
docker compose -f compose-50-bots.yaml logs -f

# Check resource usage
docker stats --no-stream | head -10
```

---

### Step 10: Monitor in GCP Console

1. **Go to:** Compute Engine → VM instances
2. **Click:** Your instance name
3. **View:**
   - CPU usage graph
   - Memory usage
   - Network traffic

---

## Cost Management

### Set Budget Alert

1. **Go to:** Billing → Budgets & alerts
2. **Click:** "Create Budget"
3. **Set:**
   - Amount: $50 (or your limit)
   - Alert at: 50%, 90%, 100%
4. **Save**

### Stop Instance (Save Money)

**When not testing:**

```bash
# Via console: Click "Stop" button
# Or via CLI:
gcloud compute instances stop zoom-bots-server --zone=us-east1-b
```

**Note:** Stopping saves compute costs, but you still pay for disk (~$3/month).

### Delete Instance (When Done)

```bash
# Via console: Click "Delete" button
# Or via CLI:
gcloud compute instances delete zoom-bots-server --zone=us-east1-b
```

---

## Troubleshooting

### Can't Connect via SSH

1. **Check instance is running:**
   - Go to VM instances list
   - Status should be "Running"

2. **Check firewall:**
   - Go to: VPC network → Firewall
   - Should have rule allowing SSH

3. **Try browser SSH:**
   - Click "SSH" button in console

### Out of Memory

```bash
# Check memory
free -h

# If low, add swap
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### Bots Not Starting

```bash
# Check logs
docker compose -f compose-50-bots.yaml logs

# Check specific bot
docker logs zoom-bot-1

# Restart
docker compose -f compose-50-bots.yaml restart
```

---

## Quick Command Reference

### Instance Management

```bash
# List instances
gcloud compute instances list

# Start instance
gcloud compute instances start zoom-bots-server --zone=us-east1-b

# Stop instance
gcloud compute instances stop zoom-bots-server --zone=us-east1-b

# Get external IP
gcloud compute instances describe zoom-bots-server --zone=us-east1-b --format='get(networkInterfaces[0].accessConfigs[0].natIP)'
```

### Bot Management

```bash
# Start all bots
docker compose -f compose-50-bots.yaml up -d

# Stop all bots
docker compose -f compose-50-bots.yaml down

# View logs
docker compose -f compose-50-bots.yaml logs -f

# Check status
docker compose -f compose-50-bots.yaml ps
```

---

## Expected Timeline

- **Account setup:** 5 minutes
- **Instance creation:** 5 minutes
- **Docker installation:** 5 minutes
- **Code transfer:** 5 minutes
- **Build & deploy:** 20-30 minutes
- **Total:** ~40-50 minutes

---

## Cost Estimate

**For 100 bots (n1-standard-4):**

- **Instance:** $150/month
- **Disk:** $3/month
- **Network:** $5/month
- **Total:** ~$158/month
- **With $300 credits:** Free for ~2 months

---

## Next Steps

1. ✅ Follow steps 1-10 above
2. ✅ Verify bots are running
3. ✅ Check Zoom meeting for bots
4. ✅ Set budget alerts
5. ✅ Monitor costs in billing dashboard

---

## Support

- **GCP Documentation:** https://cloud.google.com/docs
- **GCP Support:** https://cloud.google.com/support
- **Compute Engine Docs:** https://cloud.google.com/compute/docs

