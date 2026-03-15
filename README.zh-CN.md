[English](README.md) | [中文](README.zh-CN.md)

# BotBell GitHub Action

通过 [BotBell](https://botbell.app) 将流水线通知和审批请求发送到你的手机。

## 快速开始

### 构建结果通知

```yaml
- uses: botbell/notify-action@v1
  if: always()
  with:
    token: ${{ secrets.BOTBELL_TOKEN }}
    title: "${{ job.status == 'success' && '✅ 构建通过' || '❌ 构建失败' }}"
    message: |
      #${{ github.run_number }} on ${{ github.ref_name }}
      ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
```

### 部署前审批门控

```yaml
- uses: botbell/notify-action@v1
  id: approval
  with:
    token: ${{ secrets.BOTBELL_TOKEN }}
    mode: approve
    message: "部署 #${{ github.run_number }} 到生产环境？"
    timeout: '1800'

- name: Deploy
  if: steps.approval.outputs.approved == 'true'
  run: bash deploy.sh
```

## 完整示例

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
          title: "🚀 部署审批"
          message: |
            **构建 #${{ github.run_number }}**
            分支: `${{ github.ref_name }}`
            提交: ${{ github.sha }}
          format: markdown

      - name: Deploy
        run: make deploy

      - name: Notify Success
        if: success()
        uses: botbell/notify-action@v1
        with:
          token: ${{ secrets.BOTBELL_TOKEN }}
          title: "✅ 已部署"
          message: "#${{ github.run_number }} 已上线"

      - name: Notify Failure
        if: failure()
        uses: botbell/notify-action@v1
        with:
          token: ${{ secrets.BOTBELL_TOKEN }}
          title: "❌ 部署失败"
          message: "#${{ github.run_number }} on ${{ github.ref_name }}"
```

## 输入参数

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `token` | 是 | — | BotBell Bot Token（`bt_...`） |
| `mode` | 否 | `notify` | `"notify"` 或 `"approve"` |
| `message` | 是 | — | 消息内容 |
| `title` | 否 | — | 消息标题（approve 默认："🔔 Approval Required"） |
| `url` | 否 | — | 附加 URL |
| `image_url` | 否 | — | 图片 URL |
| `format` | 否 | `text` | `"text"` 或 `"markdown"` |
| `actions` | 否 | Approve/Reject | Action 按钮 JSON 数组（approve 模式） |
| `timeout` | 否 | `1800` | 最大等待秒数（approve 模式） |
| `poll_interval` | 否 | `5` | 轮询间隔秒数（approve 模式） |

## 输出

| 输出 | 说明 |
|------|------|
| `message_id` | 发送的消息 ID |
| `delivered` | 推送是否到达设备（notify 模式） |
| `approved` | `"true"` 或 `"false"`（approve 模式） |
| `action` | 用户选择的 Action key（approve 模式） |
| `reply` | 用户回复文本（approve 模式） |

## 自定义 Actions

```yaml
- uses: botbell/notify-action@v1
  with:
    token: ${{ secrets.BOTBELL_TOKEN }}
    mode: approve
    message: "发布 v2.1.0？"
    actions: |
      [
        {"key": "approve", "label": "发布"},
        {"key": "hold", "label": "暂缓"},
        {"key": "reason", "label": "暂不发布", "type": "input", "placeholder": "原因？"}
      ]
```

## 工作原理

```
GitHub Actions 到达审批步骤
    ↓
推送通知发送到你的手机
    ↓
你看到：[批准] [拒绝] 按钮
    ↓
点击批准 → 工作流继续
点击拒绝 → 工作流失败
    ↓
无需打开浏览器
```

## 许可证

MIT
