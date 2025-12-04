# Spotify Web Playback SDK Compliance Matrix

| Area | Requirement (per Spotify terms) | Current Status | Action Items |
| --- | --- | --- | --- |
| Subscription | End users must have an active Spotify Premium subscription; developer account used for testing must also be Premium. | ✅ Product requirement documented (MVP already targets Premium users only). | Confirm marketing copy and onboarding screens explicitly call out Premium requirement. |
| Authentication | Authorization must use Spotify Accounts service (PKCE) and tokens cannot be shared between users. | ✅ Implementation already uses PKCE backend + per-user tokens. | None. |
| Playback | Audio must be streamed directly from Spotify APIs/SDK; no caching, recording, or mixing with local files. | ✅ Internal player loads official SDK and uses Spotify streams only. | During CEF work, ensure no buffering to disk beyond SDK defaults. |
| Branding & Attribution | Spotify branding must be displayed if any Spotify UI is visible; naming must follow “Powered by Spotify” rules. | ⚠️ Need final UX decision (internal player is headless, but fallback UI may expose metadata). | Work with design to add attribution in Now Playing view before launch. |
| Content Restrictions | No offensive filtering, lyric modifications, or track data persistence beyond SDK allowances. | ✅ App only reads playlists/tracks; no manipulation planned. | None. |
| Hardware / Commercial Use | Dedicated hardware integrations need separate approval. Electric Slideshow ships as macOS app only. | ✅ Not shipping hardware. | Revisit if kiosk hardware is ever considered. |
| Data Storage | Only store minimal metadata; never store access tokens unencrypted or longer than necessary. | ✅ Tokens already stored via Keychain. | Verify Chromium helper never logs tokens; redact in IPC logs. |
| Rate Limits | Must respect Spotify API rate limits and avoid aggressive polling. | ⚠️ New internal player device polling should be capped (< 1 req/sec). | Implement exponential backoff in Stage 3. |

**References**
- Spotify Web Playback SDK Terms of Use (developer.spotify.com)
- Spotify Developer Policy & Compliance Tips

_Last updated: 2025-12-03_
