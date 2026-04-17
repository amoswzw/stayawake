---
layout: default
title: stayawake
---

<p align="center">
  <img src="assets/app-icon.png" width="128" alt="stayawake app icon">
</p>

# stayawake

Lightweight automatic sleep control for macOS.

stayawake keeps your Mac awake during long-running work and lets macOS sleep normally when useful activity is gone.

<p>
  <a href="{{ site.github.repository_url }}/releases/latest">Download latest DMG</a>
  ·
  <a href="SCREENSHOTS.html">Screenshots</a>
  ·
  <a href="{{ site.github.repository_url }}">Source code</a>
</p>

![Awake and Sleep status icons](assets/status-preview.png)

## What It Handles

- Builds, downloads, renders, scripts, and other long-running tasks
- CPU, network, disk, audio, fullscreen, foreground-app, and idle signals
- Manual keep-awake for 30 minutes, 1 hour, or until turned off
- Recent decision logs directly from the menu
- English and Simplified Chinese

## Status

The menu-bar icon changes with the current decision.

- Awake: stayawake is actively keeping the Mac awake.
- Sleep: macOS is allowed to sleep normally.

## Privacy

stayawake runs locally. It does not require an account, cloud service, telemetry, Accessibility permission, or content upload.

## Requirements

- macOS 13 or later
- Apple silicon or Intel Mac

## More

- [Screenshots](SCREENSHOTS.html)
- [Release downloads]({{ site.github.repository_url }}/releases/latest)
- [README]({{ site.github.repository_url }}#readme)
