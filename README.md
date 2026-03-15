[English](README.md) | [中文](README.zh-CN.md)

# BotBell GitHub Action

Send pipeline notifications and approval requests to your phone via [BotBell](https://botbell.app).

## Quick Start

### Notify on build result

```yaml
- uses: botbell/notify-action@v1
  if: always()
  with:
    token: ${{ secrets.BOTBELL_TOKEN }}
    title: "${{ job.status == 'success' && '✅ Build Passed' || '❌ Build Failed' }}"
    message: |
      #${{ github.run_number }} on ${{ github.ref_name }}
      ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
```

### Approval gate before deploy

```yaml
- uses: botbell/notify-action@v1
  id: approval
  with:
    token: ${{ secrets.BOTBELL_TOKEN }}
    mode: approve
    message: "Deploy #${{ github.run_number }} to production?"
    timeout: '1800'

- name: Deploy
  if: steps.approval.outputs.approved == 'true'
  run: bash deploy.sh
```

## Full Example

```yaml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build
        run: make build

      - name: Test
        run: make test

      - name: Request Approval
        uses: botbell/notify-action@v1
        id: approval
        with:
          token: ${{ secrets.BOTBELL_TOKEN }}
          mode: approve
          title: "🚀 Deploy Approval"
          message: |
            **Build #${{ github.run_number }}**
            Branch: `${{ github.ref_name }}`
            Commit: ${{ github.sha }}
          format: markdown

      - name: Deploy
        run: make deploy

      - name: Notify Success
        if: success()
        uses: botbell/notify-action@v1
        with:
          token: ${{ secrets.BOTBELL_TOKEN }}
          title: "✅ Deployed"
          message: "#${{ github.run_number }} is live"

      - name: Notify Failure
        if: failure()
        uses: botbell/notify-action@v1
        with:
          token: ${{ secrets.BOTBELL_TOKEN }}
          title: "❌ Deploy Failed"
          message: "#${{ github.run_number }} on ${{ github.ref_name }}"
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `token` | Yes | — | BotBell Bot Token (`bt_...`) |
| `mode` | No | `notify` | `"notify"` or `"approve"` |
| `message` | Yes | — | Message body |
| `title` | No | — | Message title (approve default: "🔔 Approval Required") |
| `url` | No | — | URL to attach |
| `image_url` | No | — | Image URL |
| `format` | No | `text` | `"text"` or `"markdown"` |
| `actions` | No | Approve/Reject | JSON array of action buttons (approve mode) |
| `timeout` | No | `1800` | Max seconds to wait (approve mode) |
| `poll_interval` | No | `5` | Seconds between polls (approve mode) |

## Outputs

| Output | Description |
|--------|-------------|
| `message_id` | ID of the sent message |
| `delivered` | Whether push reached a device (notify mode) |
| `approved` | `"true"` or `"false"` (approve mode) |
| `action` | Action key selected by user (approve mode) |
| `reply` | User reply text (approve mode) |

## Custom Actions

```yaml
- uses: botbell/notify-action@v1
  with:
    token: ${{ secrets.BOTBELL_TOKEN }}
    mode: approve
    message: "Release v2.1.0?"
    actions: |
      [
        {"key": "approve", "label": "Ship it"},
        {"key": "hold", "label": "Hold off"},
        {"key": "reason", "label": "Not now", "type": "input", "placeholder": "Why?"}
      ]
```

## How It Works

```
GitHub Actions reaches approval step
    ↓
Push notification sent to your phone
    ↓
You see: [Approve] [Reject] buttons
    ↓
Tap Approve → Workflow continues
Tap Reject  → Workflow fails
    ↓
No browser needed
```

## License

MIT
