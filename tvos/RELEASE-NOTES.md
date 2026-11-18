Experimental Apple TV browser. Download TabLockdownTV-unsigned.ipa and sign it for your Apple TV using your signing service. This is a tvOS IPA, not the iPhone build.

Opens https://v2.streameast.ph with exact-host lockdown enabled. Popups are always blocked. Touch-surface swipes move the cursor; center click selects; directional buttons step the cursor; Play/Pause opens the menu with scroll mode, unlock, home, reload and native video handoff. Back goes back or opens the menu. TV/Home leaves the app.

The site's authentication redirect to auth.streamea.st requires unlocking and reopening Home. Lock again once back on the intended site. Embedded cross-host players remain allowed.

Uses unsupported WebKit runtime interfaces. Compilation does not establish compatibility with a particular tvOS release. No physical Apple TV testing has been performed. Synthetic clicks may be rejected by players, login widgets or anti-bot challenges. Native playback requires a directly accessible HTTP(S) video and does not transfer website cookies or custom headers. Blob/DRM playback is not supported by native handoff.

Lockdown is a browsing guard, not a network firewall: redirects may send a request before cancellation. It does not block ads inside the page or subframe network activity.
