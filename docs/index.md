---
layout: default
title: macOS Keep Awake App
description: stayawake is a lightweight macOS keep awake app that automatically prevents idle sleep during builds, downloads, scripts, audio playback, fullscreen work, and AI agent runs.
image: /assets/status-preview.png
image_alt: Awake and Sleep status icons for the stayawake macOS menu bar app
---

<section class="hero">
  <div class="hero-copy">
    <p class="eyebrow"><span class="pulse"></span> macOS keep-awake utility</p>
    <h1>Keep your Mac awake while work is alive.</h1>
    <p class="lede">stayawake is a lightweight macOS keep awake app that watches system signals, protects long-running work, and steps aside when your Mac can sleep.</p>

    <div class="hero-install" id="install" aria-label="Homebrew install command">
      <div class="hero-install-label">
        <span>Homebrew</span>
        <span>macOS 13+</span>
      </div>
      <pre><code>brew install --cask amoswzw/tap/stayawake</code></pre>
    </div>

    <div class="actions">
      <a class="button secondary" href="{{ site.download_url }}">Download latest DMG</a>
      <a class="button secondary" href="{{ site.repository_url }}">View source</a>
    </div>
  </div>

  <div class="status-demo" aria-label="stayawake menu preview">
    <div class="desktop-strip">
      <span>Fri 16:20</span>
      <img src="assets/app-icon.png" alt="stayawake menu-bar icon">
    </div>
    <div class="menu-window">
      <div class="menu-row main-state">
        <span class="dot"></span>
        <span>
          <span class="row-title">Awake</span>
          <span class="row-note">CPU and network activity detected</span>
        </span>
        <span class="tag">ACTIVE</span>
      </div>
      <div class="menu-row">
        <span class="dot warn"></span>
        <span>
          <span class="row-title">Next check</span>
          <span class="row-note">Low-resource cooldown is running</span>
        </span>
        <span class="tag warn">120s</span>
      </div>
      <div class="log-row">
        <span class="dot"></span>
        <span>
          <span class="row-title">Build process matched</span>
          <span class="row-note">Recent input keeps work protected</span>
        </span>
        <span class="tag">Awake</span>
      </div>
      <div class="log-row">
        <span class="dot sleep"></span>
        <span>
          <span class="row-title">Idle window cleared</span>
          <span class="row-note">Sleep allowed when signals are quiet</span>
        </span>
        <span class="tag sleep">Sleep</span>
      </div>
    </div>
  </div>
</section>

<section class="section alt">
  <div class="section-header">
    <h2>One tiny icon, two clear states.</h2>
    <p>The character changes with the decision, and the settings icon follows the same visual language.</p>
  </div>
  <div class="status-preview">
    <img src="assets/status-preview.png" alt="Awake and Sleep status icons">
    <div class="status-copy">
      <div class="state-line">
        <strong>Awake</strong>
        <span>Work is active, so stayawake holds a power assertion.</span>
      </div>
      <div class="state-line sleep">
        <strong>Sleep</strong>
        <span>No useful activity is detected, so macOS can sleep normally.</span>
      </div>
    </div>
  </div>
</section>

<section class="section">
  <div class="section-header">
    <h2>Signals, not noise.</h2>
    <p>The policy favors low overhead and meaningful decisions over constant polling.</p>
  </div>
  <div class="signal-rail">
    <div class="signal">
      <span class="stripe"></span>
      <strong>Resources</strong>
      <p>CPU, network, disk, and audio activity keep long tasks uninterrupted.</p>
    </div>
    <div class="signal">
      <span class="stripe teal"></span>
      <strong>Context</strong>
      <p>Foreground work apps, fullscreen windows, and task process names add intent.</p>
    </div>
    <div class="signal">
      <span class="stripe warn"></span>
      <strong>Cooldown</strong>
      <p>Automatic checks use a release cooldown to reduce always-on resource usage.</p>
    </div>
    <div class="signal">
      <span class="stripe sleep"></span>
      <strong>Privacy</strong>
      <p>No account, no telemetry, no uploaded data, and no Accessibility permission.</p>
    </div>
  </div>
</section>

<section class="section">
  <div class="section-header">
    <h2>For Mac work that should finish.</h2>
    <p>Use stayawake when macOS should avoid idle sleep for active work, then return to normal sleep behavior after signals go quiet.</p>
  </div>
  <div class="signal-rail">
    <div class="signal">
      <span class="stripe"></span>
      <strong>Long jobs</strong>
      <p>Builds, downloads, scripts, renders, backups, archive jobs, and AI agent runs can finish without changing global power settings.</p>
    </div>
    <div class="signal">
      <span class="stripe teal"></span>
      <strong>Media and meetings</strong>
      <p>Audio playback and fullscreen work can keep the system awake while the activity is still useful.</p>
    </div>
    <div class="signal">
      <span class="stripe warn"></span>
      <strong>Automatic release</strong>
      <p>When activity stops, stayawake releases its macOS power assertion so the normal sleep policy can continue.</p>
    </div>
    <div class="signal">
      <span class="stripe sleep"></span>
      <strong>Automation runs</strong>
      <p>Local AI agents and command-line jobs can keep working without a prevent-sleep setting left on all day.</p>
    </div>
  </div>
</section>

<section class="section alt">
  <div class="section-header">
    <h2>Menu first, logs one click away.</h2>
    <p>The menu opens directly to the current state, reason, next check timing, and recent status history.</p>
  </div>
  <div class="screenshot-grid">
    <a class="shot-link featured" href="SCREENSHOTS.html">
      <img src="screenshots/stayawake_screen_shot.jpg" alt="stayawake menu with current state and recent logs">
      <span class="shot-label">Menu bar <span>current state</span></span>
    </a>
    <div class="shot-stack">
      <a class="shot-link" href="SCREENSHOTS.html">
        <img src="screenshots/stayawake_screen_shot2.jpg" alt="stayawake general settings">
        <span class="shot-label">Settings <span>general</span></span>
      </a>
      <a class="shot-link" href="SCREENSHOTS.html">
        <img src="screenshots/stayawake_screen_shot5.jpg" alt="stayawake logs window">
        <span class="shot-label">Logs <span>details</span></span>
      </a>
    </div>
  </div>
</section>

<section class="section">
  <div class="privacy-band">
    <div>
      <h2>Local by design.</h2>
      <p>stayawake reads aggregate macOS signals and stores settings locally. It does not inspect file content, browser pages, terminal output, or window text.</p>
      <div class="actions">
        <a class="button" href="{{ site.download_url }}">Download</a>
        <a class="button secondary" href="SCREENSHOTS.html">Open screenshots</a>
      </div>
    </div>
    <ul class="privacy-list">
      <li>No cloud service</li>
      <li>No account or telemetry</li>
      <li>No Accessibility permission</li>
      <li>English and Simplified Chinese</li>
    </ul>
  </div>
</section>
