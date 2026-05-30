# Claude Usage Widget

A lightweight macOS desktop widget that shows your Claude Code usage stats in real-time. Sits on the desktop like the macOS calendar widget — always visible, behind every regular app window.

![Claude Usage Widget](https://github.com/DarioOfek/claude-widget/raw/main/screenshot.png)

## What it shows

- **5-hour window** — % of your rolling session budget used (cost-weighted)
- **Since Thursday** — % of your weekly budget used (Claude.ai resets Thursdays)
- **Today** — turns, output tokens, cache reads
- **This month** — total turns and tokens
- **Model breakdown** — top 2 models by token usage

All data is read directly from `~/.claude/projects/**/*.jsonl` — no API key required.

> **Estimate, Claude Code only.** The % bars approximate Claude.ai's usage page,
> but they are an estimate: Claude.ai meters token-weighted, per-model consumption
> using budgets Anthropic doesn't publish, and it aggregates *all* surfaces
> (web chat, Claude in Chrome). This widget only sees Claude Code, so it reads
> somewhat lower than claude.ai. Calibrate the budgets in Settings to taste.

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
- **Settings** — pick a plan preset (Pro / Max 5x / Max 20x) or enter custom budgets

## Plan budgets

Budgets are an estimated compute cost (`$`) per window, calibrated so the bars
track Claude.ai's usage %. Tiers scale the Max-5x budget by the plan multiplier.

| Plan | 5-hour | Weekly |
|------|--------|--------|
| Pro | $160 | $3,280 |
| Max 5x | $800 | $16,400 |
| Max 20x | $3,200 | $65,600 |

## Build from source

```bash
swift build -c release        # build
make bundle                   # create ClaudeWidget.app
make install                  # install to /Applications
```

## How it works

Claude Code writes every conversation turn to JSONL files under `~/.claude/projects/`.
The widget scans those files every 60 seconds and, for each assistant response,
computes an estimated compute cost from its token usage — input, output, and cache
tokens weighted by approximate per-model list prices (Opus ≫ Sonnet ≫ Haiku). It
sums that cost into the 5-hour rolling window and the Thursday-based weekly window,
then divides by your plan budget to get the % shown. Raw turn counts (unique
`promptId` values from user entries) are still shown as context in the bars and the
Today / This-month sections.
