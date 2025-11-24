I’m getting a Spotify playback error in my macOS client when I try to play a slideshow with an associated Spotify playlist.

The backend is a Node/Express app that handles Spotify OAuth and playback via the Spotify Web API. The macOS app calls this backend to:

- Check Spotify connection status
- List custom playlists
- Start/stop playback of a playlist

When the client calls the “start playback” endpoint, Spotify returns:

{
  "error": {
    "status": 404,
    "message": "Player command failed: No active device found",
    "reason": "NO_ACTIVE_DEVICE"
  }
}

The access token is valid and not expired (the logs confirm this), but there is no “active device” from Spotify’s point of view.

I want you to improve our backend so that:

1. Scopes and auth are correct.
2. There is a clean endpoint to list devices.
3. The playback start endpoint handles NO_ACTIVE_DEVICE gracefully and returns clear JSON errors to the client.
4. Playback stop is also robust.

Please follow this plan and modify the existing backend code accordingly:

---

1) Check and fix Spotify OAuth scopes

- Find the Spotify auth setup (where we build the authorize URL and request tokens).
- Confirm the requested scopes include at least:

  - user-read-playback-state
  - user-modify-playback-state
  - user-read-currently-playing

- If they do not, update the Spotify OAuth configuration so future logins use those scopes.
- Make sure the scope value is passed everywhere needed (authorize URL, refresh logic, etc.).

---

2) Implement or fix a “list devices” endpoint

- Add or verify an endpoint like:

  GET /api/spotify/devices

- This endpoint should:

  - Use the stored refresh/access token for the current user.
  - Call `GET https://api.spotify.com/v1/me/player/devices`.
  - Handle non-200 responses gracefully (log details, return a meaningful error).
  - Return a JSON payload like:

    {
      "devices": [
        {
          "id": "...",
          "name": "...",
          "type": "...",
          "is_active": true,
          "is_restricted": false,
          "volume_percent": 100
        }
      ]
    }

  - If the devices array is empty, return `{ "devices": [] }` rather than throwing.

- Make sure this endpoint fits into whatever auth/session model we already use (e.g., user id from cookie, JWT, or session).

---

3) Harden the “start playback” endpoint

- Find the playback start endpoint. It might look like:

  - GET or POST /api/spotify/playback/start/:playlistId

- Update its logic to:

  1. Use a valid access token (refresh if necessary using our existing auth helper).
  2. Call `GET https://api.spotify.com/v1/me/player/devices`.
  3. If the user has **no devices**:

     - Return a 409 (or 400) error with a clear JSON body:

       {
         "error": "NO_ACTIVE_DEVICE",
         "message": "No active Spotify devices. Please open Spotify on one of your devices and start playing something once, then try again."
       }

  4. If devices are present:

     - Pick a device to target. For MVP, a reasonable strategy is:
       - Prefer a device with `is_active === true`.
       - If none, fall back to the first device of type "Computer" or just the first device in the array.
     - Call `PUT https://api.spotify.com/v1/me/player/play?device_id=<chosenDeviceId>` with a JSON body that starts playback of the requested playlist. For example:
       - `context_uri` pointing to the playlist URI, or
       - a list of track URIs.

  5. Log the response status and body for debugging if there is an error, but return a clean error payload to the client instead of just passing through raw Spotify errors.

---

4) Harden the “stop playback” endpoint

- Find or add an endpoint like:

  POST /api/spotify/playback/stop

- Implementation:

  - Use the valid token.
  - Call `PUT https://api.spotify.com/v1/me/player/pause`.
  - If Spotify returns NO_ACTIVE_DEVICE, treat that as a no-op (already stopped) and return a 200 or 204 to the client.
  - For other errors, log details and return a reasonable error JSON.

---

5) Return clear structured errors to the macOS client

- For all Spotify Web API calls (devices, start, stop), avoid throwing generic errors.
- Instead, return JSON structured like:

  - On success:

    { "ok": true, ... any data ... }

  - On known errors (like NO_ACTIVE_DEVICE):

    {
      "ok": false,
      "code": "NO_ACTIVE_DEVICE",
      "message": "No active Spotify devices..."
    }

  - On unexpected errors:

    {
      "ok": false,
      "code": "UNEXPECTED_ERROR",
      "message": "Something went wrong talking to Spotify.",
      "details": "optional short reason or status code"
    }

Once you’ve made these changes, please provide an overview for me on:

- The updated routes for:
  - /api/spotify/devices
  - /api/spotify/playback/start/:playlistId
  - /api/spotify/playback/stop
- The updated Spotify auth/scope configuration.
- Any helper modules you modified for making Spotify Web API calls.