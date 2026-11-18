# Tab Lockdown TV — Live Sports

Version 0.2 replaces the website homepage with a native Apple TV game list powered by the [EmbedSE API](https://api.embedse.com/docs/). Choose a live or upcoming game, then automatic server selection or an individual server. Apple TV focus navigation operates the list; the remote cursor operates the embedded player.

## Install and controls

Run **Build Apple TV app** on GitHub. It publishes TabLockdownTV-unsigned.ipa in a tvos-build-* release for your Apple TV signing workflow. The build is separate from iPhone and runs only on manual dispatch. Sign the IPA using your service and install the updated app. It uses the same bundle ID as 0.1, with version/build bumped to 0.3.0/5.

The app includes tvOS layered Home screen icons and standard/wide Top Shelf artwork. The workflow verifies compiled assets and primary-icon metadata exist before packaging.

| Screen | Control | Action |
| --- | --- | --- |
| Game list | Directional controls / swipe | Focus games |
| Game list | Select | Choose a game and current server |
| Game list | Play/Pause | Live/upcoming, category filter, refresh |
| Player | Swipe / directional controls | Move cursor (or scroll in Scroll mode) |
| Player | Select | Click at cursor |
| Player | Play/Pause | Scroll mode, reload, return to games, native video handoff |
| Player | Back/Menu | Return to game list |
| Any screen | TV/Home | Leave app |

## API and playback

The API needs no key. A visible game list refreshes every 60 seconds, with a 30-second local cache, conditional ETags, and Retry-After handling. Filters operate on the local snapshot. Server metadata is fetched on selection and cached briefly; server numbers are not persisted. Malformed/null data, unavailable games, network failures and rate limits have explicit handling. Existing results remain visible after a refresh error.

This personal app calls the API directly from the TV; it has no hosted backend or API key. The provider recommends a shared server cache for visitor-facing integrations. Revisit that architecture before distributing it broadly. Provider rate limits apply per public IP.

The documented URLs are **HTML embeds**, not direct HLS URLs. The player refuses standalone navigation, so we load it inside an iframe in a local wrapper with a reserved .invalid base origin. There is no website hosted at that origin. Actual player compatibility with this app-origin/referrer must be tested on the TV. The API does not remove the need for experimental WebKit playback on tvOS.

## Blocking and limitations

The wrapper is the only allowed top-level page. The app rejects new windows, downloads, external-app schemes and attempts to navigate the whole screen away. Cross-host subframes and media are allowed because players depend on them. Popup rejection uses native delegates; player-frame window.open is left unchanged to avoid interfering with sandbox detection. Known ad-host request rules load before the player; if the runtime cannot compile them, the status explicitly reports this while retaining native popup/navigation guards.

This is **best-effort blocking, not a promise of all ads removed**. The small bundled list does not cover every rotating ad domain, same-origin ad, frame navigation or ad embedded in the video. More aggressive rules can break playback. Redirect requests may be sent before cancellation; this is not a firewall. The provider documents an ad-free embed arrangement separately.

Remote clicks are synthetic JavaScript events and may be rejected by player controls or anti-bot checks. Native video handoff only works for directly accessible HTTP(S) media without required browser cookies/headers; it does not support blob/DRM streams. Full web text entry and drag/drop are not implemented.

## Build and checks

On a Mac with Xcode and XcodeGen, run xcodegen generate in this folder. For local signing, open the generated project and select your team and Apple TV.

Run node --test Tests/interaction.test.cjs to verify cursor/frame behavior and blocking-rule URL boundaries. CI compiles and runs Foundation policy and API-validation checks, builds against the Apple TV SDK, then checks the IPA resources. PNG asset metadata is validated locally and the icon is visually inspected. Native game-list focus and live playback still require a device test. A successful build does not establish compatibility with every tvOS version.

make_assets.py reproduces the existing green-lock design in tvOS asset sizes using Pillow. Generated PNGs are committed; no image tool is required by CI.


## Player compatibility (0.2.2)

The provider also labels missing service-worker support as a sandbox error. The player WebView now opts into app-bound domains (the local wrapper and embedse.com), which is WebKit's configuration path for service workers without browser entitlements. Third-party subframes remain allowed by native policy. The app reports an opaque origin, unavailable storage, or unavailable service workers above the player when detected. No browser APIs are stubbed. Actual service-worker availability and playback still require verification on the installed tvOS runtime.

## Switching modes (0.3.0)

Press Play/Pause in the game list or API player and select **Switch to website mode**. The original homepage opens directly with cursor/scroll controls, a hostname lockdown toggle, Home and Reload. Back navigates website history or opens the menu. Play/Pause > **Switch to API mode** returns to the existing game catalog and filters. The app starts in API mode; switching away releases the previous player.

Website mode probes WebKit's private `_setIgnoresAppBoundDomains:` configuration selector to preserve cursor scripting and unlocked navigation without changing API player configuration. If unavailable, a visible error explains that Play/Pause can return to API mode. This is experimental and requires device validation. Implementation reference: https://github.com/WebKit/WebKit/blob/main/Source/WebKit/UIProcess/API/Cocoa/WKWebViewConfiguration.mm.
