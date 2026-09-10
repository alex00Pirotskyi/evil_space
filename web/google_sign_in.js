(() => {
  let initializedClientId = '';
  let active = null;
  let overlay = null;

  function googleApi() {
    return window.google?.accounts?.id ?? null;
  }

  function waitForGoogle() {
    const started = Date.now();
    return new Promise((resolve, reject) => {
      const check = () => {
        const api = googleApi();
        if (api) {
          resolve(api);
          return;
        }
        if (Date.now() - started >= 10000) {
          reject(new Error('Google Identity Services did not load.'));
          return;
        }
        window.setTimeout(check, 80);
      };
      check();
    });
  }

  function removeOverlay() {
    if (overlay) overlay.remove();
    overlay = null;
  }

  function finish(value, error) {
    if (!active) return;
    const current = active;
    active = null;
    removeOverlay();
    document.removeEventListener('keydown', onKeyDown, true);
    if (error) current.reject(error);
    else current.resolve(value || '');
  }

  function onKeyDown(event) {
    if (event.key === 'Escape') finish('');
  }

  function handleCredential(response) {
    const credential = typeof response?.credential === 'string'
      ? response.credential
      : '';
    if (!credential) {
      finish('', new Error('Google did not return a credential.'));
      return;
    }
    finish(credential);
  }

  function initialize(api, clientId) {
    if (initializedClientId === clientId) return;
    api.initialize({
      client_id: clientId,
      callback: handleCredential,
      auto_select: false,
      cancel_on_tap_outside: true,
      ux_mode: 'popup',
      use_fedcm_for_prompt: true,
      use_fedcm_for_button: true,
    });
    initializedClientId = clientId;
  }

  function createOverlay(api) {
    removeOverlay();

    const root = document.createElement('div');
    root.id = 'evil-google-signin-overlay';
    Object.assign(root.style, {
      position: 'fixed',
      inset: '0',
      zIndex: '2147483646',
      display: 'grid',
      placeItems: 'center',
      padding: '24px',
      boxSizing: 'border-box',
      background: 'rgba(28, 28, 26, 0.22)',
    });

    const panel = document.createElement('div');
    Object.assign(panel.style, {
      width: 'min(390px, 100%)',
      boxSizing: 'border-box',
      padding: '24px',
      background: '#F2F0E8',
      border: '1px solid #1C1C1A',
      boxShadow: '0 14px 40px rgba(28, 28, 26, 0.16)',
    });

    const title = document.createElement('div');
    title.textContent = 'EVIL SPACE MEMBER ACCESS';
    Object.assign(title.style, {
      color: '#1C1C1A',
      font: '700 11px/1.3 "Courier New", monospace',
      letterSpacing: '0.8px',
    });

    const copy = document.createElement('div');
    copy.textContent = 'Continue with your Google account';
    Object.assign(copy.style, {
      marginTop: '9px',
      color: '#6F6D66',
      font: '400 17px/1.35 Georgia, "Times New Roman", serif',
    });

    const buttonSlot = document.createElement('div');
    Object.assign(buttonSlot.style, {
      marginTop: '20px',
      minHeight: '44px',
      display: 'flex',
      justifyContent: 'center',
    });

    const cancel = document.createElement('button');
    cancel.type = 'button';
    cancel.textContent = 'CANCEL';
    Object.assign(cancel.style, {
      width: '100%',
      height: '42px',
      marginTop: '12px',
      background: 'transparent',
      color: '#1C1C1A',
      border: '1px solid #1C1C1A',
      borderRadius: '0',
      font: '700 10px/1 "Courier New", monospace',
      letterSpacing: '0.6px',
      cursor: 'pointer',
    });
    cancel.addEventListener('click', () => finish(''));

    panel.append(title, copy, buttonSlot, cancel);
    root.append(panel);
    root.addEventListener('click', (event) => {
      if (event.target === root) finish('');
    });
    document.body.append(root);
    overlay = root;
    document.addEventListener('keydown', onKeyDown, true);

    const width = Math.max(220, Math.min(320, window.innerWidth - 96));
    api.renderButton(buttonSlot, {
      type: 'standard',
      theme: 'outline',
      size: 'large',
      text: 'continue_with',
      shape: 'rectangular',
      logo_alignment: 'left',
      width,
    });
  }

  window.evilGoogleSignIn = async (clientId) => {
    if (active) throw new Error('Google Sign-In is already open.');
    const normalized = String(clientId || '').trim();
    if (!normalized) throw new Error('Google client ID is missing.');

    const api = await waitForGoogle();
    initialize(api, normalized);
    return new Promise((resolve, reject) => {
      active = { resolve, reject };
      try {
        createOverlay(api);
      } catch (error) {
        finish('', error instanceof Error ? error : new Error(String(error)));
      }
    });
  };

  window.evilGoogleDisableAutoSelect = () => {
    try {
      googleApi()?.disableAutoSelect();
    } catch (_) {}
  };
})();
