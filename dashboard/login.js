// API Base URL
const API_BASE_URL = window.location.hostname === 'localhost' && window.location.port === '8080' 
    ? 'http://localhost:3000/api' 
    : '/api';

// Check if already logged in
window.addEventListener('DOMContentLoaded', () => {
    const token = localStorage.getItem('authToken');
    if (token) {
        // Verify token is still valid
        verifyToken(token);
    }
});

// Handle login form submission
document.getElementById('loginForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const username = document.getElementById('username').value.trim();
    const password = document.getElementById('password').value;
    const loginButton = document.getElementById('loginButton');
    const errorMessage = document.getElementById('errorMessage');
    
    // Hide error message
    errorMessage.classList.remove('show');
    errorMessage.textContent = '';
    
    // Disable button and show loading
    loginButton.disabled = true;
    loginButton.textContent = 'Logging in...';
    
    try {
        const response = await fetch(`${API_BASE_URL}/auth/login`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ username, password })
        });
        
        const result = await response.json();
        
        if (response.ok && result.success) {
            // Store token
            localStorage.setItem('authToken', result.token);
            localStorage.setItem('user', JSON.stringify(result.user));
            
            // Redirect to dashboard
            window.location.href = 'index.html';
        } else {
            // Show error
            errorMessage.textContent = result.message || result.error || 'Login failed';
            errorMessage.classList.add('show');
            loginButton.disabled = false;
            loginButton.textContent = 'LOGIN';
        }
    } catch (error) {
        console.error('Login error:', error);
        errorMessage.textContent = 'Network error. Please try again.';
        errorMessage.classList.add('show');
        loginButton.disabled = false;
        loginButton.textContent = 'LOGIN';
    }
});

// Verify token and redirect if valid
async function verifyToken(token) {
    try {
        const response = await fetch(`${API_BASE_URL}/auth/me`, {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });
        
        if (response.ok) {
            // Token is valid, redirect to dashboard
            window.location.href = 'index.html';
        } else {
            // Token invalid, clear it
            localStorage.removeItem('authToken');
            localStorage.removeItem('user');
        }
    } catch (error) {
        console.error('Token verification error:', error);
        localStorage.removeItem('authToken');
        localStorage.removeItem('user');
    }
}

