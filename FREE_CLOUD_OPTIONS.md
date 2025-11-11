# Free/Cheap Cloud Options for 100 Bots Testing

## Overview

Testing 100 bots requires significant resources (8-16GB RAM). Most free tiers don't provide enough, but here are the best options:

## Option 1: AWS Free Tier + Credits (Best Option)

### AWS Free Tier
- **t2.micro/t3.micro:** 1GB RAM (not enough for 100 bots)
- **Free for:** 12 months (new accounts)
- **Limitation:** Too small for 100 bots

### AWS Credits (Recommended)
1. **AWS Activate** - For startups (up to $1000 credits)
2. **AWS Educate** - For students (free credits)
3. **AWS Startup Program** - For startups
4. **GitHub Student Pack** - Includes AWS credits

### Strategy: Use Credits for t3.xlarge
- **Instance:** t3.xlarge (16GB RAM, 4 vCPU)
- **Cost:** ~$120/month
- **With credits:** Free for 1-2 months
- **Can handle:** 80-100 bots

## Option 2: Multiple Free Tier Instances (Distributed)

### Split 100 Bots Across Multiple Free Instances

**Oracle Cloud Free Tier** (Best for this)
- **2 instances** with:
  - 1GB RAM each (or upgrade to 2GB)
  - 1 vCPU each
- **Free forever** (not just 12 months)
- **Strategy:** Run 10-15 bots per instance = 20-30 bots total
- **Need:** 4-5 Oracle Cloud accounts for 100 bots

**AWS Free Tier**
- **1 t2.micro** per account
- **Free for:** 12 months
- **Strategy:** Run 5-10 bots per instance
- **Need:** 10-20 AWS accounts for 100 bots

### Distributed Setup Script

```bash
# deploy-distributed.sh
# Run on multiple free tier instances

INSTANCE_NUM=${1:-1}
BOTS_PER_INSTANCE=10
START_BOT=$(( (INSTANCE_NUM - 1) * BOTS_PER_INSTANCE + 1 ))
END_BOT=$(( INSTANCE_NUM * BOTS_PER_INSTANCE ))

echo "Deploying bots $START_BOT to $END_BOT on instance $INSTANCE_NUM"

# Generate only specific bots
for i in $(seq $START_BOT $END_BOT); do
    # Add bot-$i to compose file
done

docker compose -f compose-distributed.yaml up -d
```

## Option 3: Trial Periods (Temporary Free)

### Google Cloud Platform (GCP)
- **Free Trial:** $300 credits for 90 days
- **Instance:** n1-standard-4 (15GB RAM, 4 vCPU)
- **Cost:** ~$150/month
- **With trial:** Free for 2 months
- **Can handle:** 100 bots

### Microsoft Azure
- **Free Trial:** $200 credits for 30 days
- **Instance:** Standard_D4s_v3 (16GB RAM, 4 vCPU)
- **Cost:** ~$150/month
- **With trial:** Free for 1 month
- **Can handle:** 100 bots

### DigitalOcean
- **Free Trial:** $200 credits for 60 days
- **Droplet:** 8GB RAM, 4 vCPU
- **Cost:** $48/month
- **With trial:** Free for 4 months
- **Can handle:** 80-100 bots

## Option 4: Educational Credits

### GitHub Student Pack
- **AWS Credits:** $75-200
- **DigitalOcean Credits:** $200
- **Azure Credits:** $100
- **Total:** Can cover 1-2 months of testing

### AWS Educate
- **Free credits** for students
- **Access to:** t3 instances
- **Duration:** While student

## Option 5: Spot Instances (Very Cheap)

### AWS Spot Instances
- **Savings:** 60-90% off regular price
- **t3.xlarge:** ~$12-30/month (instead of $120)
- **Risk:** Can be interrupted
- **Best for:** Testing (not production)

### Setup Spot Instance

```bash
# Request Spot Instance via AWS Console
# EC2 → Spot Requests → Request Spot Instances
# Instance: t3.xlarge
# Max price: $0.10/hour (on-demand is ~$0.17/hour)
# Interruption: Stop (bots restart when instance resumes)
```

## Option 6: Local Testing (Free but Limited)

### Run Locally with Fewer Bots
- **Test with:** 10-20 bots locally
- **Free:** Yes
- **Limitation:** Can't test 100 bots
- **Use for:** Code testing, not scale testing

## Recommended Strategy

### For Immediate Free Testing:

1. **Use AWS/GCP/Azure Trial Credits**
   - Sign up for new account
   - Get $200-300 free credits
   - Use for 1-2 months of testing
   - Best option for quick testing

2. **Use Spot Instances**
   - 60-90% cheaper
   - t3.xlarge for ~$12-30/month
   - Good for testing

3. **Combine Free Tiers**
   - Use multiple free tier accounts
   - Distribute bots across instances
   - More setup but completely free

## Step-by-Step: AWS Free Trial Setup

### Step 1: Create AWS Account
1. Go to aws.amazon.com
2. Create new account
3. Add credit card (won't be charged if you stay in free tier)
4. Get $200-300 credits (if available)

### Step 2: Launch Spot Instance

```bash
# Via AWS Console:
# EC2 → Spot Requests → Request Spot Instances
# 
# Configuration:
# - AMI: Ubuntu 22.04
# - Instance: t3.xlarge
# - Max price: $0.10/hour
# - Interruption: Stop
```

### Step 3: Deploy

```bash
# Connect
ssh -i key.pem ubuntu@your-ip

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Transfer code and deploy
./deploy.sh 100
```

## Cost Comparison

| Option | Cost | Duration | Bots |
|--------|------|----------|------|
| AWS Free Tier | $0 | 12 months | 5-10 only |
| AWS Spot | $12-30/month | Ongoing | 100 |
| AWS Trial Credits | $0 | 1-2 months | 100 |
| GCP Trial | $0 | 2 months | 100 |
| Azure Trial | $0 | 1 month | 100 |
| DigitalOcean Trial | $0 | 4 months | 100 |
| Oracle Free Tier | $0 | Forever | 20-30 (multiple accounts) |

## Quick Start: Free Trial

### DigitalOcean (Easiest)

1. **Sign up:** digitalocean.com
2. **Get $200 credits** (60 days)
3. **Create Droplet:**
   - 8GB RAM, 4 vCPU
   - Ubuntu 22.04
   - $48/month (free with credits for 4 months)

4. **Deploy:**
```bash
ssh root@your-droplet-ip
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
# Transfer code and deploy
./deploy.sh 100
```

### AWS with Credits

1. **Sign up:** aws.amazon.com
2. **Get credits** (if available)
3. **Launch Spot Instance:**
   - t3.xlarge
   - Spot price: ~$0.10/hour
   - Total: ~$12-30/month

4. **Deploy:**
```bash
# Same as above
```

## Important Notes

### Free Tier Limitations
- Most free tiers are **too small** for 100 bots
- Need **8-16GB RAM** minimum
- Free tiers usually provide **1-2GB RAM**

### Trial Credits
- **Time-limited** (1-4 months)
- **Require credit card** (but won't charge if you stay within limits)
- **Best for:** Short-term testing

### Spot Instances
- **Can be interrupted** (not ideal for production)
- **Very cheap** (60-90% off)
- **Best for:** Testing

## Recommendation

**For 100 bots free testing:**

1. **Best Option:** DigitalOcean Trial ($200 credits = 4 months free)
2. **Second Best:** AWS/GCP/Azure Trial ($200-300 credits = 1-2 months)
3. **Cheapest Ongoing:** AWS Spot Instances ($12-30/month)
4. **Completely Free:** Multiple Oracle Cloud accounts (more setup)

## Next Steps

1. **Choose option** based on your needs
2. **Sign up** for trial/credits
3. **Follow deployment guide** from SERVER_DEPLOYMENT_GUIDE.md
4. **Deploy 100 bots** using deploy.sh
5. **Monitor** to ensure everything works

