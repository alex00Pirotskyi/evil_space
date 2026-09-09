{{flutter_js}}
{{flutter_build_config}}

const bootElement = document.getElementById('evil-space-boot');
const bootCopy = document.getElementById('evil-space-boot-copy');
const bootstrapStatusKey = 'evil_space_bootstrap_status_v1';
const bootstrapStatusConsumedKey = 'evil_space_bootstrap_status_consumed_v1';

performance.mark('evil-bootstrap-start');

try {
  sessionStorage.removeItem(bootstrapStatusKey);
  sessionStorage.removeItem(bootstrapStatusConsumedKey);

  fetch('/api/public/status', {
    method: 'GET',
    headers: { Accept: 'application/json' },
    cache: 'no-store',
    credentials: 'same-origin',
  })
    .then((response) => (response.ok ? response.text() : ''))
    .then((payload) => {
      if (
        payload &&
        sessionStorage.getItem(bootstrapStatusConsumedKey) !== '1'
      ) {
        sessionStorage.setItem(bootstrapStatusKey, payload);
      }
      performance.mark('evil-status-prefetch-ready');
    })
    .catch(() => {});
} catch (_) {}

_flutter.loader.load({
  onEntrypointLoaded: async (engineInitializer) => {
    try {
      performance.mark('evil-entrypoint-ready');
      const appRunner = await engineInitializer.initializeEngine();
      performance.mark('evil-engine-ready');
      await appRunner.runApp();
      performance.mark('evil-app-running');

      if (bootElement) {
        requestAnimationFrame(() => {
          requestAnimationFrame(() => bootElement.remove());
        });
      }
    } catch (error) {
      console.error('Evil Space Flutter startup failed.', error);
      if (bootCopy) bootCopy.textContent = 'RELOAD TO TRY AGAIN';
    }
  },
});
