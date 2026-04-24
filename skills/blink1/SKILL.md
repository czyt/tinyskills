---
name: blink1
description: Use when controlling blink(1) USB LED device via blink1-tool CLI, setting RGB/HSB colors, fade transitions, patterns, blinking effects, multi-device/LED control, or Linux udev setup. Keywords: blink1-tool, ThingM, USB LED, notification light, RGB color, HSB, pattern, blink, fade, chase, glimmer.
---

# blink(1) USB LED Control

## Overview

blink1-tool controls ThingM blink(1) USB LED devices. Supports RGB/HSB colors, fade transitions, patterns, multi-device, and multi-LED (mk2+).

**Quick Fix**: If device not detected on Linux, run `blink1-tool --add_udev_rules` then replug. See [Troubleshooting](#troubleshooting) for details.

### Version Compatibility

| Feature | mk1 | mk2 | mk3 |
|---------|-----|-----|-----|
| Multi-LED (top/bottom) | ✗ | ✓ | ✓ |
| Save pattern to flash | ✗ | ✓ | ✓ |
| Startup params | ✗ | v206+ | ✓ |
| Bootloader access | ✗ | ✗ | ✓ |
| User notes | ✗ | ✗ | ✓ |
| LED count | 1 | 2 | 2 |

Check firmware: `blink1-tool --fwversion`

## Quick Reference

| Action | Command |
|--------|---------|
| List devices | `blink1-tool --list` |
| Set RGB | `blink1-tool --rgb=255,0,0` or `--rgb=#FF0000` |
| Set HSB | `blink1-tool --hsb=<hue>,<sat>,<bri>` |
| Preset colors | `--red`, `--green`, `--blue`, `--cyan`, `--magenta`, `--yellow`, `--on` (white), `--off` |
| Blink | `blink1-tool --rgb=ff00ff --blink 3` |
| Fade time | `-m <ms>` (default 300ms) |
| Delay between events | `-t <ms>` (default 500ms) |
| Random colors | `blink1-tool --random=10` |
| Play pattern | `blink1-tool --playpattern '5,#ff0000,0.5,0,#00ff00,0.5,0'` |
| Read color | `blink1-tool --lastcolor` |
| Firmware version | `blink1-tool --fwversion` |

## Quick Start (3 Steps)

```bash
# 1. 检测设备
blink1-tool --list           # 应显示设备ID

# 2. 设置颜色（验证工作）
blink1-tool --rgb=255,0,0    # 红灯亮起 = 成功

# 3. 关闭设备
blink1-tool --off
```

如果 Step 1 无输出 → 见 [Troubleshooting](#troubleshooting)

## Color Control

### RGB Values
```bash
# Decimal: R,G,B (0-255 each)
blink1-tool --rgb=255,0,255    # Magenta

# Hex (with or without #)
blink1-tool --rgb=#FF9900      # Orange
blink1-tool --rgb FF9900       # Same
```

### HSB Values
```bash
# Hue (0-360), Saturation (0-100), Brightness (0-100)
blink1-tool --hsb=180,100,50   # Cyan at 50% brightness
```

### Fade Transitions
```bash
# -m sets fade duration (milliseconds)
blink1-tool -m 100 --rgb=255,0,0   # Quick 0.1s fade to red
blink1-tool -m 2000 --rgb=0,255,0  # Slow 2s fade to green
```

### Brightness Control
```bash
# -b sets brightness (0-255)
# 0 = use actual RGB values
# 1-255 = scale brightness (1=min, 255=max)
blink1-tool -b 50 --rgb=255,255,255   # Dim white
blink1-tool -b 200 --rgb=ff0000       # Bright red

# Or use HSB with brightness parameter
blink1-tool --hsb=0,100,25            # Red at 25% brightness
```

## Blinking & Effects

### Basic Blink
```bash
# Blink command LAST (timing set with -t and -m)
blink1-tool -t 200 -m 100 --rgb ff00ff --blink 5   # Purple, 5 times
```

### Random Colors
```bash
blink1-tool --random          # One random color
blink1-tool -t 2000 --random=100   # Every 2s, 100 random colors
```

### Glimmer Effect
```bash
# Soft flickering of set color
blink1-tool --rgb=0,0,255 --glimmer=10   # Blue glimmer 10 times
```

### Chase (Multi-LED mk2+)
```bash
blink1-tool --chase                     # Forever chase
blink1-tool --chase=5,3,18              # 5 times, LEDs 3-18
```

## Patterns

### Pattern String Format
`count,color,fade,delay,color,fade,delay,...`

```bash
# Purple-green flash 10 times
blink1-tool --playpattern '10,#ff00ff,0.1,0,#00ff00,0.1,0'

# Write pattern to device
blink1-tool --writepattern '5,#ff0000,0.3,0.1,#000000,0.3,0.1'
blink1-tool --savepattern   # Save to flash (mk2+)
```

### Pattern Management
```bash
blink1-tool --clearpattern   # Erase RAM pattern
blink1-tool --savepattern    # Save RAM to flash
blink1-tool --readpattern    # Download pattern as string
blink1-tool --play 1,0       # Play from position 0
blink1-tool --playstate      # Check play status
```

## Multi-Device & Multi-LED

### Device Selection
```bash
# First get device IDs
blink1-tool --list

# Select specific devices
blink1-tool -d all --rgb=ff0000     # All devices
blink1-tool -d 0,2 --rgb=00ff00     # 1st and 3rd device
```

### LED Selection (mk2+)
```bash
# -l: 0=all, 1=top, 2=bottom
blink1-tool --led=2 --rgb=FF9900    # Bottom LED orange
blink1-tool --ledn 1,3,5,7          # Specific LED list
```

## Device Setup (Linux)

```bash
# If device not detected, add udev rules
blink1-tool --add_udev_rules

# Then replug device

# Verify: blink1-tool --list should now show device
```

## Options Summary

| Option | Purpose |
|--------|---------|
| `-d <ids>` | Device IDs (from --list) |
| `-l <led>` | LED number: 0=all, 1=top, 2=bottom |
| `-m <ms>` | Fade time (default 300ms) |
| `-t <ms>` | Delay between events (default 500ms) |
| `-g` | Disable gamma correction |
| `-b <0-255>` | Brightness (0=real, 1-255 scaled) |
| `-q` | Quiet (mute output) |
| `-v` | Verbose debug |

## Troubleshooting

### No Device Found
```bash
# Check if device is connected
blink1-tool --list

# If empty output:
# 1. Physical: check USB connection
# 2. Linux: run --add_udev_rules, replug, or try with sudo
# 3. Permission: user must be in plugdev group (may need restart)
```

### Permission Denied (Linux)
```bash
# Option 1: Add udev rules (persistent)
blink1-tool --add_udev_rules
# Then replug device

# Option 2: Temporary sudo
sudo blink1-tool --list

# Option 3: Add user to plugdev group (persistent)
# If plugdev group doesn't exist:
sudo groupadd plugdev

# Add user to group:
sudo usermod -a -G plugdev $USER

# MUST restart system for group change to take effect
# (logout/login may not be sufficient)
```

## Common Mistakes

| Issue | Fix |
|-------|-----|
| Device not detected on Linux | Run `--add_udev_rules`, replug |
| Blink timing wrong | Put `--blink` LAST: `--rgb X --blink N` |
| Pattern blocks terminal | Pattern runs in blink1-tool - use background |
| Hex without # works | Both `#FF9900` and `FF9900` valid |
| mk2+ features on mk1 | LED selection, savepattern require mk2+ |
| Multiple devices conflict | Use `-d 0` or `-d all` to specify target |
| Color looks washed out | Try `-g` to disable gamma correction |