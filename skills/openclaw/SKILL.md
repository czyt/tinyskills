---
name: openclaw
description: >
  OpenClaw personal AI assistant helper. Use when setting up, configuring,
  developing plugins, or troubleshooting OpenClaw (formerly Clawdbot/Moltbot).
  Triggers on mentions of openclaw, clawdbot, moltbot, gateway daemon, or
  multi-channel AI assistant setup.
---

# OpenClaw Assistant

Help users set up, configure, develop plugins for, and troubleshoot
[OpenClaw](https://openclaw.ai/) — the open-source personal AI assistant that
bridges messaging channels to AI agents.

## When to Apply

Use this skill when the user:
- Mentions OpenClaw, Clawdbot, or Moltbot
- Needs help with multi-channel AI assistant gateway setup
- Is developing OpenClaw plugins or extensions
- Is configuring messaging channel integrations (WhatsApp, Telegram, Discord,
  iMessage, Slack, Signal, Teams, Matrix, etc.)

## Quick Reference

### Installation

```bash
# Requires Node >= 22
npm install -g openclaw@latest
openclaw onboard --install-daemon
```

The onboard wizard installs the Gateway daemon as a launchd (macOS) or systemd
(Linux) user service. Windows requires WSL2.

### Key CLI Commands

| Command | Purpose |
|---------|---------|
| `openclaw onboard` | Interactive setup wizard |
| `openclaw gateway` | Start the gateway daemon |
| `openclaw gateway --port 18789 --verbose` | Start gateway with options |
| `openclaw doctor` | Diagnose misconfigurations |
| `openclaw config set <key> <value>` | Set configuration values |
| `openclaw message send --to <recipient> --message <text>` | Send a message |
| `openclaw agent --message <text> --thinking high` | Talk to the agent |
| `openclaw pairing approve <channel> <code>` | Approve DM pairing |
| `openclaw update --channel stable\|beta\|dev` | Switch update channel |
| `openclaw gateway --dev --reset` | Wipe dev config and restart |
| `openclaw status` | Check gateway and channel status |
| `openclaw logs` | View gateway logs |
| `openclaw sessions` | Manage active sessions |
| `openclaw plugins` | Manage plugins |
| `openclaw skills` | Manage skills |
| `openclaw sandbox` | Run sandboxed commands |

### Architecture

```
Channels (WhatsApp / Telegram / Discord / iMessage / Slack / …)
        │
        ▼
   ┌─────────┐
   │ Gateway  │  ws://127.0.0.1:18789 (loopback-only)
   └────┬────┘
        │
   ┌────┴──────────────────────────┐
   │  Pi Agent (RPC)               │
   │  CLI / TUI                    │
   │  Dashboard (browser UI)       │
   │  macOS App (SwiftUI)          │
   │  iOS / Android Nodes (WS)    │
   └───────────────────────────────┘
```

- **One Gateway per host** — it owns the WhatsApp Web session.
- Dashboard at `http://127.0.0.1:18789/`
- Config key: `gateway.mode=local`

### Supported Channels

WhatsApp (Baileys), Telegram (grammY), Discord (discord.js), iMessage (imsg
CLI), Slack, Signal, Google Chat, Microsoft Teams, BlueBubbles, Matrix, Zalo,
WebChat, Voice Call (ElevenLabs).

### Plugin Development

- Plugins live in `extensions/*` (e.g. `extensions/msteams`, `extensions/matrix`)
- Core channels: `src/telegram`, `src/discord`, `src/slack`, `src/signal`,
  `src/imessage`, `src/web`, `src/channels`, `src/routing`
- Install runs `npm install --omit=dev` in the plugin dir
- Runtime deps go in `dependencies`; put `openclaw` in `devDependencies` or
  `peerDependencies`, never use `workspace:*`

### Security Notes

- Gateway binds to loopback only — do not expose to the network
- Running an AI agent close to the OS has serious implications
- Use `openclaw doctor` to audit risky DM policies
- Review `openclaw security` for hardening options
- Credentials are stored in local config files — protect them accordingly

## References

- Documentation: https://docs.openclaw.ai
- GitHub: https://github.com/openclaw/openclaw
- FAQ: https://docs.openclaw.ai/help/faq
