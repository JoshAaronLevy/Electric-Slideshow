import CDP from 'chrome-remote-interface';
import http from 'node:http';

const TOKEN = process.env.SPOTIFY_ACCESS_TOKEN;
const DEVTOOLS_HOST = process.env.CEF_DEVTOOLS_HOST || 'localhost';
const DEVTOOLS_PORT = Number(process.env.CEF_DEVTOOLS_PORT || 9223);
const TARGET_URL_MATCH = process.env.CEF_TARGET_URL_MATCH || 'internal-player';

if (!TOKEN) {
  console.error('[inject_token] Missing SPOTIFY_ACCESS_TOKEN environment variable');
  process.exit(1);
}

async function waitForTarget(timeoutMs = 10000, intervalMs = 500) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    try {
      const targets = await CDP.List({ host: DEVTOOLS_HOST, port: DEVTOOLS_PORT });
      const matching = targets.find((t) => t.url?.includes(TARGET_URL_MATCH));
      if (matching) return matching;
    } catch (err) {
      // DevTools may not be ready yet; ignore and retry
    }
    await new Promise((resolve) => setTimeout(resolve, intervalMs));
  }
  throw new Error(`Timed out waiting for DevTools target containing "${TARGET_URL_MATCH}"`);
}

function escapeToken(value) {
  return value
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "\\'")
    .replace(/\n/g, '\\n')
    .replace(/\r/g, '\\r');
}

(async () => {
  console.log(`[inject_token] Waiting for DevTools target on ${DEVTOOLS_HOST}:${DEVTOOLS_PORT}`);
  const target = await waitForTarget();
  console.log(`[inject_token] Found target: ${target.title || target.url}`);

  const client = await CDP({ host: DEVTOOLS_HOST, port: DEVTOOLS_PORT, target });
  const { Runtime } = client;

  const escapedToken = escapeToken(TOKEN);
  const expression = `(() => {
    if (window.INTERNAL_PLAYER && typeof window.INTERNAL_PLAYER.setAccessToken === 'function') {
      window.INTERNAL_PLAYER.setAccessToken('${escapedToken}');
      return 'token_sent';
    }
    return 'internal_player_not_ready';
  })();`;

  try {
    const result = await Runtime.evaluate({ expression, returnByValue: true });
    console.log('[inject_token] Result:', result.result?.value ?? result.result?.description);
  } finally {
    await client.close();
  }
})();
