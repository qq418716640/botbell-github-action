#!/usr/bin/env bash
set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────

API_BASE="${BOTBELL_API_BASE:-https://api.botbell.app/v1}"
TOKEN="${BOTBELL_TOKEN:?BotBell token is required}"
MODE="${BOTBELL_MODE:-notify}"
MESSAGE="${BOTBELL_MESSAGE:?Message is required}"
TIMEOUT="${BOTBELL_TIMEOUT:-1800}"
POLL_INTERVAL="${BOTBELL_POLL_INTERVAL:-5}"

# ── Dependency check ─────────────────────────────────────────────────

command -v jq >/dev/null 2>&1 || { echo "::error::BotBell: jq is required but not installed"; exit 1; }

# ── Helpers ──────────────────────────────────────────────────────────

build_body() {
    local body
    body=$(jq -n --arg msg "$MESSAGE" '{message: $msg}')

    [ -n "${BOTBELL_TITLE:-}" ]     && body=$(echo "$body" | jq --arg v "$BOTBELL_TITLE" '. + {title: $v}')
    [ -n "${BOTBELL_URL:-}" ]       && body=$(echo "$body" | jq --arg v "$BOTBELL_URL" '. + {url: $v}')
    [ -n "${BOTBELL_IMAGE_URL:-}" ] && body=$(echo "$body" | jq --arg v "$BOTBELL_IMAGE_URL" '. + {image_url: $v}')
    [ -n "${BOTBELL_FORMAT:-}" ]    && body=$(echo "$body" | jq --arg v "$BOTBELL_FORMAT" '. + {format: $v}')

    echo "$body"
}

send_push() {
    local body="$1"
    local response
    local http_code

    response=$(curl -s -w "\n%{http_code}" -X POST "${API_BASE}/push/${TOKEN}" \
        -H "Content-Type: application/json" \
        -H "User-Agent: botbell-github-action/0.1.0" \
        -d "$body")

    http_code=$(echo "$response" | tail -1)
    local resp_body
    resp_body=$(echo "$response" | sed '$d')

    if [ "$http_code" -ge 400 ]; then
        local err_msg
        err_msg=$(echo "$resp_body" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "$resp_body")
        echo "::error::BotBell API error (HTTP ${http_code}): ${err_msg}"
        exit 1
    fi

    echo "$resp_body"
}

poll_replies() {
    local response http_code
    response=$(curl -s -w "\n%{http_code}" -X GET "${API_BASE}/messages/poll" \
        -H "X-Bot-Token: ${TOKEN}" \
        -H "User-Agent: botbell-github-action/0.1.0")

    http_code=$(echo "$response" | tail -1)
    local resp_body
    resp_body=$(echo "$response" | sed '$d')

    if [ "$http_code" -ge 400 ]; then
        local err_msg
        err_msg=$(echo "$resp_body" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "$resp_body")
        echo "::error::BotBell: Poll failed (HTTP ${http_code}): ${err_msg}"
        exit 1
    fi

    echo "$resp_body"
}

# ── Notify Mode ──────────────────────────────────────────────────────

do_notify() {
    local body
    body=$(build_body)
    body=$(echo "$body" | jq '. + {reply_mode: "none"}')

    local resp
    resp=$(send_push "$body")

    local msg_id delivered
    msg_id=$(echo "$resp" | jq -r '.data.message_id')
    delivered=$(echo "$resp" | jq -r '.data.delivered')

    echo "message_id=${msg_id}" >> "$GITHUB_OUTPUT"
    echo "delivered=${delivered}" >> "$GITHUB_OUTPUT"
    echo "BotBell: Notification sent (${msg_id}, delivered: ${delivered})"
}

# ── Approve Mode ─────────────────────────────────────────────────────

do_approve() {
    local body
    body=$(build_body)

    # Set title default
    if [ -z "${BOTBELL_TITLE:-}" ]; then
        body=$(echo "$body" | jq '. + {title: "🔔 Approval Required"}')
    fi

    body=$(echo "$body" | jq '. + {reply_mode: "actions_only"}')

    # Set actions
    if [ -n "${BOTBELL_ACTIONS:-}" ]; then
        body=$(echo "$body" | jq --argjson actions "$BOTBELL_ACTIONS" '. + {actions: $actions}')
    else
        body=$(echo "$body" | jq '. + {actions: [{"key":"approve","label":"Approve"},{"key":"reject","label":"Reject"}]}')
    fi

    local resp
    resp=$(send_push "$body")

    local msg_id
    msg_id=$(echo "$resp" | jq -r '.data.message_id')
    echo "BotBell: Approval request sent (${msg_id}), waiting up to ${TIMEOUT}s..."

    # Poll for reply
    local deadline
    deadline=$(( $(date +%s) + TIMEOUT ))

    while [ "$(date +%s)" -lt "$deadline" ]; do
        sleep "$POLL_INTERVAL"

        local poll_resp
        poll_resp=$(poll_replies)

        local match
        match=$(echo "$poll_resp" | jq -r --arg mid "$msg_id" \
            '.data.messages[]? | select(.reply_to == $mid) | @json' 2>/dev/null | head -1)

        if [ -n "$match" ]; then
            local action content
            action=$(echo "$match" | jq -r '.action // ""')
            content=$(echo "$match" | jq -r '.content // ""')

            echo "message_id=${msg_id}" >> "$GITHUB_OUTPUT"
            echo "action=${action}" >> "$GITHUB_OUTPUT"
            echo "reply=${content}" >> "$GITHUB_OUTPUT"

            if [ "$action" = "approve" ]; then
                echo "approved=true" >> "$GITHUB_OUTPUT"
                echo "BotBell: Approved!"
                return 0
            else
                local reason="${content:-$action}"
                echo "approved=false" >> "$GITHUB_OUTPUT"
                echo "::error::BotBell: Rejected — ${reason}"
                exit 1
            fi
        fi
    done

    echo "approved=false" >> "$GITHUB_OUTPUT"
    echo "::error::BotBell: Approval timed out after ${TIMEOUT}s"
    exit 1
}

# ── Main ─────────────────────────────────────────────────────────────

case "$MODE" in
    notify)  do_notify ;;
    approve) do_approve ;;
    *)
        echo "::error::BotBell: Unknown mode '${MODE}'. Use 'notify' or 'approve'."
        exit 1
        ;;
esac
