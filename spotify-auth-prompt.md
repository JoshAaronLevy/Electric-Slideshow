You are helping debug a networking issue in my macOS SwiftUI app *Electric Slideshow*.
This project handles the OAuth PKCE flow with Spotify. The app can open the Spotify consent screen and receives the redirect callback correctly. However, after the redirect, the app logs this error:

```
Token exchange failed: A server with the specified hostname could not be found.
NSErrorFailingURLStringKey=https://electric-slideshow-server.onrender.com/auth/spotify/token
Code=-1003
```

Important details:

* The backend is a Node/Express service hosted on Render:
  [https://electric-slideshow-server.onrender.com](https://electric-slideshow-server.onrender.com)
* Visiting this URL in the browser works.
* The token endpoint is supposed to be:
  POST [https://electric-slideshow-server.onrender.com/auth/spotify/token](https://electric-slideshow-server.onrender.com/auth/spotify/token)
* The app DOES receive the OAuth callback correctly via the custom URL scheme.
* The failure occurs **when the Swift code tries to contact the backend token endpoint.**

### **What I need you to do**

1. Search the entire Swift project for:

   * Anywhere the backend URL or base URL is defined.
   * Any config, constant, struct, or environment injection that defines the back-end hostname.
   * Any URL construction using `URL(string:)`, `URLComponents`, or `appendingPathComponent`.

2. Verify that the backend URL in the Swift code:

   * Exactly matches `https://electric-slideshow-server.onrender.com`
   * Uses HTTPS (not HTTP)
   * Has no trailing spaces, newline characters, or hidden characters
   * Is not conditionally overwritten in DEBUG / RELEASE blocks
   * Is not still pointing at the old `slideshow-buddy-server` URL

3. Look for logic that handles the Spotify callback.
   Find the code that extracts the `code` from the redirect and calls the token exchange method.
   Confirm the token-exchange method is being called with the correct URL.

4. Inspect the exact code that creates and performs the URLRequest to `/auth/spotify/token` and verify that:

   * The URL is constructed correctly
   * It is not accidentally creating a malformed URL like `"https: //electric..."`
   * It is not appending paths incorrectly (double slashes, missing slashes, etc.)
   * It is using POST, not GET

5. If you find any incorrect URLs, stale config, or malformed URL construction, please:

   * Point them out
   * Suggest the minimal code change needed
   * Apply the fix in the codebase if appropriate

Do NOT alter any unrelated architecture. Only focus on making sure the Swift app is calling the correct backend URL for the token exchange.

When you're ready, tell me what you found and what changes (if any) you made.