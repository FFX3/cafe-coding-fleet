const express = require('express');
const cookieParser = require('cookie-parser');

const app = express();
app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(cookieParser());

const GOTRUE_URL = process.env.GOTRUE_URL || 'https://auth.justinmcintyre.com';

// Common styles
const styles = `
  * { box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: #0a0a0a;
    color: #fafafa;
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
    margin: 0;
    padding: 1rem;
  }
  .container {
    background: #1a1a1a;
    padding: 2rem;
    border-radius: 8px;
    width: 100%;
    max-width: 400px;
    border: 1px solid #333;
  }
  h1 { margin: 0 0 1.5rem; font-size: 1.5rem; text-align: center; }
  .error { background: #7f1d1d; color: #fecaca; padding: 0.75rem; border-radius: 4px; margin-bottom: 1rem; }
  label { display: block; margin-bottom: 0.5rem; color: #a1a1aa; font-size: 0.875rem; }
  input {
    width: 100%;
    padding: 0.75rem;
    margin-bottom: 1rem;
    border: 1px solid #333;
    border-radius: 4px;
    background: #0a0a0a;
    color: #fafafa;
    font-size: 1rem;
  }
  input:focus { outline: none; border-color: #3b82f6; }
  button, .btn {
    display: inline-block;
    padding: 0.75rem 1.5rem;
    background: #3b82f6;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-size: 1rem;
    font-weight: 500;
    text-decoration: none;
    text-align: center;
  }
  button:hover, .btn:hover { background: #2563eb; }
  .btn-full { width: 100%; }
  .btn-secondary { background: #333; }
  .btn-secondary:hover { background: #444; }
`;

// Login page HTML
const loginPage = (redirectTo = '/', error = '') => `
<!DOCTYPE html>
<html>
<head>
  <title>Sign In - Studio</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>${styles}</style>
</head>
<body>
  <div class="container">
    <h1>Sign In</h1>
    ${error ? `<div class="error">${error}</div>` : ''}
    <form method="POST" action="/login">
      <input type="hidden" name="redirect_to" value="${redirectTo}">
      <label for="email">Email</label>
      <input type="email" id="email" name="email" required autofocus>
      <label for="password">Password</label>
      <input type="password" id="password" name="password" required>
      <button type="submit" class="btn-full">Sign In</button>
    </form>
  </div>
</body>
</html>
`;

// Dashboard page HTML
const dashboardPage = (user) => `
<!DOCTYPE html>
<html>
<head>
  <title>Studio</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    ${styles}
    .container { max-width: 600px; text-align: center; }
    .subtitle { color: #a1a1aa; margin-bottom: 2rem; }
    .user-info { background: #0a0a0a; padding: 1rem; border-radius: 4px; margin-bottom: 1.5rem; text-align: left; }
    .user-info p { margin: 0.5rem 0; color: #d4d4d8; }
    .actions { display: flex; gap: 1rem; justify-content: center; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Welcome to the Studio</h1>
    <p class="subtitle">Your personal dashboard</p>
    <div class="user-info">
      <p><strong>Email:</strong> ${user.email || 'Unknown'}</p>
    </div>
    <div class="actions">
      <a href="/logout" class="btn btn-secondary">Sign Out</a>
    </div>
  </div>
</body>
</html>
`;

// Verify token and get user info
async function verifyToken(accessToken) {
  try {
    const res = await fetch(`${GOTRUE_URL}/user`, {
      headers: { 'Authorization': `Bearer ${accessToken}` }
    });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

// Auth middleware
async function requireAuth(req, res, next) {
  const accessToken = req.cookies.access_token;
  if (!accessToken) {
    return res.redirect(`/login?redirect_to=${encodeURIComponent(req.originalUrl)}`);
  }

  const user = await verifyToken(accessToken);
  if (!user) {
    res.clearCookie('access_token');
    return res.redirect(`/login?redirect_to=${encodeURIComponent(req.originalUrl)}`);
  }

  req.user = user;
  next();
}

// GET / - Dashboard (requires auth)
app.get('/', requireAuth, (req, res) => {
  res.send(dashboardPage(req.user));
});

// GET /login - Show login page
app.get('/login', (req, res) => {
  const redirectTo = req.query.redirect_to || '/';
  res.send(loginPage(redirectTo));
});

// POST /login - Handle login
app.post('/login', async (req, res) => {
  const { email, password, redirect_to = '/' } = req.body;

  if (!email || !password) {
    return res.send(loginPage(redirect_to, 'Email and password required'));
  }

  try {
    const loginRes = await fetch(`${GOTRUE_URL}/token?grant_type=password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    });

    if (!loginRes.ok) {
      const errData = await loginRes.json().catch(() => ({}));
      return res.send(loginPage(redirect_to, errData.error_description || errData.msg || 'Invalid credentials'));
    }

    const data = await loginRes.json();

    res.cookie('access_token', data.access_token, {
      httpOnly: true,
      secure: true,
      sameSite: 'lax',
      maxAge: 3600000
    });

    return res.redirect(redirect_to);
  } catch (err) {
    console.error('Login error:', err);
    return res.send(loginPage(redirect_to, 'Login failed'));
  }
});

// GET /logout
app.get('/logout', (req, res) => {
  res.clearCookie('access_token');
  res.redirect('/login');
});

// GET /oauth/consent - OAuth consent flow
app.get('/oauth/consent', async (req, res) => {
  const authorizationId = req.query.authorization_id;
  if (!authorizationId) {
    return res.status(400).send('Missing authorization_id');
  }

  const accessToken = req.cookies.access_token;

  if (!accessToken) {
    // Show login form for OAuth flow
    return res.send(loginPage(`/oauth/consent?authorization_id=${authorizationId}`));
  }

  // User is logged in, get authorization details (this claims and may auto-approve)
  try {
    const detailsRes = await fetch(`${GOTRUE_URL}/oauth/authorizations/${authorizationId}`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`
      }
    });

    const details = await detailsRes.json().catch(() => ({}));
    console.log('Authorization details:', detailsRes.status, details);

    if (!detailsRes.ok) {
      if (detailsRes.status === 401) {
        res.clearCookie('access_token');
        return res.send(loginPage(`/oauth/consent?authorization_id=${authorizationId}`, 'Session expired, please sign in again'));
      }
      return res.status(500).send(`Authorization failed: ${details.msg || 'Unknown error'}`);
    }

    // Check if we got a redirect (auto-approved)
    if (details.redirect_url) {
      return res.redirect(details.redirect_url);
    }

    // If not auto-approved, explicitly approve
    const approveRes = await fetch(`${GOTRUE_URL}/oauth/authorizations/${authorizationId}/consent`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ action: 'approve' })
    });

    const result = await approveRes.json().catch(() => ({}));
    console.log('Approve response:', approveRes.status, result);

    if (result.redirect_url) {
      return res.redirect(result.redirect_url);
    }

    if (!approveRes.ok) {
      return res.status(500).send(`Authorization failed: ${result.msg || 'Unknown error'}`);
    }

    return res.status(500).send('No redirect received from authorization');
  } catch (err) {
    console.error('Consent error:', err);
    return res.status(500).send(`Error: ${err.message}`);
  }
});

// Health check (no auth required)
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Studio server running on port ${PORT}`);
});
