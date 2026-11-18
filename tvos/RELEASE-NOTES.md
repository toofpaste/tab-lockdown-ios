Tab Lockdown TV 0.2.0 — native game browsing and Apple TV icon.

- Native live/upcoming game list from EmbedSE, category filtering and a server picker.
- Automatic server selection or individual player selection.
- Player inside a local iframe wrapper, with remote cursor and scroll mode.
- New windows, top-level navigation away, downloads and external-app launches blocked; a small known-ad-host filter added.
- Proper layered Apple TV Home screen icons and Top Shelf artwork.
- Brief local caching, ETags, 60-second foreground refresh and rate-limit backoff.

Download TabLockdownTV-unsigned.ipa and sign it for your Apple TV. Play/Pause opens filters on the game list and controls in the player. Back returns from the player to games.

Experimental: the API supplies embed pages, not direct video URLs. Playback still uses unsupported tvOS WebKit interfaces and needs testing on your device. All-ad blocking cannot be guaranteed. Some synthetic clicks and streams may fail; native video handoff does not support blob/DRM streams or browser-only authentication.

