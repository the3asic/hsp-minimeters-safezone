# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Hammerspoon configuration project focused on **window boundary monitoring** - automatically preventing windows from overlapping the bottom 32 pixels of macOS screens. The project replaces a previous yabai/skhd setup while maintaining essential functionality.

## Core Architecture

### Primary Module: `window_boundary_monitor.lua`
- Timer-based architecture using `hs.timer.doEvery` for reliable 2-second interval checking
- Screen watcher using `hs.screen.watcher` for display configuration changes
- Screen boundary caching with multi-monitor support
- Smart exclusion system for system apps and utility windows

### Key Components
- **WindowBoundaryMonitor**: Main module with start/stop/configuration methods
- **Timer-based Checking**: Periodic scanning of all visible windows every 2 seconds
- **Boundary Detection**: Calculates violations against bottom 32px boundary
- **Auto-adjustment**: Resizes windows by reducing height to fit within boundaries
- **Screen Monitoring**: Automatic boundary recalculation on display changes

### Configuration Management
- Global variable `wbm` exposed for console interaction
- Configurable boundary height (1-200px, default 32px)
- Dynamic exclusion list management
- Hotkey system for manual control

## Usage Commands

### Deployment to Hammerspoon
```bash
# Copy configuration files to Hammerspoon directory
cp init.lua ~/.hammerspoon/
cp window_boundary_monitor.lua ~/.hammerspoon/

# Reload Hammerspoon configuration
hs.reload()
```

### Manual Testing
```bash
# Run test script (requires Hammerspoon to be running)
hs test.lua
```

### Console Commands (via Hammerspoon Console)
```lua
-- Status and control
wbm.showStatus()                    -- Display current configuration
wbm.checkAllWindows()              -- Manual scan of all windows
wbm.start() / wbm.stop()           -- Start/stop monitoring

-- Configuration
wbm.setBoundaryHeight(50)          -- Change boundary height
wbm.addExcludedApp("App Name")     -- Add app to exclusion list
wbm.removeExcludedApp("App Name")  -- Remove from exclusion list
```

## Key Design Decisions

### Minimal Approach
- **No window management hotkeys**: Replaced by Raycast application launcher
- **No window resizing controls**: Focus purely on boundary protection
- **Simple toggle mechanism**: Enable/disable Hammerspoon = enable/disable 32px protection

### Performance Optimizations
- Hash table lookups for O(1) app exclusion checks
- Timer-based checking (2-second intervals) for stability and low resource usage
- Smart filtering to avoid processing irrelevant windows
- Resource cleanup on config reload
- Minimal logging (only when violations are found and fixed)

### Multi-Monitor Handling
- Per-screen boundary calculation respecting macOS coordinate system
- Screen change detection with automatic boundary recalculation
- Support for complex monitor arrangements (negative coordinates)

## Integration Notes

### Compatibility with Status Bar Apps
- **Minimeters compatibility**: 32px bottom boundary protects status indicators
- **External bar simulation**: Hammerspoon enabled = external bar active
- **Toggle workflow**: Start/stop Hammerspoon to enable/disable protection

### Exclusion Strategy
Automatically excludes:
- System applications (System Preferences, Finder, etc.)
- Small utility windows (<200px width or <100px height)
- Non-standard windows (dialogs, palettes)
- Windows with specific title patterns (Inspector, Console, etc.)

## Migration from yabai/skhd

### Preserved Functionality
- Bottom boundary protection (equivalent to `external_bar main:0:32`)
- Application launching (migrated to Raycast hotkeys)
- Window information display

### Removed Features
- Window tiling and management
- Window swapping/warping
- Space/desktop management
- Complex window resizing controls

### Hotkey Migration
Original skhd hotkeys for app launching should be configured in Raycast:
- hyper + o → Obsidian
- hyper + n → Notion  
- hyper + z → Google Chrome
- hyper + w → WeChat
- hyper + c → ChatGPT
- hyper + t → Warp
- hyper + m → Monica
- hyper + ` → AIBOI
- hyper + p → Cursor