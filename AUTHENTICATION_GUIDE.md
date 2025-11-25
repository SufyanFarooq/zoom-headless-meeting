# Authentication Guide

## Overview
The application now includes JWT-based authentication. Users must login to access the dashboard.

## Features
- **Register API** - Create new users (Postman only)
- **Login API** - Authenticate users and get JWT token
- **Reset Password API** - Reset user password (Postman only)
- **Forgot Password API** - Generate reset token (Postman only)
- **JWT Session** - 1 hour expiry

## Database Setup

Run the updated schema to create the users table:

```bash
psql -U your_user -d your_database -f database/schema.sql
```

Or if using Docker:
```bash
docker exec -i zoom-dashboard-db psql -U postgres -d zoom_dashboard < database/schema.sql
```

## API Endpoints

### 1. Register User (Postman Only)
**POST** `/api/auth/register`

**Request Body:**
```json
{
  "username": "admin",
  "email": "admin@example.com",
  "password": "password123"
}
```

**Response:**
```json
{
  "success": true,
  "message": "User registered successfully",
  "user": {
    "id": 1,
    "username": "admin",
    "email": "admin@example.com",
    "created_at": "2025-11-25T..."
  }
}
```

### 2. Login
**POST** `/api/auth/login`

**Request Body:**
```json
{
  "username": "admin",
  "password": "password123"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Login successful",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "username": "admin",
    "email": "admin@example.com"
  }
}
```

### 3. Forgot Password (Postman Only)
**POST** `/api/auth/forgot-password`

**Request Body:**
```json
{
  "username": "admin"
}
```
or
```json
{
  "email": "admin@example.com"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Reset token generated",
  "resetToken": "abc123...",
  "expiresAt": "2025-11-25T..."
}
```

### 4. Reset Password (Postman Only)
**POST** `/api/auth/reset-password`

**Option 1: Using reset token**
```json
{
  "resetToken": "abc123...",
  "newPassword": "newpassword123"
}
```

**Option 2: Using username/email (admin use)**
```json
{
  "username": "admin",
  "newPassword": "newpassword123"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Password reset successfully"
}
```

### 5. Get Current User
**GET** `/api/auth/me`

**Headers:**
```
Authorization: Bearer <token>
```

**Response:**
```json
{
  "success": true,
  "user": {
    "id": 1,
    "username": "admin",
    "email": "admin@example.com"
  }
}
```

## Protected Routes

All dashboard API routes now require authentication:
- `/api/meetings` - Requires JWT token
- `/api/schedules` - Requires JWT token
- `/api/usage` - Requires JWT token
- `/api/names` - Requires JWT token
- `/api/bot-servers` - Requires JWT token

**Request Headers:**
```
Authorization: Bearer <token>
```

## Frontend Usage

### Login Page
Access the login page at: `http://your-domain/login.html`

### Dashboard
After successful login, users are redirected to `index.html`. The JWT token is stored in `localStorage` and automatically included in all API requests.

### Logout
Click the "Logout" button in the header to logout and clear the session.

## Environment Variables

Add to your `.env` file:

```env
JWT_SECRET=your-secret-key-change-in-production
```

**Important:** Use a strong, random secret key in production!

## Postman Examples

### Register User
```
POST http://your-domain/api/auth/register
Content-Type: application/json

{
  "username": "admin",
  "email": "admin@example.com",
  "password": "password123"
}
```

### Login
```
POST http://your-domain/api/auth/login
Content-Type: application/json

{
  "username": "admin",
  "password": "password123"
}
```

### Access Protected Route
```
GET http://your-domain/api/meetings?status=active
Authorization: Bearer <token-from-login>
```

### Reset Password
```
POST http://your-domain/api/auth/reset-password
Content-Type: application/json

{
  "username": "admin",
  "newPassword": "newpassword123"
}
```

## Security Notes

1. **JWT Secret:** Always use a strong, random secret key in production
2. **Password Strength:** Minimum 6 characters (can be increased)
3. **Token Expiry:** 1 hour (configurable in `api/routes/auth.js`)
4. **HTTPS:** Use HTTPS in production to protect tokens
5. **Token Storage:** Tokens are stored in `localStorage` (consider httpOnly cookies for production)

## Troubleshooting

### "Unauthorized" Error
- Check if token is included in `Authorization` header
- Verify token hasn't expired (1 hour)
- Ensure token format: `Bearer <token>`

### Login Redirect Loop
- Clear browser `localStorage`
- Check API `/auth/me` endpoint is accessible
- Verify JWT_SECRET is set correctly

### Database Errors
- Ensure users table exists (run schema.sql)
- Check database connection
- Verify PostgreSQL is running

