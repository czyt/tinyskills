# LazyCat Skills Organization

This directory contains two LazyCat-related skills with distinct purposes.

## Skills Overview

### 1. lazycat-app-publisher

**Purpose:** Convert and publish Docker applications to LazyCat Cloud.

**Use When:**
- Converting docker-compose.yml to LazyCat format
- Creating LPK packages
- Publishing apps to LazyCat App Store
- Managing application lifecycle (deploy, build, release)

**Key Files:**
| File | Content |
|------|---------|
| `SKILL.md` | Main skill instructions |
| `references/dev-workflow.md` | Development workflow |
| `references/injects.md` | Script injection reference |
| `references/cli-reference.md` | CLI commands |
| `ADVANCED_FEATURES.md` | compose_override, networking, etc. |
| `MANIFEST_REFERENCE.md` | Manifest format specification |

### 2. lazycat-sdk-dev

**Purpose:** Develop applications using LazyCat SDKs.

**Use When:**
- Code imports `@lazycatcloud/sdk`
- Code imports `gitee.com/linakesi/lzc-sdk`
- Need to query app lists, manage devices
- Using minidb or file-pickers extensions

**Key Files:**
| File | Content |
|------|---------|
| `SKILL.md` | SDK usage for Go and JavaScript |

## Relationship

```
┌─────────────────────────────────────────────────────────────┐
│                     User Request                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
              ┌───────────────┴───────────────┐
              │                               │
              ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────────┐
│  lazycat-app-publisher  │     │     lazycat-sdk-dev         │
│                         │     │                             │
│  • Docker → LPK         │     │  • Query apps               │
│  • Publish to store     │     │  • Manage devices           │
│  • Deploy/manage apps   │     │  • SDK integration          │
│  • Dev workflow         │     │  • minidb, file-pickers     │
└─────────────────────────┘     └─────────────────────────────┘
```

## Trigger Examples

### lazycat-app-publisher

```
✅ "Convert this docker-compose.yml to LazyCat"
✅ "Help me publish this app to LazyCat store"
✅ "Create an LPK package for my application"
✅ "How do I set up development workflow?"
```

### lazycat-sdk-dev

```
✅ "How do I use @lazycatcloud/sdk?"
✅ "Query all installed applications"
✅ "Get device list using Go SDK"
✅ "Use minidb in my LazyCat app"
```

## Version

- **lazycat-app-publisher**: v1.4.1+ compatible
- **lazycat-sdk-dev**: Supports Go and JavaScript/TypeScript SDKs