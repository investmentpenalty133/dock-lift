<p align="right">
  <a href="./usage.zh.md">中文</a>
</p>
<!--rehype:style=float: right; bottom: -36px; position: relative;-->

Usage Guide
===

## Install & first launch

1. Install DockLift from the Mac App Store (or your distribution build).  
2. Open the app — a menu bar icon appears (no Dock tile by default).  
3. Grant **Accessibility** in System Settings when asked.  
4. Prefer leaving **Enable DockLift** turned on.

## Everyday use

### Bring a window from another Space

1. Open an app window on Space A.  
2. Switch to Space B.  
3. Click that app’s icon in the Dock.  
4. DockLift tries to show the recent window on Space B.

### Bring a window from another display

1. Move an app window to an external monitor.  
2. Move the pointer to the display where you work (Dock click screen).  
3. Click the app in the Dock.  
4. Even if the app was already frontmost on the other display, DockLift should pull the window to the Dock’s screen when **Move windows to the Dock’s screen** is enabled.

## Settings overview

Open **Settings…** from the menu bar (`⌘,`).

### General

| Option | Meaning |
|--------|---------|
| Enable DockLift | Master switch |
| Only react to Dock clicks | Off = also lift on ⌘Tab / other activations |
| Include minimized windows | Restore minimized windows |
| Move windows to the Dock’s screen | Multi-display reposition |
| Move windows to the current Space | Best-effort Space move |
| Use minimize fallback when needed | Public API fallback for Spaces |
| Launch at login | Start with your user session |
| Show title next to menu bar icon | Optional “DockLift” text in the menu bar |

### Permissions

Check Accessibility status and open System Settings to grant access if needed.

### Advanced — ignore list

Apps on this list are never lifted. Add via:

- Type a **bundle identifier** and **Add**  
- **Drop an app** onto the drop zone  
- **Choose App…** (file panel)  
- **Running Apps** menu  

Default ignores include Finder and DockLift itself (configurable list).

## Troubleshooting

| Symptom | What to try |
|---------|-------------|
| Nothing happens on Dock click | Check Accessibility is granted; Enable DockLift is on; app not on ignore list |
| Window stays on other display while app already focused | Update to latest build; ensure “Move windows to the Dock’s screen” is on; click Dock icon again |
| Some apps never move | Full-screen / certain Electron apps may ignore AX position; try exiting full screen |
| Feature does nothing | Grant **Accessibility** in System Settings → Privacy & Security |
| Drag-and-drop to ignore list fails | Use **Choose App…** or Running Apps; ensure you drop a `.app` bundle |

## Related

- [Privacy Policy](./privacy-policy.md)  
- [Feedback & Support](./feedback.md)  
- [Changelog](./CHANGELOG.md)  
