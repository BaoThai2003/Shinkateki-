// js/auth.js — login / register forms
'use strict';

document.addEventListener('DOMContentLoaded', () => {

  // ── Form toggling ──────────────────────────────────────────────
  document.getElementById('show-register')?.addEventListener('click', e => {
    e.preventDefault();
    toggle('login-form',    true);
    toggle('register-form', false);
  });

  document.getElementById('show-login')?.addEventListener('click', e => {
    e.preventDefault();
    toggle('register-form', true);
    toggle('login-form',    false);
  });

  // ── Login ──────────────────────────────────────────────────────
  document.getElementById('btn-login')?.addEventListener('click', async () => {
    const username = v('login-username');
    const password = v('login-password');
    const errEl    = document.getElementById('login-error');

    clearError(errEl);
    if (!username || !password) return showError(errEl, 'Please fill in all fields.');

    try {
      const { token, user } = await api.post('/auth/login', { username, password });
      App.setAuth(token, user);
      enterApp();
    } catch (err) {
      showError(errEl, err.data?.error || 'Login failed.');
    }
  });

  // Enter key on login
  ['login-username', 'login-password'].forEach(id => {
    document.getElementById(id)?.addEventListener('keydown', e => {
      if (e.key === 'Enter') document.getElementById('btn-login')?.click();
    });
  });

  // ── Register ───────────────────────────────────────────────────
  document.getElementById('btn-register')?.addEventListener('click', async () => {
    const username = v('reg-username');
    const email    = v('reg-email');
    const password = v('reg-password');
    const errEl    = document.getElementById('reg-error');

    clearError(errEl);
    if (!username || !email || !password)
      return showError(errEl, 'Please fill in all fields.');
    if (password.length < 6)
      return showError(errEl, 'Password must be at least 6 characters.');

    try {
      const { token, user } = await api.post('/auth/register', { username, email, password });
      App.setAuth(token, user);
      enterApp();
    } catch (err) {
      showError(errEl, err.data?.error || err.data?.errors?.[0]?.msg || 'Registration failed.');
    }
  });

  // Helpers
  function v(id)      { return document.getElementById(id)?.value.trim() || ''; }
  function toggle(id, hide) {
    document.getElementById(id)?.classList.toggle('hidden', hide);
  }
  function showError(el, msg) {
    if (!el) return;
    el.textContent = msg;
    el.classList.remove('hidden');
  }
  function clearError(el) {
    if (!el) return;
    el.textContent = '';
    el.classList.add('hidden');
  }
});
