# Claude Usage Widget

A lightweight macOS desktop widget that shows your Claude Code usage stats in real-time. Sits on the desktop like the macOS calendar widget — always visible, behind every regular app window.

![Claude Usage Widget](https://github.com/DarioOfek/claude-widget/raw/main/screenshot.png)

## What it shows

- **5-hour window** — turns used vs. your plan's rolling limit, with % bar
- **Since Thursday** — weekly turns vs. limit (Claude.ai resets Thursdays)
- **Today** — turns, output tokens, cache reads
- **This month** — total turns and tokens
- **Model breakdown** — top 2 models by token usage

All data is read directly from `~/.claude/projects/**/*.jsonl` — no API key required.

## Install

Requires macOS 13+ and Swift (ships with Xcode).

```bash
git clone https://github.com/DarioOfek/claude-widget.git
cd claude-widget
make install
open /Applications/ClaudeWidget.app
```

To launch at login: **System Settings → General → Login Items** → add `ClaudeWidget.app`.

## Usage

- **Drag** anywhere by clicking the background
- **Right-click** → Refresh / Settings / Quit
- **Settings** — pick a plan preset (Pro / Max 5x / Max 20x) or enter custom limits

## Plan limits

| Plan | 5-hour | Weekly |
|------|--------|--------|
| Pro | 45 | 250 |
| Max 5x | 225 | 2,450 |
| Max 20x | 900 | 5,000 |

## Build from source

```bash
swift build -c release        # build
make bundle                   # create ClaudeWidget.app
make install                  # install to /Applications
```

## How it works

Claude Code writes every conversation turn to JSONL files under `~/.claude/projects/`. The widget scans those files every 60 seconds, counts unique `promptId` values from user entries (matching how Claude.ai counts turns), and buckets them into the 5-hour rolling window and the Thursday-based weekly window.
