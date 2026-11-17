# Tab Lockdown for iPhone

An iOS 16+ browser with hostname lockdown, popup blocking, local bookmarks, and on-device video discovery.

## Install from Windows

Download **TabLockdown-unsigned.ipa** from this repository's Releases. Install AltStore Classic using AltServer on Windows, then import the IPA in AltStore. AltStore signs the app for your Apple account. Enable Developer Mode on the iPhone when required. Free-account installations need refreshing every seven days.

[Official Windows installation instructions](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)

The IPA is unsigned and requires signing through your sideloading tool. Physical iPhone installation still needs testing by the person installing it.

## Use

Enter a URL and choose Open website. Hostname lockdown allows the exact starting hostname and blocks other hosts. Turn it off to navigate between websites. Popups remain blocked in both modes. Reload refreshes the current page. Save bookmarks on the device.

Find video examines video elements and media requests in the currently loaded page and embedded frames. Start playback on the website, then rescan if no sources appear. Direct MP4 and HLS URLs can be opened from the home screen with Find video. Detected sources open in a separate native player. DRM, DASH, blob-only media, expired links, unsupported codecs, and servers requiring their original player may prevent standalone playback. Detection never guarantees access.

WebKit provides navigation decisions and redirect callbacks. The app cannot guarantee interception before every redirected network request is sent. Hostname lockdown controls browsing destinations and should not be used as a network firewall.

## Costs and privacy

The native app connects directly from the phone to the selected websites and media servers. It has no developer-operated backend, analytics, accounts, metered APIs, paid SDKs, or dependency on the hosted PWA. Other people's app use does not consume the repository owner's compute or hosting. Website subscriptions and users' own cellular-data charges remain their responsibility.

Builds run only when the owner manually starts the workflow, on GitHub's standard macOS runner in this public repository. Downloads do not trigger builds. Builds publish small release assets. This repository does not enable paid runners or purchase services. GitHub's future policies remain under GitHub's control.

Browsing cookies and bookmarks stay in the app's local WebKit storage and UserDefaults. For a detected video, the native player can use applicable cookies from this app's browsing session. Nothing is sent to a developer server.

## Build

Run **Build iPhone app** from the Actions tab. It checks the hostname policy, generates an Xcode project using XcodeGen, compiles device and simulator builds, launches the simulator, and publishes an unsigned IPA and simulator screenshot.

For local development on a Mac, install Xcode and XcodeGen, then run `xcodegen generate`. Open `TabLockdown.xcodeproj`. Choose your own development team to sign for your phone.
