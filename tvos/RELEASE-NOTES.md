Tab Lockdown TV 0.3.0 - website/API mode switching (build 5).

- Play/Pause switches from catalog or API player to direct website mode, and back to API mode.
- Restored hostname lockdown toggle, cursor/scroll controls, history, Home and Reload.
- API player configuration retained. Website mode requires a runtime-checked private WebKit selector.
- Native compilation and playback require Mac/Apple TV verification.

Tab Lockdown TV 0.2.2 — app-bound player configuration.

- Enable app-bound WebKit mode and declare the wrapper/player domains. The provider's sandbox check rejects missing service-worker support, even without a sandbox attribute.
- Display missing origin/storage/service-worker capabilities above the player to diagnose runtime compatibility.
- Retain native popup/navigation blocking. No fake service-worker APIs are injected.
- Device playback remains unverified; install build 4 to test the tvOS runtime.

Tab Lockdown TV 0.2.1 — player compatibility patch.

- Remove the injected window.open override that may trigger a false sandbox error. The wrapper has no sandbox attribute; native delegates still reject new windows.
- Live playback requires Apple TV verification.

Tab Lockdown TV 0.2.0 — native game browsing and Apple TV icon.

- Native live/upcoming game list from EmbedSE, category filtering and a server picker.
- Automatic server selection or individual player selection.
- Player inside a local iframe wrapper, with remote cursor and scroll mode.
- New windows, top-level navigation away, downloads and external-app launches blocked; a small known-ad-host filter added.
- Proper layered Apple TV Home screen icons and Top Shelf artwork.
- Brief local caching, ETags, 60-second foreground refresh and rate-limit backoff.

Download TabLockdownTV-unsigned.ipa and sign it for your Apple TV. Play/Pause opens filters on the game list and controls in the player. Back returns from the player to games.

Experimental: the API supplies embed pages, not direct video URLs. Playback still uses unsupported tvOS WebKit interfaces and needs testing on your device. All-ad blocking cannot be guaranteed. Some synthetic clicks and streams may fail; native video handoff does not support blob/DRM streams or browser-only authentication.

