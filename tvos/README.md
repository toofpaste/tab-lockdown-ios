# Tab Lockdown TV (experimental)

Native tvOS shell for the existing hostname-lockdown idea, with a Siri Remote cursor. Starts at https://v2.streameast.ph. The browser runs on Apple TV itself and needs no streaming computer or developer backend.

Apple does not support web views on tvOS. This app dynamically loads WebKit and declares the required Objective-C method signatures locally. It is intended for personal sideloading. A runtime availability check can report missing classes, but cannot guarantee every private implementation works on newer firmware. tvOS 27.2.1 and physical hardware have not been validated.

## Install

The **Build Apple TV app** GitHub Action is separate from the iPhone action. It builds an unsigned arm64 tvOS IPA on a standard macOS runner and publishes a `tvos-build-*` release. Download **TabLockdownTV-unsigned.ipa**, sign it for your registered Apple TV with your signing service, and use that service's Apple TV installation flow. Signing-service compatibility is not verified by this project.

This folder is deployed as `tvos/` inside the existing `tab-lockdown-ios` repository; its workflow is installed at repository-root `.github/workflows/build-tvos.yml`. Only manual workflow dispatch builds it. It does not require an Apple signing certificate in GitHub.

Local Mac build: install Xcode and XcodeGen, run `xcodegen generate`, then open `TabLockdownTV.xcodeproj`. Select your Apple TV and development team to sign locally. Windows cannot compile the tvOS SDK.

## Remote

| Control | Action |
| --- | --- |
| Swipe touch surface | Move cursor, or scroll in Scroll mode |
| Center click | Click under cursor |
| Directional button | Step cursor, or scroll |
| Play/Pause | Open controls |
| Back/Menu | Back in page history, or controls at root |
| TV/Home | Leave app |

For touch movement, enable touch tracking for your remote in Apple TV settings. The controls menu switches scrolling, toggles lockdown, reloads, opens Home, or tries native video playback under the cursor. Orange cursor means scrolling. Web text input and complex drag/drop widgets are not fully implemented; this is an initial browsing/player build.

## Lockdown and compatibility

The exact starting hostname is locked by default. Other top-level HTTP(S) hosts and external-app schemes are blocked; sibling subdomains are not automatically trusted. Subframe documents and media from other hosts can load. New windows are always refused, even while unlocked. Native action and response policies enforce the lock; injected popup guards supplement them. This is not a firewall and cannot promise cancellation before every redirected request is sent.

The site's observed authentication redirect is on `auth.streamea.st`. To allow it: Play/Pause → Unlock → Home; finish authentication; return to the intended website; then Lock to current hostname. No automatic authentication exception is configured.

Remote clicks are JavaScript mouse events. Frame messages relay cursor coordinates to cross-origin iframe scripts injected by WebKit. Synthetic events do not have browser user-gesture trust; some video controls and anti-bot challenges will reject them. Native video handoff only works for direct HTTP(S) sources and does not forward cookies, custom headers, blob streams or DRM. A successful build cannot verify the live site or playback on the TV.

## Verification

`node --test Tests/interaction.test.cjs` checks cursor scaling, iframe relay, message-source filtering, nested scrolling and video handoff behavior. On macOS, `clang -fobjc-arc -framework Foundation Tests/policy.m -o /tmp/tvos-policy && /tmp/tvos-policy` checks the actual native hostname policy. The action runs both and compiles the device binary.

On your TV verify: launch, move and click, scroll, blocked off-site link, blocked popup, unlock/sign-in/relock, embedded player and native handoff. Report any launch failure and the exact version shown under Settings → General → About.
