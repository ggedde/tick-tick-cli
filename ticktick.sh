#!/bin/bash

# =============================================================================
# TICKTICK CLI SCRIPT - AI AGENT DOCUMENTATION
# =============================================================================
#
# OVERVIEW:
#   Command-line interface for TickTick task management using OAuth2 authentication
#   Target OS: macOS only (uses built-in python3 and curl)
#   Dependencies: python3, curl (both macOS built-in)
#
# AUTHENTICATION & CONFIGURATION:
#   - Uses OAuth2 authorization code flow
#   - Credentials stored in-script (CLIENT_ID, CLIENT_SECRET, ACCESS_TOKEN)
#   - Tokens auto-refresh on 401 errors
#   - Initial setup: Register app at developer.ticktick.com, add credentials below
#
# COMMAND REFERENCE:
#
#   task - Create/update tasks
#     Flags: --name (-n), --content (-c), --list (-l), --priority (-p), --due (-d), --tag (-t), --update (-u), --id (-i)
#     Output: --json, --json-pretty (default: human-readable)
#     Priority: None, Low, Medium, High (case-insensitive) → 0,1,3,5
#     Due date: yyyy-MM-dd'T'HH:mm:ss (local) or yyyy-MM-dd'T'HH:mm:ssZ (UTC)
#     Timezone: Auto-detected PST/PDT based on date (Mar8-Nov1=PDT, else=PST)
#     Update: Search by ID (24-char hex) or title (with/without --list)
#     Description: Supports Markdown and newlines. In bash/zsh use ANSI C-quoted strings
#       with \n for newlines, e.g.:
#       task "Title" --description $'First line\n\n- Bullet 1\n- Bullet 2'
#       POSIX-safe: DESC="$(printf 'First line\n\nSecond paragraph')"; task "Title" --description "$DESC"
#
#   complete - Mark task complete
#     Positional: [name] (multi-word unquoted names supported)
#     Flags: --name/-n (name), --id/-i (task ID), --list/-l (optional), --tag/-t (add after completion)
#     Output: --json/-j, --json-pretty/-jp (default: human-readable)
#     Special: --list "Inbox" or --list "inbox" (case-insensitive)
#
#   tasks - List tasks
#     Flags: --list (optional, shows all if omitted), --status
#     Output: --json, --json-pretty (default: human-readable)
#     Special: --list "Inbox" or --list "inbox" (case-insensitive)
#     Table columns: Task, Priority, Due, Status, Tags
#     Shows: ID, Title, Description, List, Priority, Status, Due Date
#
#   list - Create/update project
#     Flags: --name (-n), --color (hex), --update (-u), --id (-i)
#     Output: --json, --json-pretty (default: human-readable)
#     Name matching: Case-insensitive, normalized (strips non-alphanumeric except _-)
#
#   lists - Show all projects
#     Output: --json, --json-pretty, --table (default: human-readable)
#     Table columns: List (with colored dots)
#     Displays: Name, ID, Color, View Mode, Kind
#     Special: Inbox appears first with task count
#
# KEY IMPLEMENTATION DETAILS:
#
#   Name Matching Logic:
#     - Strips non-alphanumeric (except spaces, underscores, hyphens)
#     - Trims whitespace, case-insensitive comparison
#     - Used for project and task name resolution
#
#   ID Detection:
#     - 24-character hex string = ID
#     - Otherwise = name (searches by normalized name)
#
#   API Endpoints:
#     GET  /open/v1/project                           # List projects
#     POST /open/v1/project                           # Create project
#     POST /open/v1/project/{projectId}               # Update project
#     GET  /open/v1/project/{projectId}/data          # Get tasks in project
#     GET  /open/v1/project/inbox/data                # Get Inbox tasks (special)
#     POST /open/v1/task                              # Create task
#     POST /open/v1/task/{taskId}                     # Update task
#     POST /open/v1/project/{projectId}/task/{taskId}/complete  # Complete task
#
#   Priority Mapping: 0=None, 1=Low, 3=Medium, 5=High
#
#   Timezone Handling:
#     - Dates without 'Z' = local time (PST/PDT)
#     - DST logic: Mar 8 - Nov 1 = PDT (UTC-7), else PST (UTC-8)
#     - Converts to UTC for storage, API stores as "America/Los_Angeles"
#
#   Token Management:
#     - ACCESS_TOKEN stored in script (line 29)
#     - Auto-refreshes on 401 errors, updates script file with new token
#
# COMPREHENSIVE USAGE EXAMPLES:
#
#   TASK - Create Tasks:
#     task "Buy groceries" --list "Home"
#     task "Fix bug in login" --list "Work"
#     task "Deploy app" --list "Work" --description "Deploy to production" --priority "High" --due "2025-01-15T14:30:00" --tag "Urgent,Deploy"
#     task "Review PR" --list "Work" --tag "Code Review,High Priority,Bug"
#     # Multiline Markdown description (bash/zsh)
#     task "Write docs" --list "Work" --description $'Intro line\n\n- Step 1\n- Step 2'
#     task --title "Call dentist" --list "Home" --priority "Low"
#     task "Meeting" --list "Work" --due "2025-01-15T14:30:00Z"
#     task "Lunch" --list "Home" --due "2025-01-15T12:00:00"
#     task "Make Something Awesome folk's" --list "Work"
#     task "Test task" --list "Work" --json
#     task "Test task" --list "Work" --json-pretty
#     # table output removed
#
#   TASK - Update Tasks:
#     task "Fix bug" --update --priority "Medium" --list "Work"
#     task "Fix bug" --update --priority "High"
#     task "1234567890abcdef12345678" --update --priority "Low"
#     task "Deploy app" --update --list "Work" --content "Updated description" --priority "None" --due "2025-01-20T10:00:00"
#     task "Review PR" --update --list "Work" --tag "Done,Reviewed"
#     task "Old task" --update --list "Home" --priority "None"
#     # Update using --id (bypasses name search and implies --update)
#     task --id 1234567890abcdef12345678 --priority "High"
#     # Move a task to another list when ID is known
#     task --id 1234567890abcdef12345678 --list "Target List"
#
#   COMPLETE:
#     complete Fix bug --list Work
#     complete --id 1234567890abcdef12345678 --tag Done
#     complete "Make Something Awesome folk's" --list Work
#     complete Inbox task --list Inbox
#
#   TASKS - List Tasks:
#     tasks --list "Work"
#     tasks --list "Inbox"
#     tasks
#     tasks --list "Work" --status completed
#     tasks --list "Home" --status pending
#     tasks
#     tasks --list "Work" --json
#     tasks --list "Work" --json-pretty
#     # table output removed
#
#   LIST - Create Projects:
#     list "New Project"
#     list --name "Work Tasks"
#     list "Personal" --color "#FF5733"
#     list --name "Shopping" --color "#00FF00"
#
#   LIST - Update Projects:
#     list "Work" --update --color "#FF0000"
#     list "1234567890abcdef12345678" --update --color "#0000FF"
#     list "Old Name" --update --name "New Name"
#     list "Project" --update --name "Updated Project" --color "#FFFF00"
#     # Rename using --id and --title (bypasses name search)
#     list --id 1234567890abcdef12345678 --name "New List Name" --update
#
#   LISTS:
#     lists
#     lists --json
#     lists --json-pretty
#     # table output removed
#
#   Priority Values (case-insensitive):
#     --priority "None"    # 0 - Default
#     --priority "Low"     # 1
#     --priority "Medium"  # 3
#     --priority "High"    # 5
#     --priority "high"    # Works
#     --priority "HIGH"    # Works
#     --priority "HiGh"    # Works
#
# SCRIPT STRUCTURE REFERENCE:
#   - task() - line ~280
#   - complete_task() - line ~670
#   - tasks() - line ~750
#   - create_or_check_list() - line ~980
#   - lists() - line ~1170
#   - get_project_id() - line ~180
#   - get_task_id_from_project() - line ~230
#
# SETUP INSTRUCTIONS:
#   1. Register app at developer.ticktick.com to get CLIENT_ID and CLIENT_SECRET
#   2. Add CLIENT_ID and CLIENT_SECRET to this script below
#   3. chmod +x path/to/your/script.sh
#   4. Run the script once to complete OAuth flow
#   5. alias tt='/path/to/your/script.sh'
#
# Note: Strings with spaces or special characters must be quoted

# =============================================================================
# CREDENTIALS - Loaded from a single config file or environment
# =============================================================================

# Single config file path (chmod 600 recommended)
CONFIG_FILE="${HOME}/.config/ticktick-cli"

# Load config file if present
load_config_file() {
	[[ -f "${CONFIG_FILE}" ]] || return 0
	# shellcheck disable=SC1090
	source "${CONFIG_FILE}"
}

# Persist current credentials/tokens to CONFIG_FILE (tokens change over time)
save_config_file() {
	mkdir -p "${HOME}/.config" 2>/dev/null || true
	umask 077
	cat > "${CONFIG_FILE}.tmp" <<EOF
CLIENT_ID="${CLIENT_ID:-}"
CLIENT_SECRET="${CLIENT_SECRET:-}"
ACCESS_TOKEN="${ACCESS_TOKEN:-}"
REFRESH_TOKEN="${REFRESH_TOKEN:-}"
TOKEN_EXPIRY="${TOKEN_EXPIRY:-}"
EOF
	mv "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"
}

# 1) Load from file
load_config_file

# 2) Env overrides (CI-friendly)
CLIENT_ID="${CLIENT_ID:-}"
CLIENT_SECRET="${CLIENT_SECRET:-}"
ACCESS_TOKEN="${ACCESS_TOKEN:-}"
REFRESH_TOKEN="${REFRESH_TOKEN:-}"
TOKEN_EXPIRY="${TOKEN_EXPIRY:-}"

# 3) First-run interactive setup: prompt for CLIENT_ID/CLIENT_SECRET and create config
if [[ ! -f "${CONFIG_FILE}" && ( -z "${CLIENT_ID}" || -z "${CLIENT_SECRET}" ) ]]; then
    echo "=== TickTick CLI - First-time Setup ==="
    echo "No config found at ${CONFIG_FILE}. Let's create it now."
    echo "Register an app at https://developer.ticktick.com to obtain CLIENT_ID and CLIENT_SECRET."
    echo ""
    while [[ -z "${CLIENT_ID}" ]]; do
        read -p "Enter CLIENT_ID: " CLIENT_ID
    done
    while [[ -z "${CLIENT_SECRET}" ]]; do
        read -p "Enter CLIENT_SECRET: " CLIENT_SECRET
        echo ""
    done
    # Save minimal config (tokens blank on first run)
    ACCESS_TOKEN=""
    REFRESH_TOKEN=""
    TOKEN_EXPIRY=""
    save_config_file
    echo "Saved credentials to ${CONFIG_FILE} (permissions restricted)."
fi

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Check if python3 is available (required for JSON parsing)
check_dependencies() {
    if ! command -v python3 &> /dev/null; then
        echo "Error: python3 is required but not found. Please install Python 3."
        exit 1
    fi
}

# Get terminal width
get_terminal_width() {
    local cols
    # 1) Prefer stty (actual TTY size)
    cols=$(stty size 2>/dev/null | awk '{print $2}')
    if [[ -n "$cols" && "$cols" -gt 0 ]]; then echo "$cols"; return; fi
    if [[ -t 1 || -t 0 ]]; then
        if [[ -r /dev/tty ]]; then
            cols=$(stty -f /dev/tty size 2>/dev/null | awk '{print $2}')
            if [[ -n "$cols" && "$cols" -gt 0 ]]; then echo "$cols"; return; fi
            cols=$(stty size < /dev/tty 2>/dev/null | awk '{print $2}')
            if [[ -n "$cols" && "$cols" -gt 0 ]]; then echo "$cols"; return; fi
        fi
    fi
    # 2) tput with COLUMNS unset, try binding to tty if available
    cols=$( (unset COLUMNS; tput cols) 2>/dev/null )
    if [[ -n "$cols" && "$cols" -gt 0 ]]; then echo "$cols"; return; fi
    # Avoid redirecting to /dev/tty unless we have a TTY
    if [[ -t 1 || -t 0 ]]; then
        if [[ -r /dev/tty ]]; then
            cols=$( (unset COLUMNS; tput cols) 2>/dev/null < /dev/tty )
            if [[ -n "$cols" && "$cols" -gt 0 ]]; then echo "$cols"; return; fi
        fi
    fi
    # 3) Environment variable as a last resort
    if [[ -n "$COLUMNS" && "$COLUMNS" -gt 0 ]]; then echo "$COLUMNS"; return; fi
    # Fallback
    echo "80"
}

# Python helper functions for output formatting
PYTHON_HELPERS='
import re
from datetime import datetime

def hex_to_256_color(hex_color):
    """Convert hex color to closest xterm-256 color code"""
    if not hex_color or hex_color == "null":
        return 7  # white/default
    
    # Remove # if present
    hex_color = hex_color.lstrip("#")
    
    # Convert hex to RGB
    r = int(hex_color[0:2], 16)
    g = int(hex_color[2:4], 16)
    b = int(hex_color[4:6], 16)
    
    # Quick grayscale check
    if abs(r - g) < 10 and abs(g - b) < 10 and abs(r - b) < 10:
        gray = (r + g + b) // 3
        gray_index = round(gray / 255 * 23)
        return 232 + gray_index
    
    # Convert to 6x6x6 color cube (16-231)
    r_index = round(r / 255 * 5)
    g_index = round(g / 255 * 5)
    b_index = round(b / 255 * 5)
    
    return 16 + (36 * r_index) + (6 * g_index) + b_index

def colored_circle(hex_color):
    """Return colored circle character"""
    color_code = hex_to_256_color(hex_color)
    return f"\033[38;5;{color_code}m●\033[0m"

def strip_emojis(text):
    """Remove emojis from text"""
    # Remove emoji characters
    emoji_pattern = re.compile("["
        u"\U0001F600-\U0001F64F"  # emoticons
        u"\U0001F300-\U0001F5FF"  # symbols & pictographs
        u"\U0001F680-\U0001F6FF"  # transport & map symbols
        u"\U0001F1E0-\U0001F1FF"  # flags
        u"\U00002702-\U000027B0"
        u"\U000024C2-\U0001F251"
        "]+", flags=re.UNICODE)
    return emoji_pattern.sub("", text).strip()

def format_simple_table(message, term_width):
    """Format a simple response message in a table"""
    inner_width = term_width - 4  # Account for borders and padding
    
    # Split message into lines and wrap if needed
    lines = []
    for line in message.split("\n"):
        if len(line) <= inner_width:
            lines.append(line.ljust(inner_width))
        else:
            # Wrap long lines
            while line:
                lines.append(line[:inner_width].ljust(inner_width))
                line = line[inner_width:]
    
    # Build table
    top = "┌" + "─" * (inner_width + 2) + "┐"
    header = "│ " + "Response".ljust(inner_width) + " │"
    separator = "├" + "─" * (inner_width + 2) + "┤"
    bottom = "└" + "─" * (inner_width + 2) + "┘"
    
    print(top)
    print(header)
    print(separator)
    for line in lines:
        print("│ " + line + " │")
    print(bottom)
'

# Parse JSON using python3 (macOS built-in)
parse_json() {
    local json="$1"
    local key="$2"
    python3 -c "
import json, sys
try:
    data = json.loads(sys.argv[1])
    print(data.get(sys.argv[2], ''))
except:
    print('')
" "$json" "$key"
}

# Extract JSON value by key
get_json_value() {
    local json="$1"
    local key="$2"
    python3 -c "
import json, sys
try:
    data = json.loads(sys.argv[1])
    if sys.argv[2] in data:
        print(data[sys.argv[2]])
    else:
        print('')
except:
    print('')
" "$json" "$key"
}

# Check if current access token is valid
check_token() {
    if [[ -z "$ACCESS_TOKEN" ]]; then
        return 1
    fi
    
    # Check if token is expired
    if [[ -n "$TOKEN_EXPIRY" ]]; then
        current_time=$(date +%s)
        if [[ $current_time -ge $TOKEN_EXPIRY ]]; then
            return 1
        fi
    fi
    
    return 0
}

# Refresh access token using refresh token
refresh_access_token() {
    if [[ -z "$REFRESH_TOKEN" ]]; then
        echo "Error: No refresh token available. Please re-authenticate."
        return 1
    fi
    
    local response=$(curl -s -X POST "https://ticktick.com/oauth/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=refresh_token" \
        -d "refresh_token=$REFRESH_TOKEN" \
        -d "client_id=$CLIENT_ID" \
        -d "client_secret=$CLIENT_SECRET")
    
    local new_access_token=$(get_json_value "$response" "access_token")
    local new_refresh_token=$(get_json_value "$response" "refresh_token")
    local expires_in=$(get_json_value "$response" "expires_in")
    
    if [[ -n "$new_access_token" ]]; then
        ACCESS_TOKEN="$new_access_token"
        if [[ -n "$new_refresh_token" ]]; then
            REFRESH_TOKEN="$new_refresh_token"
        fi
        
        # Calculate expiry time (expires_in is in seconds)
        if [[ -n "$expires_in" ]]; then
            TOKEN_EXPIRY=$(($(date +%s) + expires_in - 300))  # 5 minutes buffer
        fi
        
        # Save updated tokens to config file
        save_config_file
        return 0
    else
        echo "Error: Failed to refresh access token"
        return 1
    fi
}

# Removed self-editing token persistence; now using save_config_file()

# Initial OAuth2 authentication flow
initial_auth() {
    echo "=== TickTick OAuth2 Setup ==="
    echo "No access token found. Starting OAuth2 flow..."
    echo ""
    
    # Generate authorization URL
    local auth_url="https://ticktick.com/oauth/authorize?response_type=code&client_id=$CLIENT_ID&redirect_uri=http://localhost:8080&scope=tasks:read%20tasks:write"
    
    echo "Please visit this URL in your browser:"
    echo "$auth_url"
    echo ""
    echo "After authorizing, you'll be redirected to a URL like:"
    echo "http://localhost:8080/?code=AUTHORIZATION_CODE"
    echo ""
    echo "Copy the 'code' parameter value and paste it below:"
    read -p "Authorization code: " auth_code
    
    if [[ -z "$auth_code" ]]; then
        echo "Error: No authorization code provided"
        exit 1
    fi
    
    # Exchange authorization code for tokens
    echo "Exchanging authorization code for tokens..."
    local response=$(curl -s -X POST "https://ticktick.com/oauth/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "Authorization: Basic $(echo -n "$CLIENT_ID:$CLIENT_SECRET" | base64)" \
        -d "grant_type=authorization_code" \
        -d "code=$auth_code" \
        -d "redirect_uri=http://localhost:8080")
    
    ACCESS_TOKEN=$(get_json_value "$response" "access_token")
    REFRESH_TOKEN=$(get_json_value "$response" "refresh_token")
    local expires_in=$(get_json_value "$response" "expires_in")
    
    if [[ -z "$ACCESS_TOKEN" ]]; then
        echo "Error: Failed to obtain access token"
        echo "Response: $response"
        exit 1
    fi
    
    # Calculate expiry time
    if [[ -n "$expires_in" ]]; then
        TOKEN_EXPIRY=$(($(date +%s) + expires_in - 300))  # 5 minutes buffer
    fi
    
    # Save initial tokens to config file
    save_config_file
    
    echo "Successfully authenticated! Tokens saved to ${CONFIG_FILE}."
    echo ""
}

# Get project ID by name
get_project_id() {
    local project_name="$1"
    if [[ -z "$project_name" ]]; then
        return 0
    fi
    
    local response=$(curl -s -X GET "https://api.ticktick.com/open/v1/project" \
        -H "Authorization: Bearer $ACCESS_TOKEN")
    
    # Parse projects and find matching name
    local project_id=$(python3 -c "
import json, sys
import re

def normalize_name(name):
    # Strip out all non a-zA-Z0-9_- and spaces, then trim whitespace
    normalized = re.sub(r'[^a-zA-Z0-9_\- ]', '', name)
    return normalized.strip().lower()

try:
    projects = json.loads(sys.argv[1])
    target_name = normalize_name(sys.argv[2])
    for project in projects:
        project_name = normalize_name(project.get('name', ''))
        if project_name == target_name:
            print(project.get('id', ''))
            break
except:
    pass
" "$response" "$project_name")
    
    echo "$project_id"
}

# Get task ID by name from a project
get_task_id_from_project() {
    local project_id="$1"
    local task_name="$2"
    if [[ -z "$project_id" || -z "$task_name" ]]; then
        return 0
    fi
    
    local response=$(curl -s -X GET "https://api.ticktick.com/open/v1/project/$project_id/data" \
        -H "Authorization: Bearer $ACCESS_TOKEN")
    
    # Parse tasks and find matching name
    local task_id=$(python3 -c "
import json, sys
import re

def normalize_name(name):
    # Strip out all non a-zA-Z0-9_- and spaces, then trim whitespace
    normalized = re.sub(r'[^a-zA-Z0-9_\- ]', '', name)
    return normalized.strip().lower()

try:
    data = json.loads(sys.argv[1])
    tasks = data.get('tasks', [])
    target_name = normalize_name(sys.argv[2])
    for task in tasks:
        task_title = normalize_name(task.get('title', ''))
        if task_title == target_name:
            print(task.get('id', ''))
            break
except:
    pass
" "$response" "$task_name")
    
    echo "$task_id"
}

# =============================================================================
# MAIN COMMAND FUNCTIONS
# =============================================================================

# Add a new task
task() {
    local title=""
    local description=""
    local list=""
    local priority=""
    local due=""
    local tag=""
    local update_mode=false
    local output_format="human"
    local add_tag_after=""
    local new_title=""
    local provided_task_id=""
    
    # Parse arguments (title first: consume words until first option)
    local collected_title=""
    local parsing_title=true
    while [[ $# -gt 0 ]]; do
        case $1 in
            
            --name|-n|--title)
                parsing_title=false
                shift
                if [[ $# -eq 0 || "$1" == --* ]]; then
                    echo "Error: --name requires a value"
                    return 1
                fi
                new_title=""
                while [[ $# -gt 0 && "$1" != --* ]]; do
                    if [[ -z "$new_title" ]]; then
                        new_title="$1"
                    else
                        new_title+=" $1"
                    fi
                    shift
                done
                ;;
            --content|-c|--description)
                parsing_title=false
                description="$2"
                shift 2
                ;;
            --list|-l)
                # Support unquoted multi-word list names: consume tokens until next option
                parsing_title=false
                shift
                if [[ $# -eq 0 || "$1" == --* ]]; then
                    echo "Error: --list requires a list name"
                    return 1
                fi
                list=""
                while [[ $# -gt 0 && "$1" != --* ]]; do
                    if [[ -z "$list" ]]; then
                        list="$1"
                    else
                        list+=" $1"
                    fi
                    shift
                done
                ;;
            --priority|-p)
                parsing_title=false
                priority="$2"
                shift 2
                ;;
            --due|-d)
                parsing_title=false
                due="$2"
                shift 2
                ;;
            --tag|-t)
                # Support multiple --tag flags; append with comma separation
                parsing_title=false
                if [[ -n "$tag" ]]; then
                    tag+=",$2"
                else
                    tag="$2"
                fi
                shift 2
                ;;
            --update|-u)
                parsing_title=false
                update_mode=true
                shift
                ;;
            --json|-j)
                parsing_title=false
                output_format="json"
                shift
                ;;
            --json-pretty|-jp)
                parsing_title=false
                output_format="json-pretty"
                shift
                ;;
            --id|-i)
                parsing_title=false
                provided_task_id="$2"
                update_mode=true
                shift 2
                ;;
            
            --*)
                parsing_title=false
                shift
                ;;
            *)
                if $parsing_title; then
                    if [[ -z "$collected_title" ]]; then
                        collected_title="$1"
                    else
                        collected_title+=" $1"
                    fi
                    shift
                    continue
                else
                    shift
                    continue
                fi
                ;;
        esac
    done
    if [[ -z "$title" && -n "$collected_title" ]]; then
        title="$collected_title"
    fi
    # For create: if no collected title, use --title as the actual title
    if [[ "$update_mode" != true && -z "$title" && -n "$new_title" ]]; then
        title="$new_title"
    fi

    # Convert priority string to integer (needed for both create and update)
    local priority_int=0
    if [[ -n "$priority" ]]; then
        case "$priority" in
            [Nn][Oo][Nn][Ee]|"")
                priority_int=0
                ;;
            [Ll][Oo][Ww])
                priority_int=1
                ;;
            [Mm][Ee][Dd][Ii][Uu][Mm])
                priority_int=3
                ;;
            [Hh][Ii][Gg][Hh])
                priority_int=5
                ;;
            *)
                echo "Error: Invalid priority '$priority'. Use: None, Low, Medium, High"
                return 1
                ;;
        esac
    fi
    
    # Process due date (needed for both create and update)
    local due_date_formatted=""
    if [[ -n "$due" ]]; then
        # Convert date string to proper format with timezone handling
        due_date_formatted=$(python3 -c "
import re
from datetime import datetime
import time

date_str = '$due'
try:
    if date_str.endswith('Z'):
        date_str = date_str[:-1] + '+0000'
    elif '+' in date_str or (date_str.count('-') >= 3 and len(date_str) > 19):
        pass
    else:
        date_part = date_str.split('T')[0]
        year, month, day = map(int, date_part.split('-'))
        test_date = datetime(year, month, day)
        is_dst_period = (month > 3 and month < 11) or (month == 3 and day >= 8) or (month == 11 and day <= 1)
        if is_dst_period:
            date_str = date_str + '-0700'
        else:
            date_str = date_str + '-0800'
    datetime.fromisoformat(date_str.replace('T', ' ').replace('+0000', '').replace('-0800', '').replace('-0700', '').replace('-0600', '').replace('-0500', ''))
    print(date_str)
except Exception as e:
    print('')
")
        if [[ -z "$due_date_formatted" ]]; then
            echo "Error: Invalid due date format. Use: yyyy-MM-dd'T'HH:mm:ss (local time) or yyyy-MM-dd'T'HH:mm:ssZ (UTC)"
            echo "Examples: 2025-01-15T14:30:00 (2:30 PM local) or 2025-01-15T14:30:00Z (2:30 PM UTC)"
            return 1
        fi
    fi
    
    # Handle update mode
    if [[ "$update_mode" == true ]]; then
        # Find task by title or ID
        local task_id=""
        local task_project_id=""
        local desired_project_id=""
        # Determine search key: prefer positional title for updates
        local search_key=""
        if [[ -n "$collected_title" ]]; then
            search_key="$collected_title"
        elif [[ -n "$title" ]]; then
            search_key="$title"
        elif [[ -n "$new_title" ]]; then
            search_key="$new_title"
        fi
        
        # If --id provided, use it
        if [[ -n "$provided_task_id" ]]; then
            task_id="$provided_task_id"
        fi

        
        # Check if search key looks like a task ID (24 hex characters)
        if [[ -z "$task_id" && "$search_key" =~ ^[a-f0-9]{24}$ ]]; then
            task_id="$search_key"
        fi

        # Fast path: If updating by --id and no --list move requested, find projectId first
        if [[ -n "$task_id" && -z "$list" ]]; then
            # Locate projectId by scanning projects (including Inbox)
            local projects_response=$(curl -s -X GET "https://api.ticktick.com/open/v1/project" \
                -H "Authorization: Bearer $ACCESS_TOKEN")
            local located_pid=$(echo "$projects_response" | python3 -c "
import json, sys, subprocess
try:
    projects = json.loads(sys.stdin.read())
    token = sys.argv[1]
    tid = sys.argv[2]
    # Check Inbox first
    cmd = ['curl','-s','-X','GET', 'https://api.ticktick.com/open/v1/project/inbox/data','-H', f'Authorization: Bearer {token}']
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode == 0:
        try:
            data = json.loads(res.stdout)
            for t in data.get('tasks', []):
                if str(t.get('id')) == tid:
                    print(t.get('projectId', 'inbox'))
                    raise SystemExit(0)
        except:
            pass
    # Then check other projects
    for project in projects:
        pid = project.get('id')
        if not pid:
            continue
        cmd = ['curl','-s','-X','GET', f'https://api.ticktick.com/open/v1/project/{pid}/data','-H', f'Authorization: Bearer {token}']
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0:
            continue
        try:
            data = json.loads(res.stdout)
        except:
            continue
        for t in data.get('tasks', []):
            if str(t.get('id')) == tid:
                print(t.get('projectId', pid))
                raise SystemExit(0)
except:
    pass
" "$ACCESS_TOKEN" "$task_id")
            
            # Build minimal payload from provided fields only
            local update_payload=$(python3 -c "
import json, sys

new_title = sys.argv[1] if len(sys.argv) > 1 else ''
description = sys.argv[2] if len(sys.argv) > 2 else ''
priority_int = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else 0
due_date_formatted = sys.argv[4] if len(sys.argv) > 4 else ''
tag = sys.argv[5] if len(sys.argv) > 5 else ''
project_id = sys.argv[6] if len(sys.argv) > 6 else ''

data = {}
if new_title:
    data['title'] = new_title
if description:
    data['content'] = description
if priority_int != 0:
    data['priority'] = priority_int
if due_date_formatted:
    data['dueDate'] = due_date_formatted
if tag:
    data['tags'] = [t.strip() for t in tag.split(',') if t.strip()]
# Include projectId for non-Inbox tasks
if project_id and not project_id.startswith('inbox'):
    data['projectId'] = project_id

print(json.dumps(data))
" "${new_title:-}" "$description" "$priority_int" "$due_date_formatted" "$tag" "$located_pid")

            # Use project-specific endpoint for Inbox, generic for others
            if [[ "$located_pid" == inbox* ]]; then
                local update_result=$(curl -s -w "\n%{http_code}" -X POST "https://api.ticktick.com/open/v1/project/$located_pid/task/$task_id" \
                    -H "Authorization: Bearer $ACCESS_TOKEN" \
                    -H "Content-Type: application/json" \
                    -d "$update_payload")
            else
                local update_result=$(curl -s -w "\n%{http_code}" -X POST "https://api.ticktick.com/open/v1/task/$task_id" \
                    -H "Authorization: Bearer $ACCESS_TOKEN" \
                    -H "Content-Type: application/json" \
                    -d "$update_payload")
            fi
            local http_status=$(echo "$update_result" | tail -n1)
            local update_response=$(echo "$update_result" | sed '$d')

            if [[ "$http_status" == 200 || "$http_status" == 204 ]]; then
                case "$output_format" in
                    json|json-pretty)
                        # If body empty, synthesize minimal success
                        if [[ -z "$update_response" ]]; then
                            update_response="{\"id\": \"$task_id\"}"
                        fi
                        echo "$update_response" | python3 -c "
$PYTHON_HELPERS
import json, sys

try:
    task_data = json.loads(sys.stdin.read())
    output = {
        'success': True,
        'action': 'updated',
        'task': task_data
    }
    indent = 2 if '$output_format' == 'json-pretty' else None
    print(json.dumps(output, indent=indent))
except Exception as e:
    print(json.dumps({'success': True, 'action': 'updated', 'id': '$task_id'}, indent=2 if '$output_format' == 'json-pretty' else None))
"
                        ;;
                    table)
                        ;;
                    *)
                        printf '\033[32mTask updated successfully! ID: %s\033[0m\n' "$task_id"
                        ;;
                esac
                # If tags were provided, ensure they apply by including projectId fallback
                if [[ -n "$tag" ]]; then
                    # First, try to get the task directly to extract its projectId
                    local direct_response=$(curl -s -X GET "https://api.ticktick.com/open/v1/task/$task_id" \
                        -H "Authorization: Bearer $ACCESS_TOKEN")
                    local located_pid=$(echo "$direct_response" | python3 -c "
import json, sys
try:
    task = json.loads(sys.stdin.read())
    if 'projectId' in task:
        print(task['projectId'])
        raise SystemExit(0)
except:
    pass
")
                    # If direct fetch didn't work, fall back to scanning projects
                    if [[ -z "$located_pid" ]]; then
                        local projects_response=$(curl -s -X GET "https://api.ticktick.com/open/v1/project" \
                            -H "Authorization: Bearer $ACCESS_TOKEN")
                        located_pid=$(echo "$projects_response" | python3 -c "
import json, sys, subprocess
try:
    projects = json.loads(sys.stdin.read())
    token = sys.argv[1]
    tid = sys.argv[2]
    # Check Inbox first
    cmd = ['curl','-s','-X','GET', 'https://api.ticktick.com/open/v1/project/inbox/data','-H', f'Authorization: Bearer {token}']
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode == 0:
        try:
            data = json.loads(res.stdout)
            for t in data.get('tasks', []):
                if str(t.get('id')) == tid:
                    print(t.get('projectId', 'inbox'))
                    raise SystemExit(0)
        except:
            pass
    # Then check other projects
    for project in projects:
        pid = project.get('id')
        if not pid:
            continue
        cmd = ['curl','-s','-X','GET', f'https://api.ticktick.com/open/v1/project/{pid}/data','-H', f'Authorization: Bearer {token}']
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0:
            continue
        try:
            data = json.loads(res.stdout)
        except:
            continue
        for t in data.get('tasks', []):
            if str(t.get('id')) == tid:
                print(t.get('projectId', pid))
                raise SystemExit(0)
except:
    pass
" "$ACCESS_TOKEN" "$task_id")
                    fi
                    if [[ -n "$located_pid" ]]; then
                        # Use project-specific endpoint for Inbox, generic endpoint with projectId for others
                        if [[ "$located_pid" == inbox* ]]; then
                            local tag_payload=$(python3 -c "import json,sys; print(json.dumps({'tags':[t.strip() for t in sys.argv[1].split(',') if t.strip()]}))" "$tag")
                            curl -s -X POST "https://api.ticktick.com/open/v1/project/$located_pid/task/$task_id" \
                                -H "Authorization: Bearer $ACCESS_TOKEN" \
                                -H "Content-Type: application/json" \
                                -d "$tag_payload" >/dev/null 2>&1 || true
                        else
                            local tag_payload=$(python3 -c "import json,sys; print(json.dumps({'tags':[t.strip() for t in sys.argv[1].split(',') if t.strip()], 'projectId': sys.argv[2]}))" "$tag" "$located_pid")
                            curl -s -X POST "https://api.ticktick.com/open/v1/task/$task_id" \
                                -H "Authorization: Bearer $ACCESS_TOKEN" \
                                -H "Content-Type: application/json" \
                                -d "$tag_payload" >/dev/null 2>&1 || true
                        fi
                    fi
                fi
                return 0
            else
                echo "Error: Failed to update task by ID"
                echo "HTTP Status: $http_status"
                [[ -n "$update_response" ]] && echo "Response: $update_response"
                return 1
            fi
        fi
        
        if [[ -n "$list" ]]; then
            # Search in specific list
            local project_id=$(get_project_id "$list")
            if [[ -z "$project_id" ]]; then
                echo "Error: List '$list' not found"
                return 1
            fi
            # Ensure updates end up in this list (may move projects)
            desired_project_id="$project_id"
            
            
            if [[ -n "$task_id" ]]; then
                local response=$(curl -s -X GET "https://api.ticktick.com/open/v1/project/$project_id/data" \
                    -H "Authorization: Bearer $ACCESS_TOKEN")
                
                local task_exists=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.loads(sys.stdin.read())
    tasks = data.get('tasks', [])
    for task in tasks:
        if task.get('id') == '$task_id':
            print('found')
            break
except:
    pass
")
                
                if [[ -n "$task_exists" ]]; then
                    task_project_id="$project_id"
                else
                    # Fallback: search across all projects by ID
                    local projects_response=$(curl -s -X GET "https://api.ticktick.com/open/v1/project" \
                        -H "Authorization: Bearer $ACCESS_TOKEN")
                    local found_task=$(echo "$projects_response" | python3 -c "
import json, sys, subprocess
try:
    projects = json.loads(sys.stdin.read())
    token = sys.argv[1]
    target_id = sys.argv[2]
    for project in projects:
        pid = project.get('id', '')
        if not pid:
            continue
        cmd = ['curl','-s','-X','GET', f'https://api.ticktick.com/open/v1/project/{pid}/data','-H', f'Authorization: Bearer {token}']
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            continue
        try:
            data = json.loads(result.stdout)
            for t in data.get('tasks', []):
                if str(t.get('id')) == target_id:
                    print(str(t.get('id')) + '|' + pid)
                    raise SystemExit(0)
        except:
            pass
except:
    pass
" "$ACCESS_TOKEN" "$task_id")
                    if [[ -n "$found_task" ]]; then
                        task_id=$(echo "$found_task" | cut -d'|' -f1)
                        task_project_id=$(echo "$found_task" | cut -d'|' -f2)
                    else
                        echo "\033[31mError: Task ID '$task_id' not found in any project\033[0m"
                        return 1
                    fi
                fi
            else
                # Search by title in this project (prefer collected pre-option title as search key)
                task_id=$(get_task_id_from_project "$project_id" "$search_key")
                if [[ -n "$task_id" ]]; then
                    task_project_id="$project_id"
                else
                    # Fallback: search across all projects by title/ID and then move
                    local projects_response=$(curl -s -X GET "https://api.ticktick.com/open/v1/project" \
                        -H "Authorization: Bearer $ACCESS_TOKEN")
                    local found_task=$(echo "$projects_response" | python3 -c "
import json, sys, subprocess, re

def normalize_name(name):
    normalized = re.sub(r'[^a-zA-Z0-9_\- ]', '', name)
    return normalized.strip().lower()

try:
    projects = json.loads(sys.stdin.read())
    target_name = normalize_name(sys.argv[2])
    raw_key = sys.argv[3]
    token = sys.argv[1]
    for project in projects:
        pid = project.get('id', '')
        if not pid:
            continue
        cmd = ['curl','-s','-X','GET', f'https://api.ticktick.com/open/v1/project/{pid}/data','-H', f'Authorization: Bearer {token}']
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            continue
        try:
            data = json.loads(result.stdout)
            for t in data.get('tasks', []):
                task_title = normalize_name(t.get('title', ''))
                if task_title == target_name or str(t.get('id')) == raw_key:
                    print(str(t.get('id')) + '|' + pid)
                    raise SystemExit(0)
        except:
            pass
except:
    pass
" "$ACCESS_TOKEN" "$(python3 -c "import re;print(re.sub(r'[^a-zA-Z0-9_\- ]','', '$search_key').strip().lower())")" "$search_key")
                    if [[ -n "$found_task" ]]; then
                        task_id=$(echo "$found_task" | cut -d'|' -f1)
                        task_project_id=$(echo "$found_task" | cut -d'|' -f2)
                    else
                        printf "\033[31mError: Task '%s' not found in any project\033[0m\n" "$search_key"
                        return 1
                    fi
                fi
            fi
        else
            # Search in all projects
            local projects_response=$(curl -s -X GET "https://api.ticktick.com/open/v1/project" \
                -H "Authorization: Bearer $ACCESS_TOKEN")
            
            local found_task=$(echo "$projects_response" | python3 -c "
import json, sys, subprocess

def normalize_name(name):
    import re
    normalized = re.sub(r'[^a-zA-Z0-9_\- ]', '', name)
    return normalized.strip().lower()

try:
    projects = json.loads(sys.stdin.read())
    target_name = normalize_name('$search_key')
    token = sys.argv[1]
    forced_id = sys.argv[2]
    
    for project in projects:
        project_id = project.get('id', '')
        if project_id:
            cmd = [
                'curl','-s','-X','GET',
                'https://api.ticktick.com/open/v1/project/{}/data'.format(project_id),
                '-H','Authorization: Bearer {}'.format(token)
            ]
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0:
                try:
                    project_data = json.loads(result.stdout)
                    tasks = project_data.get('tasks', [])
                    for task in tasks:
                        task_title = normalize_name(task.get('title', ''))
                        if task_title == target_name or str(task.get('id')) == forced_id or str(task.get('id')) == '$search_key':
                            print(str(task.get('id')) + '|' + project_id)
                            raise SystemExit(0)
                except:
                    pass
except:
    pass
" "$ACCESS_TOKEN" "$task_id")
            
            if [[ -n "$found_task" ]]; then
                task_id=$(echo "$found_task" | cut -d'|' -f1)
                task_project_id=$(echo "$found_task" | cut -d'|' -f2)
            else
                printf "\033[31mError: Task '%s' not found in any project\033[0m\n" "$search_key"
                return 1
            fi
        fi
        
        if [[ -z "$task_id" || -z "$task_project_id" ]]; then
            echo "Error: Could not find task to update"
            return 1
        fi
        
        
        # Now update the task
        # Get current task data first
        local current_response=$(curl -s -X GET "https://api.ticktick.com/open/v1/project/$task_project_id/data" \
            -H "Authorization: Bearer $ACCESS_TOKEN")
        
        local current_task=$(echo "$current_response" | python3 -c "
import json, sys
try:
    data = json.loads(sys.stdin.read())
    tasks = data.get('tasks', [])
    for task in tasks:
        if task.get('id') == '$task_id':
            print(json.dumps(task))
            break
except:
    pass
")
        
        if [[ -z "$current_task" ]]; then
            echo "Error: Could not retrieve current task data"
            return 1
        fi
        
        # Build update payload. If only moving lists, send just {id, projectId}
        local update_payload=$(echo "$current_task" | python3 -c "
import json, sys

current = json.loads(sys.stdin.read())
new_title = sys.argv[1] if len(sys.argv) > 1 else ''
description = sys.argv[2] if len(sys.argv) > 2 else ''
priority_int = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else 0
due_date_formatted = sys.argv[4] if len(sys.argv) > 4 else ''
tag = sys.argv[5] if len(sys.argv) > 5 else ''
target_project_id = sys.argv[6] if len(sys.argv) > 6 else ''
task_id = sys.argv[7] if len(sys.argv) > 7 else ''

# If only moving lists (no other fields provided), send minimal payload with id and projectId
if target_project_id and not any([new_title, description, priority_int, due_date_formatted, tag]):
    out = {}
    if task_id:
        out['id'] = task_id
    out['projectId'] = target_project_id
    print(json.dumps(out))
else:
    # Keep id
    if task_id:
        current['id'] = task_id
    # Overwrite fields if provided
    if new_title:
        current['title'] = new_title
    if description:
        current['content'] = description
    if priority_int != 0:
        current['priority'] = priority_int
    if due_date_formatted:
        current['dueDate'] = due_date_formatted
    if tag:
        current['tags'] = [t.strip() for t in tag.split(',') if t.strip()]
    if target_project_id:
        current['projectId'] = target_project_id
    # Remove fields known to cause update issues
    for k in ['etag', 'sortOrder', 'kind', 'items', 'createdTime', 'updatedTime']:
        current.pop(k, None)
    print(json.dumps(current))
" "${new_title:-}" "$description" "$priority_int" "$due_date_formatted" "$tag" "${desired_project_id:-}" "$task_id")
        
        
        # If a move was requested, perform create+delete flow. Otherwise, normal update.
        if [[ -n "$desired_project_id" && "$desired_project_id" != "$task_project_id" ]]; then
            
            # Build create payload using current task as base with overrides
            local create_payload=$(echo "$current_task" | python3 -c "
import json, sys

current = json.loads(sys.stdin.read())
new_title = sys.argv[1] if len(sys.argv) > 1 else ''
description = sys.argv[2] if len(sys.argv) > 2 else ''
priority_int = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else 0
due_date_formatted = sys.argv[4] if len(sys.argv) > 4 else ''
tag = sys.argv[5] if len(sys.argv) > 5 else ''
target_project_id = sys.argv[6] if len(sys.argv) > 6 else ''

out = {}
title = new_title or current.get('title', '')
out['title'] = title
if description:
    out['content'] = description
elif current.get('content'):
    out['content'] = current.get('content')
if target_project_id:
    out['projectId'] = target_project_id
if priority_int != 0:
    out['priority'] = priority_int
elif 'priority' in current:
    out['priority'] = current.get('priority', 0)
if due_date_formatted:
    out['dueDate'] = due_date_formatted
elif current.get('dueDate'):
    out['dueDate'] = current.get('dueDate')
if tag:
    out['tags'] = [t.strip() for t in tag.split(',') if t.strip()]
elif current.get('tags'):
    out['tags'] = current.get('tags')

print(json.dumps(out))
" "${new_title:-}" "$description" "$priority_int" "$due_date_formatted" "$tag" "$desired_project_id")
            
            # Create task in target project
            local create_result=$(curl -s -w "\n%{http_code}" -X POST "https://api.ticktick.com/open/v1/task" \
                -H "Authorization: Bearer $ACCESS_TOKEN" \
                -H "Content-Type: application/json" \
                -d "$create_payload")
            local create_status=$(echo "$create_result" | tail -n1)
            local create_response=$(echo "$create_result" | sed '$d')
            
            local new_task_id=$(get_json_value "$create_response" "id")
            local new_task_project_id=$(get_json_value "$create_response" "projectId")
            if [[ -z "$new_task_id" || "$new_task_project_id" != "$desired_project_id" ]]; then
                echo "Error: Failed to create task in target list during move"
                echo "Response: $create_response"
                echo "HTTP Status: $create_status"
                return 1
            fi
            # Verify presence in target project
            local verify_new=$(curl -s -X GET "https://api.ticktick.com/open/v1/project/$desired_project_id/data" -H "Authorization: Bearer $ACCESS_TOKEN")
            local verify_new_found=$(echo "$verify_new" | python3 -c "
import json, sys
try:
    data = json.loads(sys.stdin.read())
    for t in data.get('tasks', []):
        if str(t.get('id')) == sys.argv[1]:
            print('found')
            break
except:
    pass
" "$new_task_id")
            if [[ -z "$verify_new_found" ]]; then
                echo "Error: Created task not found in target project during move"
                return 1
            fi
            # Delete original task
            
            # Pre-delete wait until original task is consistently visible
            local pre_attempts=0
            while [[ $pre_attempts -lt 10 ]]; do
                local verify_old=$(curl -s -X GET "https://api.ticktick.com/open/v1/project/$task_project_id/data" -H "Authorization: Bearer $ACCESS_TOKEN")
                local verify_old_found=$(echo "$verify_old" | python3 -c "
import json, sys
try:
    data = json.loads(sys.stdin.read())
    for t in data.get('tasks', []):
        if str(t.get('id')) == sys.argv[1]:
            print('found')
            break
except:
    pass
" "$task_id")
                if [[ -n "$verify_old_found" ]]; then
                    break
                fi
                sleep 0.5
                pre_attempts=$((pre_attempts+1))
            done
            # Try delete with retries; increase backoff to handle consistency delays
            local delete_status=""
            local delete_body=""
            local del_attempts=0
            local delay=0.5
            while [[ $del_attempts -lt 8 ]]; do
                local del_result=$(curl -s -w "\n%{http_code}" -X DELETE "https://api.ticktick.com/open/v1/project/$task_project_id/task/$task_id" \
                    -H "Authorization: Bearer $ACCESS_TOKEN")
                delete_status=$(echo "$del_result" | tail -n1)
                delete_body=$(echo "$del_result" | sed '$d')
                
                if [[ "$delete_status" == 200 || "$delete_status" == 204 || "$delete_status" == 404 ]]; then
                    break
                fi
                sleep "$delay"
                del_attempts=$((del_attempts+1))
                # Exponential backoff up to ~4s
                delay=$(python3 -c 'import sys; d=float(sys.argv[1]); print(min(4.0, d*1.7))' "$delay")
            done
            # No POST fallback; TickTick delete uses HTTP DELETE only
            
            if [[ "$delete_status" != 200 && "$delete_status" != 204 ]]; then
                echo "Error: Failed to delete original task after move (status $delete_status)"
                return 1
            fi
            # Output success
            case "$output_format" in
                json|json-pretty)
                    echo "$create_response" | python3 -c "
$PYTHON_HELPERS
import json, sys

try:
    task_data = json.loads(sys.stdin.read())
    output = {
        'success': True,
        'action': 'moved',
        'task': task_data
    }
    priority_map = {0: 'None', 1: 'Low', 3: 'Medium', 5: 'High'}
    status_map = {0: 'pending', 1: 'completed'}
    output['task']['priority_text'] = priority_map.get(task_data.get('priority', 0), 'Unknown')
    output['task']['status_text'] = status_map.get(task_data.get('status', 0), 'Unknown')
    indent = 2 if '$output_format' == 'json-pretty' else None
    print(json.dumps(output, indent=indent))
except Exception as e:
    print(json.dumps({'success': False, 'error': str(e)}, indent=2 if '$output_format' == 'json-pretty' else None))
"
                    ;;
                table)
                    ;;
                *)
                    printf '\033[32mTask moved successfully! New ID: %s\033[0m\n' "$new_task_id"
                    ;;
            esac
            return 0
        else
            # Normal update
            local update_result=$(curl -s -w "\n%{http_code}" -X POST "https://api.ticktick.com/open/v1/task/$task_id" \
                -H "Authorization: Bearer $ACCESS_TOKEN" \
                -H "Content-Type: application/json" \
                -d "$update_payload")
            # Separate body and status code
            local http_status=$(echo "$update_result" | tail -n1)
            local update_response=$(echo "$update_result" | sed '$d')
            
        fi
        # Verify move when changing list: search across all projects for the task ID and confirm project
        local verify_success=false
        if [[ -n "$desired_project_id" && "$desired_project_id" != "$task_project_id" ]]; then
            local attempts=0
            local located_project_id=""
            while [[ $attempts -lt 10 ]]; do
                local projects_response=$(curl -s -X GET "https://api.ticktick.com/open/v1/project" -H "Authorization: Bearer $ACCESS_TOKEN")
                local found_task=$(echo "$projects_response" | python3 -c "
import json, sys, subprocess
try:
    projects = json.loads(sys.stdin.read())
    token = sys.argv[1]
    target_id = sys.argv[2]
    for project in projects:
        pid = project.get('id', '')
        if not pid:
            continue
        cmd = ['curl','-s','-X','GET', f'https://api.ticktick.com/open/v1/project/{pid}/data','-H', f'Authorization: Bearer {token}']
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            continue
        try:
            data = json.loads(result.stdout)
            for t in data.get('tasks', []):
                if str(t.get('id')) == target_id:
                    print(pid)
                    raise SystemExit(0)
        except:
            pass
except:
    pass
" "$ACCESS_TOKEN" "$task_id")
                if [[ -n "$found_task" ]]; then
                    located_project_id="$found_task"
                    if [[ "$located_project_id" == "$desired_project_id" ]]; then
                        verify_success=true
                        break
                    fi
                fi
                attempts=$((attempts+1))
                sleep 0.5
            done
            
            # No further fallbacks; only POST /open/v1/task/{taskId} is supported
        fi
        if [[ "$verify_success" == true ]] || [[ ( -z "$desired_project_id" || "$desired_project_id" == "$task_project_id" ) && ( "$http_status" == 200 || "$http_status" == 204 ) ]]; then
            case "$output_format" in
                json|json-pretty)
                    # If body is empty, build a minimal output but only after verification
                    local out_payload="$update_response"
                    if [[ -z "$out_payload" ]]; then
                        out_payload="{\"id\": \"$task_id\", \"projectId\": \"${desired_project_id:-$task_project_id}\"}"
                    fi
                    echo "$out_payload" | python3 -c "
$PYTHON_HELPERS
import json, sys

try:
    task_data = json.loads(sys.stdin.read())
    output = {
        'success': True,
        'action': 'updated',
        'task': task_data
    }
    priority_map = {0: 'None', 1: 'Low', 3: 'Medium', 5: 'High'}
    status_map = {0: 'pending', 1: 'completed'}
    output['task']['priority_text'] = priority_map.get(task_data.get('priority', 0), 'Unknown')
    output['task']['status_text'] = status_map.get(task_data.get('status', 0), 'Unknown')
    indent = 2 if '$output_format' == 'json-pretty' else None
    print(json.dumps(output, indent=indent))
except Exception as e:
    print(json.dumps({'success': False, 'error': str(e)}, indent=2 if '$output_format' == 'json-pretty' else None))
"
                    ;;
                table)
                    ;;
                *)
                    printf '\033[32mTask updated successfully! ID: %s\033[0m\n' "$updated_task_id"
                    ;;
            esac
        else
            echo "Error: Failed to update task"
            echo "Response: $update_response"
            echo "HTTP Status: $http_status"
            if [[ -n "$desired_project_id" && "$desired_project_id" != "$task_project_id" ]]; then
                echo "Verification: Task not found in target project after update"
            fi
            return 1
        fi
        
        return 0
    fi

    # Get project ID if list name provided
    local project_id=""
    if [[ -n "$list" ]]; then
        project_id=$(get_project_id "$list")
        if [[ -z "$project_id" ]]; then
            echo "Error: Project '$list' not found"
            return 1
        fi
    fi

    # Build JSON payload
    local payload=$(python3 -c "
import json, sys

# Read variables from command line arguments
title = sys.argv[1] if len(sys.argv) > 1 else ''
description = sys.argv[2] if len(sys.argv) > 2 else ''
project_id = sys.argv[3] if len(sys.argv) > 3 else ''
priority_int = int(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4].isdigit() else 0
due_date_formatted = sys.argv[5] if len(sys.argv) > 5 else ''
tag = sys.argv[6] if len(sys.argv) > 6 else ''

data = {'title': title}
if description:
    data['content'] = description
if project_id:
    data['projectId'] = project_id
if priority_int != 0:
    data['priority'] = priority_int
if due_date_formatted:
    data['dueDate'] = due_date_formatted
if tag:
    tags = [t.strip() for t in tag.split(',') if t.strip()]
    data['tags'] = tags
print(json.dumps(data))
" "${title}" "$description" "$project_id" "$priority_int" "$due_date_formatted" "$tag")

    # Create task
    local response=$(curl -s -X POST "https://api.ticktick.com/open/v1/task" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    local task_id=$(get_json_value "$response" "id")
    if [[ -n "$task_id" ]]; then
        case "$output_format" in
            json|json-pretty)
                echo "$response" | python3 -c "
$PYTHON_HELPERS
import json, sys

try:
    task_data = json.loads(sys.stdin.read())
    output = {
        'success': True,
        'action': 'created',
        'task': task_data
    }
    priority_map = {0: 'None', 1: 'Low', 3: 'Medium', 5: 'High'}
    status_map = {0: 'pending', 1: 'completed'}
    output['task']['priority_text'] = priority_map.get(task_data.get('priority', 0), 'Unknown')
    output['task']['status_text'] = status_map.get(task_data.get('status', 0), 'Unknown')
    indent = 2 if '$output_format' == 'json-pretty' else None
    print(json.dumps(output, indent=indent))
except Exception as e:
    print(json.dumps({'success': False, 'error': str(e)}, indent=2 if '$output_format' == 'json-pretty' else None))
"
                ;;
            table)
                ;;
            *)
                printf '\033[32mTask created successfully! ID: %s\033[0m\n' "$task_id"
                ;;
        esac
    else
        echo "Error: Failed to create task"
        echo "Response: $response"
        return 1
    fi
}

# Complete a task
complete_task() {
    local task_identifier=""
    local list_name=""
    local output_format="human"
    local add_tag_after=""
    
    # Collect positional name until first option
    local collected_name=""
    local parsing_name=true
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --task|--name|-n)
                parsing_name=false
                shift
                if [[ $# -eq 0 || "$1" == --* || "$1" == -* ]]; then
                    echo "Error: --name requires a value"
                    return 1
                fi
                task_identifier=""
                while [[ $# -gt 0 && "$1" != --* && "$1" != -* ]]; do
                    if [[ -z "$task_identifier" ]]; then
                        task_identifier="$1"
                    else
                        task_identifier+=" $1"
                    fi
                    shift
                done
                ;;
            --id|-i)
                parsing_name=false
                task_identifier="$2"
                shift 2
                ;;
            --list|-l)
                parsing_name=false
                list_name="$2"
                shift 2
                ;;
            --tag|-t)
                parsing_name=false
                add_tag_after="$2"
                shift 2
                ;;
            --json|-j)
                parsing_name=false
                output_format="json"
                shift
                ;;
            --json-pretty|-jp)
                parsing_name=false
                output_format="json-pretty"
                shift
                ;;
            --*)
                parsing_name=false
                shift
                ;;
            *)
                if $parsing_name; then
                    if [[ -z "$collected_name" ]]; then
                        collected_name="$1"
                    else
                        collected_name+=" $1"
                    fi
                    shift
                    continue
                else
                    shift
                    continue
                fi
                ;;
        esac
    done
    
    if [[ -z "$task_identifier" && -n "$collected_name" ]]; then
        task_identifier="$collected_name"
    fi
    
    if [[ -z "$task_identifier" ]]; then
        echo "Error: Task is required (use name or --id)"
        return 1
    fi
    
    # Determine project and task based on inputs
    local project_id=""
    local task_id=""
    if [[ "$task_identifier" =~ ^[a-f0-9]{24}$ ]]; then
        # Identifier is a task ID
        task_id="$task_identifier"
        if [[ -n "$list_name" ]]; then
            # Use provided list to resolve project
            if [[ "$list_name" == "Inbox" ]] || [[ "$list_name" == "inbox" ]]; then
                project_id="inbox"
            else
                project_id=$(get_project_id "$list_name")
                if [[ -z "$project_id" ]]; then
                    echo "Error: List '$list_name' not found"
                    return 1
                fi
            fi
        else
            # No list provided; search all projects (including Inbox) for this task ID
            local projects_response=$(curl -s -X GET "https://api.ticktick.com/open/v1/project" \
                -H "Authorization: Bearer $ACCESS_TOKEN")
            local located=$(echo "$projects_response" | python3 -c "
import json, sys, subprocess
try:
    projects = json.loads(sys.stdin.read())
    token = sys.argv[1]
    tid = sys.argv[2]
    # Check Inbox first
    cmd = ['curl','-s','-X','GET', 'https://api.ticktick.com/open/v1/project/inbox/data','-H', f'Authorization: Bearer {token}']
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode == 0:
        try:
            data = json.loads(res.stdout)
            for t in data.get('tasks', []):
                if str(t.get('id')) == tid:
                    print('inbox')
                    raise SystemExit(0)
        except:
            pass
    # Then check other projects
    for project in projects:
        pid = project.get('id')
        if not pid:
            continue
        cmd = ['curl','-s','-X','GET', f'https://api.ticktick.com/open/v1/project/{pid}/data','-H', f'Authorization: Bearer {token}']
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0:
            continue
        try:
            data = json.loads(res.stdout)
        except:
            continue
        for t in data.get('tasks', []):
            if str(t.get('id')) == tid:
                print(pid)
                raise SystemExit(0)
except:
    pass
" "$ACCESS_TOKEN" "$task_id")
            if [[ -z "$located" ]]; then
                echo "Error: Could not find task ID '$task_id' in any project"
                return 1
            fi
            project_id="$located"
        fi
    else
        # Identifier is a task title
        if [[ -n "$list_name" ]]; then
            # Resolve within a specific list
            if [[ "$list_name" == "Inbox" ]] || [[ "$list_name" == "inbox" ]]; then
                project_id="inbox"
            else
                project_id=$(get_project_id "$list_name")
                if [[ -z "$project_id" ]]; then
                    echo "Error: List '$list_name' not found"
                    return 1
                fi
            fi
            task_id=$(get_task_id_from_project "$project_id" "$task_identifier")
            if [[ -z "$task_id" ]]; then
                echo "Error: Task '$task_identifier' not found in list '$list_name'"
                return 1
            fi
        else
            # Search across all projects (including Inbox) for first title match
            local projects_response=$(curl -s -X GET "https://api.ticktick.com/open/v1/project" \
                -H "Authorization: Bearer $ACCESS_TOKEN")
            local found=$(echo "$projects_response" | python3 -c "
import json, sys, subprocess, re

def normalize_name(name):
    return re.sub(r'[^a-zA-Z0-9_\- ]', '', name).strip().lower()

try:
    projects = json.loads(sys.stdin.read())
    token = sys.argv[1]
    target = normalize_name(sys.argv[2])
    # Check Inbox first
    cmd = ['curl','-s','-X','GET', 'https://api.ticktick.com/open/v1/project/inbox/data','-H', f'Authorization: Bearer {token}']
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode == 0:
        try:
            data = json.loads(res.stdout)
            for t in data.get('tasks', []):
                title = normalize_name(t.get('title',''))
                if title == target:
                    print(str(t.get('id')) + '|inbox')
                    raise SystemExit(0)
        except:
            pass
    # Then check other projects
    for project in projects:
        pid = project.get('id')
        if not pid:
            continue
        cmd = ['curl','-s','-X','GET', f'https://api.ticktick.com/open/v1/project/{pid}/data','-H', f'Authorization: Bearer {token}']
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0:
            continue
        try:
            data = json.loads(res.stdout)
        except:
            continue
        for t in data.get('tasks', []):
            title = normalize_name(t.get('title',''))
            if title == target:
                print(str(t.get('id')) + '|' + pid)
                raise SystemExit(0)
except:
    pass
" "$ACCESS_TOKEN" "$(python3 -c "import re;print(re.sub(r'[^a-zA-Z0-9_\- ]','', '$task_identifier').strip().lower())")")
            if [[ -z "$found" ]]; then
                echo "Error: Task '$task_identifier' not found in any list"
                return 1
            fi
            task_id=$(echo "$found" | cut -d'|' -f1)
            project_id=$(echo "$found" | cut -d'|' -f2)
        fi
    fi
    
    # If a tag was requested, add it BEFORE completing the task
    # The task command will handle finding the projectId automatically
    if [[ -n "$add_tag_after" ]]; then
        local tag_update_response=$("$0" task --id "$task_id" --tag "$add_tag_after" --json 2>&1)
        # Check if tag update failed
        if [[ "$tag_update_response" == *"error"* ]] && [[ "$tag_update_response" != *"success\": true"* ]]; then
            echo "Error: Failed to add tag before completing task"
            if [[ "$output_format" == "json" || "$output_format" == "json-pretty" ]]; then
                echo "$tag_update_response"
            else
                echo "Tag update response: $tag_update_response"
            fi
            return 1
        fi
    fi
    
    # Complete task using correct endpoint format
    local response=$(curl -s -X POST "https://api.ticktick.com/open/v1/project/$project_id/task/$task_id/complete" \
        -H "Authorization: Bearer $ACCESS_TOKEN")
    
    # Check if response contains error
    if [[ "$response" == *"errorCode"* ]]; then
        # Format error output based on format type
        case "$output_format" in
            json|json-pretty)
                echo "$response" | python3 -c "
$PYTHON_HELPERS
import json, sys

try:
    error_data = json.loads(sys.stdin.read())
    output = {
        'success': False,
        'action': 'complete',
        'error': error_data.get('errorMessage', 'Unknown error'),
        'errorCode': error_data.get('errorCode', 'Unknown')
    }
    
    indent = 2 if '$output_format' == 'json-pretty' else None
    print(json.dumps(output, indent=indent))
except Exception as e:
    print(json.dumps({'success': False, 'error': str(e)}, indent=2 if '$output_format' == 'json-pretty' else None))
"
                ;;
            table)
                ;;
            *)
                printf '\033[31mError: Failed to complete task %s\033[0m\n' "$task_identifier"
                ;;
        esac
        return 1
    else
        # Format success output based on format type
        case "$output_format" in
            json|json-pretty)
                # Include tag update response if there was one
                if [[ -n "$add_tag_after" && -n "$tag_update_response" ]]; then
                    echo "$tag_update_response"
                else
                    echo "{\"success\": true, \"action\": \"completed\", \"task\": \"$task_identifier\", \"taskId\": \"$task_id\", \"list\": \"$list_name\"}" | python3 -c "
$PYTHON_HELPERS
import json, sys

try:
    data = json.loads(sys.stdin.read())
    indent = 2 if '$output_format' == 'json-pretty' else None
    print(json.dumps(data, indent=indent))
except Exception as e:
    print(json.dumps({'success': False, 'error': str(e)}, indent=2 if '$output_format' == 'json-pretty' else None))
"
                fi
                ;;
            table)
                ;;
            *)
                printf '\033[32mTask %s marked as complete! (ID: %s)\033[0m\n' "$task_identifier" "$task_id"
                if [[ -n "$add_tag_after" ]]; then
                    echo "Tag '$add_tag_after' added before completion"
                fi
                ;;
        esac
    fi
}

# Show tasks
tasks() {
    local list=""
    local status="all"
    # Default to table view
    local output_format="table"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --list|-l)
                # Support unquoted multi-word list names: consume tokens until next option
                shift
                if [[ $# -eq 0 || "$1" == --* || "$1" == -* ]]; then
                    echo "Error: --list requires a list name"
                    return 1
                fi
                list=""
                while [[ $# -gt 0 && "$1" != --* && "$1" != -* ]]; do
                    if [[ -z "$list" ]]; then
                        list="$1"
                    else
                        list+=" $1"
                    fi
                    shift
                done
                ;;
            --status)
                status="$2"
                shift 2
                ;;
            --json)
                output_format="json"
                shift
                ;;
            --json-pretty)
                output_format="json-pretty"
                shift
                ;;
            # no --table option
            -*)
                echo "Error: Unknown option $1"
                return 1
                ;;
            *)
                echo "Error: Unexpected argument $1"
                return 1
                ;;
        esac
    done
    
    if [[ -n "$list" ]]; then
        # Check if it's the Inbox (special case)
        local project_id=""
        if [[ "$list" == "Inbox" ]] || [[ "$list" == "inbox" ]]; then
            # Inbox has a special project ID
            project_id="inbox"
        else
            # Get tasks from specific list
            project_id=$(get_project_id "$list")
            if [[ -z "$project_id" ]]; then
                echo "Error: List '$list' not found"
                return 1
            fi
        fi
        
        # Get pending tasks
        local response=$(curl -s -X GET "https://api.ticktick.com/open/v1/project/$project_id/data" \
            -H "Authorization: Bearer $ACCESS_TOKEN")
        # Optionally get completed tasks (some APIs separate these)
        local completed_response=""
        if [[ "$status" == "completed" || "$status" == "all" ]]; then
            completed_response=$(curl -s -X GET "https://api.ticktick.com/open/v1/project/$project_id/task/completed?from=0" \
                -H "Authorization: Bearer $ACCESS_TOKEN")
        fi
        
        # Parse and display tasks from single project
        case "$output_format" in
            json|json-pretty)
                # Merge pending + completed and apply status filter
                local sep=$'\x1e'
                echo "${response}${sep}${completed_response}" | python3 -c "
$PYTHON_HELPERS
import json, sys

try:
    blob = sys.stdin.read()
    parts = blob.split('\x1e')
    pending = json.loads(parts[0]) if parts and parts[0].strip() else {}
    completed_raw = parts[1] if len(parts) > 1 else ''
    completed = []
    if completed_raw.strip():
        try:
            parsed = json.loads(completed_raw)
            if isinstance(parsed, list):
                completed = parsed
            elif isinstance(parsed, dict):
                completed = parsed.get('tasks', parsed.get('completedTasks', []))
        except:
            completed = []

    if 'errorCode' in pending:
        output = {
            'success': False,
            'error': pending.get('errorMessage', 'Unknown error'),
            'errorCode': pending.get('errorCode', 'Unknown')
        }
        indent = 2 if '$output_format' == 'json-pretty' else None
        print(json.dumps(output, indent=indent))
        sys.exit(1)

    tasks = pending.get('tasks', [])
    if completed:
        tasks += completed

    status_opt = '$status'.strip().lower()
    if status_opt in ('pending','completed'):
        want = 0 if status_opt == 'pending' else 1
        tasks = [t for t in tasks if int(t.get('status', 0)) == want]

    priority_map = {0: 'None', 1: 'Low', 3: 'Medium', 5: 'High'}
    status_map = {0: 'pending', 1: 'completed'}
    for t in tasks:
        t['priority_text'] = priority_map.get(t.get('priority', 0), 'Unknown')
        t['status_text'] = status_map.get(t.get('status', 0), 'Unknown')

    output = {'success': True, 'count': len(tasks), 'list': '$list', 'tasks': tasks}
    indent = 2 if '$output_format' == 'json-pretty' else None
    print(json.dumps(output, indent=indent))
except Exception as e:
    print(json.dumps({'success': False, 'error': str(e)}, indent=2 if '$output_format' == 'json-pretty' else None))
"
                ;;
            table)
                local term_width=$(get_terminal_width)
                echo "$response" | python3 -c "
$PYTHON_HELPERS
import json, sys

try:
    response_data = sys.stdin.read()
    term_width = int(sys.argv[1])
    data = json.loads(response_data)
    
    # Check if it's an error response
    if 'errorCode' in data:
        error_msg = f\"API Error: {data.get('errorMessage', 'Unknown error')}\"
        term_width = int(sys.argv[1])
        format_simple_table(error_msg, term_width)
        sys.exit(1)
    
    tasks_pending = data.get('tasks', [])
    tasks_completed = data.get('completedTasks', [])
    tasks = tasks_pending + tasks_completed
    status_opt = '$status'.strip().lower()
    if status_opt in ('pending','completed'):
        want = 0 if status_opt == 'pending' else 1
        tasks = [t for t in tasks if int(t.get('status', 0)) == want]
    
    if not tasks:
        format_simple_table('No tasks found in this list.', term_width)
        sys.exit(0)
    
    # Calculate column widths for single project view (Task, Due, Tags)
    # Total fixed non-content per row for 3 columns: 10 characters
    # Available for content: term_width - 10
    available_width = term_width - 10
    
    # Fixed column widths; Task fills remainder
    tags_width = 20
    due_width = 21
    
    # Remaining width goes to task column
    task_width = available_width - tags_width - due_width
    if task_width < 20:
        task_width = 20  # minimum
    
    # Build table with count in header
    top = '┌' + '─' * (task_width + 2) + '┬' + '─' * (tags_width + 2) + '┬' + '─' * (due_width + 2) + '┐'
    header = '│ ' + f'Tasks ({len(tasks)})'.ljust(task_width) + ' │ ' + 'Tags'.ljust(tags_width) + ' │ ' + 'Due'.ljust(due_width) + ' │'
    separator = '├' + '─' * (task_width + 2) + '┼' + '─' * (tags_width + 2) + '┼' + '─' * (due_width + 2) + '┤'
    bottom = '└' + '─' * (task_width + 2) + '┴' + '─' * (tags_width + 2) + '┴' + '─' * (due_width + 2) + '┘'
    
    print(top)
    print(header)
    print(separator)
    
    priority_map = {0: 'None', 1: 'Low', 3: 'Medium', 5: 'High'}
    status_map = {0: 'Pending', 1: 'Completed'}
    
    # Sort: primary by priority (desc), secondary by dueDate (asc, empty last)
    from datetime import datetime, timezone
    def due_key(t):
        d = t.get('dueDate')
        if not d:
            return float('inf')
        try:
            if isinstance(d, (int, float)):
                # assume milliseconds
                return int(d)/1000.0
            # ISO format like 2025-01-21T07:00:00.000+0000
            ds = str(d)
            if ds.endswith('Z'):
                ds = ds[:-1] + '+00:00'
            # convert +0000 or +HHMM to +HH:MM
            if len(ds) >= 5 and (ds[-5] in ['+', '-']) and ds[-3] != ':':
                ds = ds[:-2] + ':' + ds[-2:]
            dt = datetime.fromisoformat(ds)
            if dt.tzinfo is None:
                return dt.timestamp()
            return dt.timestamp()
        except:
            return float('inf')
    tasks.sort(key=lambda x: (-(x.get('priority', 0)), due_key(x)))
    
    for task in tasks:
        title = strip_emojis(task.get('title', 'No title'))
        
        # Add priority-based color dot to task name
        priority = task.get('priority', 0)
        priority_colors = {0: '7', 1: '12', 3: '11', 5: '9'}  # gray, blue, yellow, red
        color_code = priority_colors.get(priority, '7')
        colored_dot = f'\033[38;5;{color_code}m●\033[0m'
        title_with_dot = f'{colored_dot} {title}'
        
        # Calculate actual display width (without color codes)
        actual_title_width = len(title_with_dot)
        color_codes_removed = re.sub(r'\033\[[0-9;]*m', '', title_with_dot)
        actual_title_width = len(color_codes_removed)
        
        if actual_title_width > task_width:
            # Truncate the title part, keep the dot
            available_width = task_width - 2  # space for dot and space
            truncated_title = title[:available_width-3] + '...'
            title_with_dot = f'{colored_dot} {truncated_title}'
            actual_title_width = len(color_codes_removed.replace(title, truncated_title))
        
        # Format due date with capitalized day and month
        due_date = task.get('dueDate', '')
        due_str = '-'
        if due_date:
            try:
                # Handle both timestamp and ISO format
                if due_date.isdigit():
                    dt = datetime.fromtimestamp(int(due_date) / 1000)
                else:
                    # Parse ISO format like "2025-01-21T07:00:00.000+0000"
                    from datetime import datetime
                    dt = datetime.fromisoformat(due_date.replace('Z', '+00:00'))
                # Capitalize day and month, use a/p instead of AM/PM
                due_str = dt.strftime('%a, %b %d %y %I:%M%p').replace('AM', 'a').replace('PM', 'p')
            except:
                due_str = str(due_date)
        
        status = status_map.get(task.get('status', 0), 'Unknown')
        
        # Capitalize tags
        tags = task.get('tags', [])
        tags_str = ', '.join(tag.capitalize() for tag in tags) if tags else '-'
        if len(tags_str) > tags_width:
            tags_str = tags_str[:tags_width-3] + '...'
        
        # Pad to full width
        title_padding = task_width - actual_title_width
        if title_padding > 0:
            title_with_dot += ' ' * title_padding
        
        print('│ ' + title_with_dot + ' │ ' + tags_str.ljust(tags_width) + ' │ ' + due_str.ljust(due_width) + ' │')
    
    print(bottom)
    
except Exception as e:
    term_width = int(sys.argv[1])
    format_simple_table(f'Error parsing tasks: {e}', term_width)
" "$term_width"
                ;;
            *)
                # Human-readable format (default)
                echo "$response" | python3 -c "
$PYTHON_HELPERS
import json, sys

try:
    response_data = sys.stdin.read()
    data = json.loads(response_data)
    
    # Check if it's an error response
    if 'errorCode' in data:
        print(f'API Error: {data.get(\"errorMessage\", \"Unknown error\")}')
        print(f'Error Code: {data.get(\"errorCode\", \"Unknown\")}')
        sys.exit(1)
    
    tasks = data.get('tasks', [])
    
    if not tasks:
        print('No tasks found in this list.')
        sys.exit(0)
    
    print(f'Found {len(tasks)} task(s) in list:')
    print('-' * 80)
    
    for task in tasks:
        title = task.get('title', 'No title')
        content = task.get('content', '')
        tags = task.get('tags', [])
        task_status = task.get('status', 'Unknown')
        due_date = task.get('dueDate', '')
        priority = task.get('priority', 0)
        
        # Convert priority integer to string
        priority_map = {0: 'None', 1: 'Low', 3: 'Medium', 5: 'High'}
        priority_str = priority_map.get(priority, f'Unknown({priority})')
        
        print(f'ID: {task.get(\"id\", \"Unknown\")}')
        print(f'Title: {title}')
        if content:
            print(f'Description: {content}')
        if tags:
            print(f'Tags: {\", \".join(tags)}')
        if due_date:
            try:
                dt = datetime.fromtimestamp(int(due_date) / 1000)
                print(f'Due: {dt.strftime(\"%Y-%m-%d %H:%M\")}')
            except:
                print(f'Due: {due_date}')
        print(f'Priority: {priority_str}')
        print(f'Status: {task_status}')
        print('-' * 80)
        
except Exception as e:
    print(f'Error parsing tasks: {e}')
    print('Raw response length:', len(response_data))
"
                ;;
        esac
    else
        # Get tasks from all projects
        local projects_response=$(curl -s -X GET "https://api.ticktick.com/open/v1/project" \
            -H "Authorization: Bearer $ACCESS_TOKEN")
        
        # Get project IDs, names, and colors
        local project_data=$(echo "$projects_response" | python3 -c "
import json, sys
try:
    projects = json.loads(sys.stdin.read())
    for project in projects:
        project_id = project.get('id', '')
        project_name = project.get('name', 'Unknown')
        project_color = project.get('color', '')
        print(f'{project_id}|{project_name}|{project_color}')
except:
    pass
")
        
        # Process project data line by line to handle names with spaces
        while IFS= read -r project_info; do
            if [[ -n "$project_info" ]]; then
                IFS='|' read -r project_id project_name project_color <<< "$project_info"
                
                if [[ -n "$project_id" ]]; then
                    local project_response=$(curl -s -X GET "https://api.ticktick.com/open/v1/project/$project_id/data" \
                        -H "Authorization: Bearer $ACCESS_TOKEN")
                    
                    local project_tasks=$(echo "$project_response" | python3 -c "
import json, sys
try:
    data = json.loads(sys.stdin.read())
    tasks = data.get('tasks', [])
    for task in tasks:
        task['projectName'] = '$project_name'
        task['projectColor'] = '$project_color'
        print(json.dumps(task))
except:
    pass
")
                    
                    if [[ -n "$project_tasks" ]]; then
                        all_tasks="$all_tasks$project_tasks"$'\n'
                    fi
                fi
            fi
        done <<< "$project_data"
        
        # Display all tasks based on output format
        case "$output_format" in
            json|json-pretty)
                echo "$all_tasks" | python3 -c "
$PYTHON_HELPERS
import json, sys
from datetime import datetime

try:
    all_tasks = []
    for line in sys.stdin:
        line = line.strip()
        if line:
            try:
                task = json.loads(line)
                all_tasks.append(task)
            except:
                pass
    
    if not all_tasks:
        output = {'success': True, 'count': 0, 'list': 'All Projects', 'tasks': []}
    else:
        # Add human-readable fields
        for task in all_tasks:
            priority = task.get('priority', 0)
            priority_map = {0: 'None', 1: 'Low', 3: 'Medium', 5: 'High'}
            task['priority_text'] = priority_map.get(priority, f'Unknown({priority})')
            
            status = task.get('status', 0)
            status_map = {0: 'pending', 1: 'completed'}
            task['status_text'] = status_map.get(status, f'Unknown({status})')
        
        output = {
            'success': True,
            'count': len(all_tasks),
            'list': 'All Projects',
            'tasks': all_tasks
        }
    
    indent = 2 if '$output_format' == 'json-pretty' else None
    print(json.dumps(output, indent=indent))
    
except Exception as e:
    error_output = {'success': False, 'error': f'Error parsing tasks: {e}'}
    indent = 2 if '$output_format' == 'json-pretty' else None
    print(json.dumps(error_output, indent=indent))
"
                ;;
            table)
                local term_width=$(get_terminal_width)
                echo "$all_tasks" | python3 -c "
$PYTHON_HELPERS
import json, sys
from datetime import datetime

try:
    all_tasks = []
    for line in sys.stdin:
        line = line.strip()
        if line:
            try:
                task = json.loads(line)
                all_tasks.append(task)
            except:
                pass
    
    if not all_tasks:
        term_width = int(sys.argv[1])
        format_simple_table('No tasks found.', term_width)
    else:
        term_width = int(sys.argv[1])
        
        # Calculate column widths for all projects view (Task, List, Due, Status, Tags)
        # Total border chars: 5 columns + 4 separators + 2 end borders = 11
        # Fixed non-content per row for 4 columns (Task, List, Due, Tags): 13
        # Available content width = term_width - 13
        available_width = term_width - 13
        
        # Fixed column widths; Task fills the remainder
        list_width = 20
        tags_width = 20
        due_width = 21
        
        # Remaining width goes to task column
        task_width = available_width - list_width - tags_width - due_width
        if task_width < 20:
            task_width = 20  # minimum
        
        # Build table with count in header
        top = '┌' + '─' * (task_width + 2) + '┬' + '─' * (list_width + 2) + '┬' + '─' * (tags_width + 2) + '┬' + '─' * (due_width + 2) + '┐'
        header = '│ ' + f'Tasks ({len(all_tasks)})'.ljust(task_width) + ' │ ' + 'List'.ljust(list_width) + ' │ ' + 'Tags'.ljust(tags_width) + ' │ ' + 'Due'.ljust(due_width) + ' │'
        separator = '├' + '─' * (task_width + 2) + '┼' + '─' * (list_width + 2) + '┼' + '─' * (tags_width + 2) + '┼' + '─' * (due_width + 2) + '┤'
        bottom = '└' + '─' * (task_width + 2) + '┴' + '─' * (list_width + 2) + '┴' + '─' * (tags_width + 2) + '┴' + '─' * (due_width + 2) + '┘'
        
        print(top)
        print(header)
        print(separator)
        
        # Sort: primary by priority (desc), secondary by dueDate (asc, empty last)
        from datetime import datetime, timezone
        def due_key(t):
            d = t.get('dueDate')
            if not d:
                return float('inf')
            try:
                if isinstance(d, (int, float)):
                    return int(d)/1000.0
                ds = str(d)
                if ds.endswith('Z'):
                    ds = ds[:-1] + '+00:00'
                if len(ds) >= 5 and (ds[-5] in ['+', '-']) and ds[-3] != ':':
                    ds = ds[:-2] + ':' + ds[-2:]
                dt = datetime.fromisoformat(ds)
                if dt.tzinfo is None:
                    return dt.timestamp()
                return dt.timestamp()
            except:
                return float('inf')
        all_tasks.sort(key=lambda x: (-(x.get('priority', 0)), due_key(x)))
        
        for task in all_tasks:
            title = strip_emojis(task.get('title', 'No title'))
            
            # Add priority-based color dot to task name
            priority = task.get('priority', 0)
            priority_colors = {0: '7', 1: '12', 3: '11', 5: '9'}  # gray, blue, yellow, red
            color_code = priority_colors.get(priority, '7')
            colored_dot = f'\033[38;5;{color_code}m●\033[0m'
            title_with_dot = f'{colored_dot} {title}'
            
            # Calculate actual display width (without color codes)
            actual_title_width = len(title_with_dot)
            color_codes_removed = re.sub(r'\033\[[0-9;]*m', '', title_with_dot)
            actual_title_width = len(color_codes_removed)
            
            if actual_title_width > task_width:
                # Truncate the title part, keep the dot
                available_width = task_width - 2  # space for dot and space
                truncated_title = title[:available_width-3] + '...'
                title_with_dot = f'{colored_dot} {truncated_title}'
                actual_title_width = len(color_codes_removed.replace(title, truncated_title))
            
            # Get project name for List column with color dot
            project_name = strip_emojis(task.get('projectName', 'Unknown'))
            project_color = task.get('projectColor', '')
            
            if project_color:
                project_colored_dot = colored_circle(project_color)
                project_name_with_dot = f'{project_colored_dot} {project_name}'
            else:
                project_name_with_dot = f'● {project_name}'
            
            # Calculate actual project name width (without color codes)
            actual_project_width = len(project_name_with_dot)
            project_color_codes_removed = re.sub(r'\033\[[0-9;]*m', '', project_name_with_dot)
            actual_project_width = len(project_color_codes_removed)
            
            if actual_project_width > list_width:
                available_width = list_width - 2  # space for dot and space
                truncated_project = project_name[:available_width-3] + '...'
                if project_color:
                    project_name_with_dot = f'{project_colored_dot} {truncated_project}'
                else:
                    project_name_with_dot = f'● {truncated_project}'
                actual_project_width = len(project_color_codes_removed.replace(project_name, truncated_project))
            
            # Format due date with capitalized day and month
            due_date = task.get('dueDate', '')
            due_str = '-'
            if due_date:
                try:
                    # Handle both timestamp and ISO format
                    if due_date.isdigit():
                        dt = datetime.fromtimestamp(int(due_date) / 1000)
                    else:
                        # Parse ISO format like "2025-01-21T07:00:00.000+0000"
                        from datetime import datetime
                        dt = datetime.fromisoformat(due_date.replace('Z', '+00:00'))
                    # Capitalize day and month, use a/p instead of AM/PM
                    due_str = dt.strftime('%a, %b %d %y %I:%M%p').replace('AM', 'a').replace('PM', 'p')
                except:
                    due_str = str(due_date)
            
            # Capitalize tags
            tags = task.get('tags', [])
            tags_str = ', '.join(tag.capitalize() for tag in tags) if tags else '-'
            if len(tags_str) > tags_width:
                tags_str = tags_str[:tags_width-3] + '...'
            
            # Pad to full width
            title_padding = task_width - actual_title_width
            if title_padding > 0:
                title_with_dot += ' ' * title_padding
            
            project_padding = list_width - actual_project_width
            if project_padding > 0:
                project_name_with_dot += ' ' * project_padding
            
            print('│ ' + title_with_dot + ' │ ' + project_name_with_dot + ' │ ' + tags_str.ljust(tags_width) + ' │ ' + due_str.ljust(due_width) + ' │')
        
        print(bottom)
    
except Exception as e:
    term_width = int(sys.argv[1])
    format_simple_table(f'Error parsing tasks: {e}', term_width)
" "$term_width"
                ;;
            *)
                # Human-readable format (default)
                if [[ -z "$all_tasks" ]]; then
                    echo "No tasks found."
                else
                    echo "$all_tasks" | python3 -c "
$PYTHON_HELPERS
import json, sys
from datetime import datetime

try:
    all_tasks = []
    for line in sys.stdin:
        line = line.strip()
        if line:
            try:
                task = json.loads(line)
                all_tasks.append(task)
            except:
                pass
    
    if not all_tasks:
        print('No tasks found.')
        sys.exit(0)
    
    print(f'Found {len(all_tasks)} task(s) across all projects:')
    print('-' * 80)
    
    for task in all_tasks:
        title = task.get('title', 'No title')
        content = task.get('content', '')
        project_name = task.get('projectName', 'Unknown')
        tags = task.get('tags', [])
        task_status = task.get('status', 'Unknown')
        due_date = task.get('dueDate', '')
        priority = task.get('priority', 0)
        
        # Convert priority integer to string
        priority_map = {0: 'None', 1: 'Low', 3: 'Medium', 5: 'High'}
        priority_str = priority_map.get(priority, f'Unknown({priority})')
        
        print(f'ID: {task.get(\"id\", \"Unknown\")}')
        print(f'Title: {title}')
        print(f'Project: {project_name}')
        if content:
            print(f'Description: {content}')
        if tags:
            print(f'Tags: {\", \".join(tags)}')
        if due_date:
            try:
                dt = datetime.fromtimestamp(int(due_date) / 1000)
                print(f'Due: {dt.strftime(\"%Y-%m-%d %H:%M\")}')
            except:
                print(f'Due: {due_date}')
        print(f'Priority: {priority_str}')
        print(f'Status: {task_status}')
        print('-' * 80)
        
except Exception as e:
    print(f'Error parsing tasks: {e}')
"
                fi
                ;;
        esac
    fi
}

# Show all lists (projects)
lists() {
    # Default to table view
    local output_format="table"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --json)
                output_format="json"
                shift
                ;;
            --json-pretty)
                output_format="json-pretty"
                shift
                ;;
            # no --table option
            -*)
                echo "Error: Unknown option $1"
                return 1
                ;;
            *)
                echo "Error: Unexpected argument $1"
                return 1
                ;;
        esac
    done
    
    # Get all projects
    local response=$(curl -s -X GET "https://api.ticktick.com/open/v1/project" \
        -H "Authorization: Bearer $ACCESS_TOKEN")
    
    # Get Inbox data to count tasks
    local inbox_response=$(curl -s -X GET "https://api.ticktick.com/open/v1/project/inbox/data" \
        -H "Authorization: Bearer $ACCESS_TOKEN")
    
    # Parse and display projects (including Inbox first)
    case "$output_format" in
        json|json-pretty)
            echo "$response" | python3 -c "
$PYTHON_HELPERS
import json, sys

try:
    response_data = sys.stdin.read()
    projects = json.loads(response_data)
    
    # Get Inbox task count from second input
    inbox_data = sys.argv[1] if len(sys.argv) > 1 else '{}'
    inbox_tasks = []
    try:
        inbox_json = json.loads(inbox_data)
        inbox_tasks = inbox_json.get('tasks', [])
    except:
        pass
    
    # Create Inbox project entry
    inbox_project = {
        'id': 'inbox',
        'name': 'Inbox',
        'color': None,
        'viewMode': 'list',
        'kind': 'TASK',
        'taskCount': len(inbox_tasks)
    }
    
    # Add taskCount to regular projects
    for project in projects:
        project['taskCount'] = 0  # We don't have task counts for regular projects
    
    # Combine Inbox + regular projects
    all_projects = [inbox_project] + projects
    
    output = {
        'success': True,
        'count': len(all_projects),
        'projects': all_projects
    }
    
    indent = 2 if '$output_format' == 'json-pretty' else None
    print(json.dumps(output, indent=indent))
    
except Exception as e:
    print(json.dumps({'success': False, 'error': str(e)}, indent=2 if '$output_format' == 'json-pretty' else None))
" "$inbox_response"
            ;;
        table)
            local term_width=$(get_terminal_width)
            echo "$response" | python3 -c "
$PYTHON_HELPERS
import json, sys

try:
    response_data = sys.stdin.read()
    projects = json.loads(response_data)
    
    # Get Inbox task count from second input
    inbox_data = sys.argv[1] if len(sys.argv) > 1 else '{}'
    inbox_tasks = []
    try:
        inbox_json = json.loads(inbox_data)
        inbox_tasks = inbox_json.get('tasks', [])
    except:
        pass
    
    term_width = int(sys.argv[2])
    
    # Calculate total count
    total_count = len(projects) + 1  # +1 for Inbox
    
    # Build table
    top = '┌' + '─' * (term_width - 2) + '┐'
    header = '│ ' + f'Lists ({total_count})'.ljust(term_width - 4) + ' │'
    separator = '├' + '─' * (term_width - 2) + '┤'
    bottom = '└' + '─' * (term_width - 2) + '┘'
    
    print(top)
    print(header)
    print(separator)
    
    # Display Inbox first
    inbox_name = '● Inbox'
    print('│ ' + inbox_name.ljust(term_width - 4) + ' │')
    
    # Display regular projects
    for project in projects:
        name = strip_emojis(project.get('name', 'No name'))
        color = project.get('color', '')
        
        if color:
            colored_dot = colored_circle(color)
            display_name = f'{colored_dot} {name}'
        else:
            display_name = f'● {name}'
        
        # Calculate actual display width (without color codes)
        actual_width = len(display_name)
        # Remove color codes for width calculation
        import re
        color_codes_removed = re.sub(r'\033\[[0-9;]*m', '', display_name)
        actual_width = len(color_codes_removed)
        
        # Pad to full width
        padding_needed = term_width - 4 - actual_width
        if padding_needed > 0:
            display_name += ' ' * padding_needed
        
        print('│ ' + display_name + ' │')
    
    print(bottom)
    
except Exception as e:
    term_width = int(sys.argv[2])
    format_simple_table(f'Error parsing projects: {e}', term_width)
" "$inbox_response" "$term_width"
            ;;
        *)
            # Human-readable format (default)
            echo "$response" | python3 -c "
$PYTHON_HELPERS
import json, sys

try:
    response_data = sys.stdin.read()
    projects = json.loads(response_data)
    
    # Get Inbox task count from second input
    inbox_data = sys.argv[1] if len(sys.argv) > 1 else '{}'
    inbox_tasks = []
    try:
        inbox_json = json.loads(inbox_data)
        inbox_tasks = inbox_json.get('tasks', [])
    except:
        pass
    
    # Calculate total count (Inbox + regular projects)
    total_count = len(projects) + 1  # +1 for Inbox
    
    print(f'Found {total_count} project(s):')
    print('-' * 80)
    
    # Display Inbox first
    print('Name: Inbox')
    print('ID: inbox')
    print(f'Task Count: {len(inbox_tasks)}')
    print('View Mode: list')
    print('Kind: TASK')
    print('-' * 80)
    
    # Display regular projects
    for project in projects:
        name = project.get('name', 'No name')
        project_id = project.get('id', 'Unknown')
        color = project.get('color', '')
        view_mode = project.get('viewMode', 'Unknown')
        kind = project.get('kind', 'Unknown')
        
        print(f'Name: {name}')
        print(f'ID: {project_id}')
        if color:
            print(f'Color: {color}')
        print(f'View Mode: {view_mode}')
        print(f'Kind: {kind}')
        print('-' * 80)
        
except Exception as e:
    print(f'Error parsing projects: {e}')
    print('Raw response length:', len(response_data))
" "$inbox_response"
            ;;
    esac
}

# Create or check if list exists
create_or_check_list() {
    local name=""
    local color=""
    local update_mode=false
    local output_format="human"
    local new_name=""
    local provided_project_id=""
    
    # Parse arguments (collect name words until first option)
    local collected_name=""
    local parsing_name=true
    while [[ $# -gt 0 ]]; do
        case $1 in
            --id|-i)
                provided_project_id="$2"
                update_mode=true
                shift 2
                ;;
            --name|-n|--title)
                # Support unquoted multi-word new name: consume tokens until next option
                shift
                if [[ $# -eq 0 || "$1" == --* ]]; then
                    echo "Error: --name requires a value"
                    return 1
                fi
                new_name=""
                while [[ $# -gt 0 && "$1" != --* ]]; do
                    if [[ -z "$new_name" ]]; then
                        new_name="$1"
                    else
                        new_name+=" $1"
                    fi
                    shift
                done
                ;;
            --name|-n)
                name="$2"
                shift 2
                ;;
            --color)
                color="$2"
                shift 2
                ;;
            --update|-u)
                update_mode=true
                shift
                ;;
            --json|-j)
                output_format="json"
                shift
                ;;
            --json-pretty|-jp)
                output_format="json-pretty"
                shift
                ;;
            
            -*)
                echo "Error: Unknown option $1"
                return 1
                ;;
            --*)
                parsing_name=false
                ;;
            *)
                if $parsing_name; then
                    if [[ -z "$collected_name" ]]; then
                        collected_name="$1"
                    else
                        collected_name+=" $1"
                    fi
                    shift
                    continue
                else
                    shift
                    continue
                fi
                ;;
        esac
    done
    if [[ -z "$name" && -n "$collected_name" ]]; then
        name="$collected_name"
    fi
    
    if [[ -z "$name" && -z "$provided_project_id" ]]; then
        echo "Error: List name is required"
        return 1
    fi
    
    # Handle update mode
    if [[ "$update_mode" == true ]]; then
        # Find project by name or ID
        local project_id=""
        if [[ -n "$provided_project_id" ]]; then
            project_id="$provided_project_id"
        elif [[ -n "$name" && "$name" =~ ^[a-f0-9]{24}$ ]]; then
            project_id="$name"
        else
            # Search by name
            project_id=$(get_project_id "$name")
        fi
        
        if [[ -z "$project_id" ]]; then
            echo "Error: List '$name' not found"
            return 1
        fi
        
        # Get current project data
        local current_response=$(curl -s -X GET "https://api.ticktick.com/open/v1/project" \
            -H "Authorization: Bearer $ACCESS_TOKEN")
        
        local current_project=$(echo "$current_response" | python3 -c "
import json, sys
import re

def normalize_name(name):
    normalized = re.sub(r'[^a-zA-Z0-9_\- ]', '', name)
    return normalized.strip().lower()

try:
    projects = json.loads(sys.stdin.read())
    for project in projects:
        if project.get('id') == '$project_id':
            print(json.dumps(project))
            break
except:
    pass
")
        
        if [[ -z "$current_project" ]]; then
            echo "Error: Could not retrieve current project data"
            return 1
        fi
        
        # Build update payload (use new_name when provided)
        local update_payload=$(echo "$current_project" | python3 -c "
import json, sys

# Read current project
current = json.loads(sys.stdin.read())

# Update fields if new values provided
new_name = sys.argv[1]
if new_name:
    current['name'] = new_name
if '$color':
    current['color'] = '$color'

# Remove fields that shouldn't be in update
current.pop('etag', None)
current.pop('sortOrder', None)

print(json.dumps(current))
" "$new_name")
        
        # Update the project
        local update_response=$(curl -s -X POST "https://api.ticktick.com/open/v1/project/$project_id" \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$update_payload")
        
        local updated_project_id=$(get_json_value "$update_response" "id")
        if [[ -n "$updated_project_id" ]]; then
            # Format output based on format type
            case "$output_format" in
                json|json-pretty)
                    echo "$update_response" | python3 -c "
$PYTHON_HELPERS
import json, sys

try:
    project_data = json.loads(sys.stdin.read())
    output = {
        'success': True,
        'action': 'updated',
        'project': project_data
    }
    
    indent = 2 if '$output_format' == 'json-pretty' else None
    print(json.dumps(output, indent=indent))
except Exception as e:
    print(json.dumps({'success': False, 'error': str(e)}, indent=2 if '$output_format' == 'json-pretty' else None))
"
                    ;;
            table)
                    ;;
                *)
                    printf '\033[32mList updated successfully! ID: %s\033[0m\n' "$updated_project_id"
                    ;;
            esac
        else
            echo "Error: Failed to update list"
            echo "Response: $update_response"
            return 1
        fi
        
        return 0
    fi
    
    # Get all projects to check if exists
    local response=$(curl -s -X GET "https://api.ticktick.com/open/v1/project" \
        -H "Authorization: Bearer $ACCESS_TOKEN")
    
    # Check if project exists (case-insensitive with normalized names)
    local existing_project=$(python3 -c "
import json, sys
import re

def normalize_name(name):
    # Strip out all non a-zA-Z0-9_- and spaces, then trim whitespace
    normalized = re.sub(r'[^a-zA-Z0-9_\- ]', '', name)
    return normalized.strip().lower()

try:
    projects = json.loads(sys.argv[1])
    target_name = normalize_name(sys.argv[2])
    for project in projects:
        project_name = normalize_name(project.get('name', ''))
        if project_name == target_name:
            print(json.dumps(project))
            break
except:
    pass
" "$response" "$name")
    
    if [[ -n "$existing_project" ]]; then
        local project_name=$(python3 -c "
import json, sys
try:
    project = json.loads(sys.argv[1])
    print(project.get('name', ''))
except:
    print('')
" "$existing_project")
        echo "List '$project_name' already exists!"
        return 0
    fi
    
    # Create new project
    local payload=$(python3 -c "
import json
data = {
    'name': '$name',
    'viewMode': 'list',
    'kind': 'TASK'
}
if '$color':
    data['color'] = '$color'
print(json.dumps(data))
")
    
    local create_response=$(curl -s -X POST "https://api.ticktick.com/open/v1/project" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    local project_id=$(get_json_value "$create_response" "id")
    if [[ -n "$project_id" ]]; then
        # Format output based on format type
        case "$output_format" in
            json|json-pretty)
                echo "$create_response" | python3 -c "
$PYTHON_HELPERS
import json, sys

try:
    project_data = json.loads(sys.stdin.read())
    output = {
        'success': True,
        'action': 'created',
        'project': project_data
    }
    
    indent = 2 if '$output_format' == 'json-pretty' else None
    print(json.dumps(output, indent=indent))
except Exception as e:
    print(json.dumps({'success': False, 'error': str(e)}, indent=2 if '$output_format' == 'json-pretty' else None))
"
                ;;
            table)
                ;;
            *)
                printf '\033[32mList %s created successfully!\033[0m\n' "$name"
                ;;
        esac
    else
        echo "Error: Failed to create list '$name'"
        echo "Response: $create_response"
        return 1
    fi
}

# Show usage information
show_usage() {
    echo "TickTick CLI - Task Management"
    echo ""
    echo "Usage: $0 {task|complete|tasks|list|lists} [options]"
    echo ""
    echo "Commands:"
    echo "  task [title]                                 Add a new task"
    echo "    --name, -n     \"Name\"                      Task name (optional if first arg provided)"
    echo "    --content, -c  \"Text\"                      Task content/description (Markdown + newlines supported)"
    echo "    --list, -l     \"List Name\"                 Add to specific list"
    echo "    --priority, -p \"None|Low|Medium|High\"      Set priority (default: None)"
    echo "    --due, -d      \"yyyy-MM-dd'T'HH:mm:ss[Z]\"  Set due date"
    echo "    --tag, -t      \"Tag1,Tag2\"                 Add tags (comma-separated)"
    echo "    --id, -i       <taskId>                    Update by ID (implies --update)"
    echo "    --update, -u                               Update existing task instead of creating new"
    echo "    --json, -j                                 JSON output"
    echo "    --json-pretty, -jp                         Pretty JSON output"
    echo ""
    echo "  complete [name]                Mark task as complete"
    echo "    --name, -n     \"Name\"        Task name (optional if first arg provided)"
    echo "    --id, -i       <taskId>      Task ID to complete"
    echo "    --list, -l     \"List Name\"   List name (optional; scans all if omitted)"
    echo "    --tag, -t      \"Tag\"         Add tag after completion"
    echo "    --json, -j                   JSON output"
    echo "    --json-pretty, -jp           Pretty JSON output"
    echo ""
    echo "  tasks                          Show tasks"
    echo "    --list \"List Name\"           Filter by list"
    echo "    --status \"status\"            Filter by status (completed, pending, etc.)"
    echo ""
    echo "  list [name]                    Create new list or check if exists"
    echo "    --name, -n \"List Name\"       List name (optional if first arg provided) or new name when --update"
    echo "    --color \"#hexcolor\"          Set list color"
    echo "    --id, -i <projectId>         Update by ID (implies --update)"
    echo "    --update, -u                 Update existing list instead of creating new"
    echo "    --json, -j                   JSON output"
    echo "    --json-pretty, -jp           Pretty JSON output"
    echo ""
    echo "  lists                          Show all lists (projects)"
    echo ""
    echo "Examples:"
    echo " task \"Fix bug\" --description \"Details here\" --list \"Work\" --priority \"High\" --due \"2025-01-15T14:30:00\" --tag \"Bug,High Priority\""
    echo " task \"Make Something Awesome folk's\" --list Work"
    echo " complete Add Feature --list Home"
    echo " complete --id 617c54843c9fd1323e3900b0 --tag Done"
    echo " tasks --list \"Work\" --status completed"
    echo " list \"New Project\""
    echo " list --name \"Work\" --color \"#FF5733\""
    echo " list \"Work\" --update --color \"#FF0000\""
    echo " lists"
    echo ""
}

# =============================================================================
# MAIN SCRIPT LOGIC
# =============================================================================

# Check dependencies
check_dependencies

# Validate required credentials
missing=()
[[ -z "$CLIENT_ID" ]] && missing+=("CLIENT_ID")
[[ -z "$CLIENT_SECRET" ]] && missing+=("CLIENT_SECRET")
if ((${#missing[@]} > 0)); then
    echo "Error: Missing: ${missing[*]}"
    echo "Provide via environment variables or ${CONFIG_FILE}."
    echo "Examples:"
    echo "  export CLIENT_ID=... CLIENT_SECRET=..."
    echo "  echo 'CLIENT_ID=\"...\"' >> ${CONFIG_FILE}; chmod 600 ${CONFIG_FILE}"
    exit 1
fi

# Check authentication
if ! check_token; then
    if [[ -n "$REFRESH_TOKEN" ]]; then
        echo "Access token expired. Refreshing..."
        if ! refresh_access_token; then
            echo "Failed to refresh token. Starting new authentication..."
            initial_auth
        fi
    else
        initial_auth
    fi
fi

# Parse main command
case "$1" in
    task)
        shift
        task "$@"
        ;;
    complete)
        shift
        complete_task "$@"
        ;;
    tasks)
        shift
        tasks "$@"
        ;;
    list)
        shift
        create_or_check_list "$@"
        ;;
    lists)
        shift
        lists "$@"
        ;;
    help|--help|-h)
        show_usage
        ;;
    "")
        show_usage
        ;;
    *)
        echo "Error: Unknown command '$1'"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
