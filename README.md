# TickTick CLI

A command-line interface for TickTick task management using OAuth2 authentication. Built for macOS with built-in dependencies (python3 and curl).

## Features

- ✅ **Create and update tasks** with priority, due dates, tags, and descriptions
- ✅ **Complete tasks** by name or ID
- ✅ **List tasks** from specific projects or all projects
- ✅ **Create and update projects** (lists) with custom colors
- ✅ **Direct ID updates** with `--id` for tasks and lists (great for AI agents)
- ✅ **Inbox support** - access your TickTick Inbox directly
- ✅ **Smart timezone handling** - automatically detects PST/PDT based on date
- ✅ **Case-insensitive priority** - "high", "HIGH", "HiGh" all work
- ✅ **Name-based operations** - use project and task names instead of IDs
- ✅ **Multiple output formats** - human-readable, JSON, JSON-pretty
- ✅ **Terminal table display** - full-width tables with colored project indicators
- ✅ **Comprehensive error handling** with helpful messages
- ✅ **Markdown descriptions with newlines** via `--content` (CLI-friendly for AI agents)

## Prerequisites

- **macOS** (uses built-in python3 and curl)
- **TickTick account**
- **TickTick Developer App** (free registration required)

## Installation

### 1. Register TickTick Developer App

1. Visit [developer.ticktick.com](https://developer.ticktick.com)
2. Create a new app to get your `CLIENT_ID` and `CLIENT_SECRET`
3. Set redirect URI to: `http://localhost:8080`

### 2. Download and Setup

```bash
# Download the script
curl -O https://raw.githubusercontent.com/yourusername/ticktick-cli/main/ticktick.sh

# Make it executable
chmod +x ticktick.sh

# Edit the script to add your credentials
nano ticktick.sh
```

### 3. Add Your Credentials

Edit the script and add your TickTick app credentials:

```bash
CLIENT_ID="your_client_id_here"
CLIENT_SECRET="your_client_secret_here"
ACCESS_TOKEN=""
REFRESH_TOKEN=""
TOKEN_EXPIRY=""
```

### 4. Initial Setup (Credentials & OAuth)

```bash
# The script uses a single config file at ~/.config/ticktick-cli
# (chmod 600 recommended). You can set credentials in one of two ways:

# Option A: First run prompts
# If the config file is missing, running the script will prompt for CLIENT_ID
# and CLIENT_SECRET and create ~/.config/ticktick-cli for you.
./ticktick.sh

# Option B: Pre-create the config file yourself
cat > ~/.config/ticktick-cli <<'EOF'
CLIENT_ID="your_client_id_here"
CLIENT_SECRET="your_client_secret_here"
ACCESS_TOKEN=""
REFRESH_TOKEN=""
TOKEN_EXPIRY=""
EOF
chmod 600 ~/.config/ticktick-cli

# Then run the script to complete the OAuth flow
./ticktick.sh

# After successful auth, ACCESS_TOKEN/REFRESH_TOKEN/TOKEN_EXPIRY
# are saved back to ~/.config/ticktick-cli automatically.
```

### 5. Create Alias (Optional)

Add to your `~/.zshrc` or `~/.bash_profile`:

```bash
alias tt='/path/to/your/ticktick.sh'
```

## Output Formats

All commands support the following output formats:

| Format | Flag | Description |
|--------|------|-------------|
| **Human-readable** | *(default)* | Easy-to-read text format for manual use |
| **JSON** | `--json` | Compact JSON for scripting and AI agents |
| **JSON-pretty** | `--json-pretty` | Formatted JSON with indentation |

Note: Table output has been removed. Use JSON for scripting and automation.

## Usage

### Commands Overview

| Command | Description |
|---------|-------------|
| `task` | Create or update tasks |
| `complete` | Mark tasks as complete |
| `tasks` | List tasks from projects |
| `list` | Create or update projects |
| `lists` | Show all projects |

### Task Management

#### Create Tasks

```bash
# Simple task
./ticktick.sh task "Buy groceries" --list "Home"

# Full task with all options
./ticktick.sh task "Deploy app" --list "Work" \
  --content "Deploy to production server" \
  --priority "High" \
  --due "2025-01-15T14:30:00" \
  --tag "Urgent,Deploy"

# Task with multiple tags
./ticktick.sh task "Review PR" --list "Work" --tag "Code Review,High Priority,Bug"

# Using explicit --name flag
./ticktick.sh task --name "Call dentist" --list "Home" --priority "Low"

# UTC time with Z suffix
./ticktick.sh task "Meeting" --list "Work" --due "2025-01-15T14:30:00Z"

# Local time (auto-converts to PST/PDT)
./ticktick.sh task "Lunch" --list "Home" --due "2025-01-15T12:00:00"

# Output formats
./ticktick.sh task "Test task" --list "Work" --json
./ticktick.sh task "Test task" --list "Work" --json-pretty
./ticktick.sh task "Test task" --list "Work" --table
#### Multiline Markdown Descriptions

You can include newlines and Markdown in `--content`:

```bash
# Bash/Zsh (ANSI C-quoted)
./ticktick.sh task "Write docs" --list "Work" \
  --content $'First line\n\n- Bullet 1\n- Bullet 2'

# Using a variable
DESC=$'Intro line\n\nSecond paragraph'
./ticktick.sh task "Title" --content "$DESC"

# POSIX-safe with printf
DESC="$(printf 'First line\n\nSecond paragraph')"
./ticktick.sh task "Title" --content "$DESC"
```
```

#### Update Tasks

```bash
# Update by task name (searches in specific list)
./ticktick.sh task "Fix bug" --update --priority "Medium" --list "Work"

# Update by task name (searches all lists)
./ticktick.sh task "Fix bug" --update --priority "High"

# Update by task ID
./ticktick.sh task "1234567890abcdef12345678" --update --priority "Low"

# Update using --id (bypasses name search and implies --update)
./ticktick.sh task --id 1234567890abcdef12345678 --priority "High"

# Move a task to another list when ID is known
./ticktick.sh task --id 1234567890abcdef12345678 --list "Target List"

# Update multiple fields
./ticktick.sh task "Deploy app" --update --list "Work" \
  --description "Updated description" \
  --priority "None" \
  --due "2025-01-20T10:00:00"
```

#### Complete Tasks

```bash
# Complete by task name
./ticktick.sh complete --task "Fix bug" --list "Work"

# Complete by task ID
./ticktick.sh complete --task "1234567890abcdef12345678" --list "Work"

# Complete Inbox task
./ticktick.sh complete --task "Inbox task" --list "Inbox"

# Output formats
./ticktick.sh complete --task "Fix bug" --list "Work" --json
./ticktick.sh complete --task "Fix bug" --list "Work" --table
```

### Task Listing

#### List Tasks

```bash
# List tasks from specific project
./ticktick.sh tasks --list "Work"

# List Inbox tasks (special case)
./ticktick.sh tasks --list "Inbox"

# List all tasks from all projects
./ticktick.sh tasks

# Filter by status
./ticktick.sh tasks --list "Work" --status completed
./ticktick.sh tasks --list "Home" --status pending

# Output formats
./ticktick.sh tasks --list "Work" --json
./ticktick.sh tasks --list "Work" --json-pretty
./ticktick.sh tasks --list "Work" --table
```

### Project Management

#### Create Projects

```bash
# Simple project creation
./ticktick.sh list "New Project"

# With explicit --name flag
./ticktick.sh list --name "Work Tasks"

# With color
./ticktick.sh list "Personal" --color "#FF5733"

# Both name and color
./ticktick.sh list --name "Shopping" --color "#00FF00"
```

#### Update Projects

```bash
# Update color
./ticktick.sh list "Work" --update --color "#FF0000"

# Update by project ID
./ticktick.sh list "1234567890abcdef12345678" --update --color "#0000FF"

# Update name
./ticktick.sh list "Old Name" --update --name "New Name"

# Rename using --id and --name (bypasses name search)
./ticktick.sh list --id 1234567890abcdef12345678 --name "New List Name" --update
```

#### List All Projects

```bash
# Show all projects (Inbox appears first)
./ticktick.sh lists

# Output formats
./ticktick.sh lists --json
./ticktick.sh lists --json-pretty
./ticktick.sh lists --table
```

## Priority Values

Priority values are case-insensitive:

| Priority | Value | Integer |
|----------|-------|---------|
| None | Default | 0 |
| Low | `--priority "Low"` | 1 |
| Medium | `--priority "Medium"` | 3 |
| High | `--priority "High"` | 5 |

**Examples:**
```bash
--priority "high"    # Works
--priority "HIGH"    # Works  
--priority "HiGh"    # Works
```

## Date and Time

### Date Formats

- **Local time**: `2025-01-15T14:30:00` (auto-converts to PST/PDT)
- **UTC time**: `2025-01-15T14:30:00Z` (keeps as UTC)

### Timezone Handling

The script automatically detects your timezone:
- **March 8 - November 1**: Uses PDT (UTC-7)
- **November 2 - March 7**: Uses PST (UTC-8)

## Special Features

### Inbox Support

TickTick's Inbox is a special project that contains tasks without a projectId:

```bash
# List Inbox tasks
./ticktick.sh tasks --list "Inbox"

# Complete Inbox task
./ticktick.sh complete --task "Inbox task" --list "Inbox"

# Inbox appears first in project list
./ticktick.sh lists
```

### Name Matching

The script uses intelligent name matching:
- **Case-insensitive** comparison
- **Strips special characters** (keeps letters, numbers, spaces, underscores, hyphens)
- **Trims whitespace**
- **Works with both names and IDs**

## Examples

### Workflow Examples

```bash
# Create a new project
./ticktick.sh list "Weekend Tasks" --color "#FF6B6B"

# Add tasks to the project
./ticktick.sh task "Clean garage" --list "Weekend Tasks" --priority "Medium"
./ticktick.sh task "Grocery shopping" --list "Weekend Tasks" --due "2025-01-18T10:00:00"

# List tasks
./ticktick.sh tasks --list "Weekend Tasks"

# Complete a task
./ticktick.sh complete --task "Clean garage" --list "Weekend Tasks"

# Update task priority
./ticktick.sh task "Grocery shopping" --update --priority "High" --list "Weekend Tasks"
```

### Quick Capture

```bash
# Quick task to Inbox (no --list needed)
./ticktick.sh task "Remember to call mom"

# Quick task with priority
./ticktick.sh task "Urgent email" --priority "High"
```

## Error Handling

The script provides helpful error messages:

```bash
# Missing required parameters
./ticktick.sh complete --task "Fix bug"
# Error: List name is required (use --list <name>)

# Invalid priority
./ticktick.sh task "Test" --priority "Invalid"
# Error: Invalid priority 'Invalid'. Use: None, Low, Medium, High

# Invalid date format
./ticktick.sh task "Test" --due "invalid-date"
# Error: Invalid due date format. Use: yyyy-MM-dd'T'HH:mm:ss (local time) or yyyy-MM-dd'T'HH:mm:ssZ (UTC)
```

## Troubleshooting

### Common Issues

1. **"CLIENT_ID and CLIENT_SECRET must be set"**
   - Add your credentials to the script configuration section

2. **"List 'ProjectName' not found"**
   - Check spelling and case sensitivity
   - Use `./ticktick.sh lists` to see available projects

3. **"Task 'TaskName' not found"**
   - Verify the task exists in the specified project
   - Check spelling and case sensitivity

4. **OAuth errors**
   - Ensure redirect URI is set to `http://localhost:8080` in your TickTick app
   - Check that CLIENT_ID and CLIENT_SECRET are correct

### Getting Help

```bash
# Show usage information
./ticktick.sh help

# Show all available commands
./ticktick.sh
```

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

This project is open source. Please check the LICENSE file for details.

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review the TickTick API documentation
3. Open an issue on GitHub

---

**Note**: This script is designed for macOS and uses built-in tools (python3 and curl). It may work on other Unix-like systems with minor modifications.
