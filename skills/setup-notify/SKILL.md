---
name: setup-notify
description: "Interactive wizard to configure Telegram or Discord notifications"
allowed_tools:
  - Read
  - Write
  - Bash
  - AskUserQuestion
validate_prompt: "notify-config.json saved and test message sent successfully"
---

# /setup-notify — Notification Setup Wizard

## Usage
```
/setup-notify
```

## Process

### Step 1: Platform Selection
Use **AskUserQuestion** to ask:
- **Telegram**: Requires bot token + chat ID
- **Discord**: Requires webhook URL

### Step 2: Credential Input

**Telegram**:
1. Instruct user to create bot via @BotFather
2. Ask for bot token
3. Ask for chat ID (instruct to use @userinfobot)

**Discord**:
1. Instruct user to create webhook in channel settings
2. Ask for webhook URL

### Step 3: Save Configuration
Save to `~/.taco-claude/notify-config.json`:

**Telegram**:
```json
{
  "platform": "telegram",
  "token": "{bot-token}",
  "chat_id": "{chat-id}"
}
```

**Discord**:
```json
{
  "platform": "discord",
  "webhook_url": "{webhook-url}"
}
```

Create directory if needed: `mkdir -p ~/.taco-claude`

### Step 4: Test
Send a test notification:
```bash
source scripts/notify.sh
notify "taco-claude" "Notification setup complete!"
```

Confirm with user that they received the message.

## Rules
- Never log or display full tokens in output
- Config file should be user-readable only: `chmod 600`
- If test fails, help troubleshoot before saving
