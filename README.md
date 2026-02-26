# Verso

Verso is a native SwiftUI client for [Jellyfin](https://jellyfin.org) media servers, with built-in support for [Jellyseerr](https://github.com/Fallenbagel/jellyseerr) media requests and [Prograrr](https://github.com/IAvecilla/Prograrr) download tracking.

---

## Features

### Playback
- **HLS direct play** — streams `main.m3u8` to avoid unnecessary transcoding
- **HDR & Dolby Vision** passthrough
- **Client-side PGS subtitles** — lazy decompression of raw RLE bitmaps rendered via CGImage, no server burn-in required
- **Smart audio selection** — auto-detects TrueHD/DTS defaults and prefers EAC3 > AC3 > AAC for direct play

### Home & Library
- Download tracking via Prograrr integration

### Discover & Requests
- TMDB-powered search via Jellyseerr
- Trending & popular media
- Full request workflow with quality profile and season selection

---

## Tech Highlights

- **Zero external dependencies** — no SPM, CocoaPods, or Carthage
- **@Observable MVVM** — iOS 17 Observation framework throughout
- **async/await networking** — three standalone URLSession clients (Jellyfin, Jellyseerr, Prograrr)
- **Actor-based image cache**
- **Keychain-backed authentication**

---

## Requirements

| Requirement | Details |
|---|---|
| iOS | 17.0+ |
| Jellyfin server | Required |
| Jellyseerr | Optional — enables Discover & Requests |
| Prograrr | Optional — enables download tracking |

---

## Build

```bash
xcodebuild build \
  -project JellyFinn.xcodeproj \
  -scheme Verso \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
