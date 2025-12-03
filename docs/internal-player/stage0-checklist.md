# Stage 0 Checklist (CEF Prerequisites)

| # | Task | Owner | Status | Notes |
| - | ---- | ----- | ------ | ----- |
| 1 | Document Spotify Web Playback SDK compliance requirements | Josh / Copilot | ✅ | See `docs/spotify-compliance.md`. |
| 2 | Decide on Chromium strategy (CEF) and capture architecture | Josh / Copilot | ✅ | See `docs/internal-player/cef-architecture.md`. |
| 3 | Prototype CEF app that loads `internal_player.html` and verifies Widevine | Josh | ⚠️ Pending | Prototype scaffolding in `Prototypes/CEFPlayer`; need to run and capture logs by 2025-12-10. |
| 4 | Record baseline metrics from prototype (startup time, memory, connect success) | Josh | ⚠️ Pending | Use `metrics-template.md` after running prototype. |
| 5 | Draft plan for integrating CEF into Xcode project & CI pipeline | Copilot | ✅ | Outline included in Stage 0 section and architecture doc (signing, helper layout). |
| 6 | Prepare storage strategy for CEF binaries (Git LFS or release artifact) | Josh | ⚠️ Pending | Decision needed before Stage 2 to avoid repo bloat. |
| 7 | Stakeholder approval for compliance + architecture | Josh / PM | ⚠️ Pending | Share docs with PM/legal for sign-off. |

**Next steps**
1. Build the standalone prototype (Tasks 3–4) and capture proof-of-life logs/screenshots.
2. Decide on binary distribution approach (Task 6).
3. Collect approvals (Task 7) and then open Stage 1 tickets.

_Last updated: 2025-12-03_
