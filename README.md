# Hammerspoon Window Boundary Monitor

> 中文版请见 [`README.zh-CN.md`](README.zh-CN.md)

A Hammerspoon script designed to reserve a 32-pixel safe area at the bottom of your screen for [MiniMeters](https://minimeters.app). Whenever you maximise, tile or drag a window, it automatically adjusts the window's frame so that MiniMeters is never covered.

## ✨ Features

- 🚀 **One-click installation** – graphical installer, no Terminal required
- 🔄 **Smart updates** – detects newer versions and offers an in-place upgrade
- 🎯 **Single purpose** – does exactly one thing and does it well
- 🔧 **Zero configuration** – works out-of-the-box
- 🗑️ **Clean uninstall** – removes every file we have created

## 📦 Repository Layout

```text
hammerspoon/
├── installer.app                # GUI installer (recommended)
├── setup.sh                     # Command-line installer / updater / uninstaller
├── window_boundary_monitor.lua  # Core monitor module
├── init.lua                     # Hammerspoon init file that loads the monitor
├── MiniMeters-config.json       # Reference MiniMeters configuration
└── README.md                    # This file
```

## 🚀 Quick Start

### Method 1: GUI Installer (recommended)

1. Download the latest release from the [GitHub Releases page](https://github.com/the3asic/hsp-minimeters-safezone/releases).
2. Unzip the archive.
3. Double-click `installer.app` and follow the on-screen instructions.

### Method 2: Command-line Installer

```bash
# Clone the repository
git clone https://github.com/the3asic/hsp-minimeters-safezone.git
cd hsp-minimeters-safezone

# Run the installer script
./setup.sh
```

### Method 3: Silent Installation (for scripts / CI)

```bash
./setup.sh install -s
```

## 🎮 Usage

1. Launch **Hammerspoon** (first launch requires accessibility permission).
2. Start or reopen **MiniMeters**.
3. Maximise or drag any window to the bottom of the screen – it should stop 32 px above the edge.

Hammerspoon console helpers:

```lua
-- Show current status
wbm.showStatus()

-- Re-scan all windows manually
wbm.checkAllWindows()
```

## 🔧 Management

| Task             | GUI                                          | CLI                           |
|------------------|----------------------------------------------|-------------------------------|
| Check for update | Run `installer.app` again                    | `./setup.sh check`            |
| Update           | Choose "Update" in installer                 | `./setup.sh`                  |
| Uninstall        | Choose "Uninstall" in installer              | `./setup.sh uninstall`        |

## ⚙️ Recommended MiniMeters Settings

Provided in `MiniMeters-config.json`:

```json
{
  "window": {
    "always_on_top": true,
    "collapse_main_menu": false,
    "custom_position": {
      "anchor": "BottomLeft",
      "h": 32,
      "w": "stick",
      "x": "stick",
      "y": -32
    },
    "default_position": "custom"
  }
}
```

After importing the config, click **Default Position** in the MiniMeters menu to apply the new position.

## 🔍 Troubleshooting

| Symptom | Fix |
|---------|-----|
| Installer fails | Make sure Hammerspoon is installed: `brew install --cask hammerspoon` |
| Script does not run | Grant Hammerspoon Accessibility permission in System Settings and check the Hammerspoon console for errors |
| Window height wrong | Run `wbm.showStatus()` in the console to inspect current state |
| MiniMeters sits behind windows | Verify that MiniMeters is using the custom position (`y = -32`) |

## 🔄 Versioning

The installer records the installed version in `~/.hammerspoon/.wbm_version` and checks GitHub for newer versions on each run.

## 🏗️ Architecture

- Polls open windows every 2 seconds with minimal overhead.
- Ignores system utility panels and hidden windows.
- Dynamically adjusts window frames on multi-monitor setups.
- Designed for stability and negligible CPU usage.

## 🚀 Performance Optimizations (v0.0.2)

### Memory Management Improvements
- **Aggressive cache cleanup**: Window state cache reduced from 5 minutes to 30 seconds
- **Cache size limits**: Prevents unlimited growth (max 50 window states, 50 fullscreen logs)
- **Window list caching**: Reduces system API calls with 0.5s cache TTL
- **Enhanced resource cleanup**: Complete cleanup on stop with garbage collection

### Performance Monitoring
```lua
-- View memory usage and cache status
wbm.showStatus()

-- Manually clear all caches
wbm.clearCaches()
```

### Performance Testing
```bash
# Run the performance test script (5-minute test)
hs test_performance.lua
```

## 📜 License

MIT – see `LICENSE` for details. Contributions are welcome!