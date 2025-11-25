# Authentication Setup Guide

## Dependencies Installation

**Dependencies container mein automatically install hote hain!**

Dockerfile.api mein already `npm install` hai, isliye manually install karne ki zaroorat nahi:

```dockerfile
# Dockerfile.api line 9
RUN npm install --only=production
```

**Container rebuild karein:**
```bash
docker-compose -f docker-compose.full.yml build api
docker-compose -f docker-compose.full.yml up -d
```

## Database Setup

### Option 1: Automatic (First Time)
Schema automatically run hota hai jab container pehli baar start hota hai (volume mount se).

### Option 2: Manual (If needed)

**Exact command with database name:**

```bash
# Container ke andar schema run karein
docker exec -i zoom-dashboard-db psql -U postgres -d zoom_bots -f /docker-entrypoint-initdb.d/schema.sql
```

**Ya phir interactive mode:**

```bash
# Container mein psql open karein
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots

# Phir SQL run karein:
\i /docker-entrypoint-initdb.d/schema.sql
```

**Database details (docker-compose.full.yml se):**
- **Database Name:** `zoom_bots` (default, ya `.env` mein `DB_NAME`)
- **User:** `postgres` (default, ya `.env` mein `DB_USER`)
- **Password:** `postgres` (default, ya `.env` mein `DB_PASSWORD`)
- **Container:** `zoom-dashboard-db`

### Option 3: Direct SQL (If container already running)

```bash
# Users table manually add karein
docker exec -i zoom-dashboard-db psql -U postgres -d zoom_bots << EOF
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  email VARCHAR(100) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  reset_token VARCHAR(255),
  reset_token_expiry TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
EOF
```

## Environment Variables

`.env` file mein add karein:

```env
# Database
DB_NAME=zoom_bots
DB_USER=postgres
DB_PASSWORD=postgres

# JWT Secret (IMPORTANT: Change in production!)
JWT_SECRET=your-strong-random-secret-key-change-this-in-production
```

## Quick Setup Steps

1. **Rebuild API container (dependencies install honge):**
   ```bash
   docker-compose -f docker-compose.full.yml build api
   ```

2. **Start containers:**
   ```bash
   docker-compose -f docker-compose.full.yml up -d
   ```

3. **Check if users table exists:**
   ```bash
   docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c "\d users"
   ```

4. **If table nahi hai, manually create:**
   ```bash
   docker exec -i zoom-dashboard-db psql -U postgres -d zoom_bots -f /docker-entrypoint-initdb.d/schema.sql
   ```

5. **Create first user (Postman):**
   ```bash
   POST http://your-domain/api/auth/register
   {
     "username": "admin",
     "email": "admin@example.com",
     "password": "password123"
   }
   ```

6. **Login:**
   - Open: `http://your-domain/login.html`
   - Username: `admin`
   - Password: `password123`

## Notes

- **Dependencies:** Container build time par automatically install hote hain
- **Schema:** First container start par automatically run hota hai
- **Manual run:** Agar table nahi bana to Option 2 ya 3 use karein

