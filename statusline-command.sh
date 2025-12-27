#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract basic information
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir')
model_name=$(echo "$input" | jq -r '.model.display_name')
output_style=$(echo "$input" | jq -r '.output_style.name')
version=$(echo "$input" | jq -r '.version')

# Get relative path if we're in a project
if [[ "$current_dir" == "$project_dir"* ]] && [[ "$project_dir" != "null" ]] && [[ -n "$project_dir" ]]; then
    rel_path="${current_dir#$project_dir}"
    if [[ -z "$rel_path" ]]; then
        dir_display="$(basename "$project_dir")"
    else
        dir_display="$(basename "$project_dir")$rel_path"
    fi
else
    dir_display="$current_dir"
fi

# Get git information (skip optional locks for performance)
git_info=""
if git -C "$current_dir" rev-parse --git-dir > /dev/null 2>&1; then
    # Get branch name
    branch=$(git -C "$current_dir" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
    
    # Get git status indicators
    git_status=""
    if [[ -n "$branch" ]]; then
        # Check for uncommitted changes
        if ! git -C "$current_dir" --no-optional-locks diff --quiet 2>/dev/null; then
            git_status="${git_status}*"
        fi
        
        # Check for staged changes
        if ! git -C "$current_dir" --no-optional-locks diff --cached --quiet 2>/dev/null; then
            git_status="${git_status}+"
        fi
        
        # Check for untracked files
        if [[ -n $(git -C "$current_dir" --no-optional-locks ls-files --others --exclude-standard 2>/dev/null) ]]; then
            git_status="${git_status}?"
        fi
        
        git_info=" on $(printf '\033[35m')${branch}${git_status}$(printf '\033[0m')"
    fi
fi

# Get session cost directly from Claude Code (already calculated across all models)
cost_info=""
total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

if [[ "$total_cost" != "0" ]] && [[ "$total_cost" != "null" ]]; then
    # Format cost nicely
    if (( $(echo "$total_cost < 0.01" | bc -l) )); then
        cost_display=$(printf "%.4f" "$total_cost")
    else
        cost_display=$(printf "%.2f" "$total_cost")
    fi
    cost_info=" $(printf '\033[36m')\$$cost_display$(printf '\033[0m')"
fi

# Calculate context window usage with visual progress bar
context_info=""
usage=$(echo "$input" | jq '.context_window.current_usage')
if [[ "$usage" != "null" ]]; then
    current=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
    size=$(echo "$input" | jq '.context_window.context_window_size')
    if [[ "$current" != "null" ]] && [[ "$size" != "null" ]] && [[ "$size" -gt 0 ]]; then
        pct=$((current * 100 / size))

        # Color code based on usage (conservative thresholds to account for hidden overhead)
        # JSON only shows ~50% of actual context (missing system/tools/MCP)
        # Green <25% (real ~50%), Yellow 25-40% (real ~65-80%), Red >40% (real ~80%+ autocompact zone)
        if [[ $pct -lt 25 ]]; then
            color='\033[32m'  # green
        elif [[ $pct -lt 40 ]]; then
            color='\033[33m'  # yellow
        else
            color='\033[31m'  # red
        fi

        # Create progress bar (20 characters wide)
        bar_width=20
        filled=$((pct * bar_width / 100))
        empty=$((bar_width - filled))

        # Build the bar with filled and empty sections
        bar="["
        for ((i=0; i<filled; i++)); do
            bar="${bar}█"
        done
        for ((i=0; i<empty; i++)); do
            bar="${bar}░"
        done
        bar="${bar}]"

        context_info=" $(printf "${color}")${bar}$(printf '\033[0m') ${pct}%"
    fi
fi

# Get timestamp
timestamp=$(date +"%H:%M:%S")

# Build the complete status line
# Format: [HH:MM:SS] model_name | output_style | directory git_info | context%
printf "$(printf '\033[36m')[%s]$(printf '\033[0m') " "$timestamp"
printf "$(printf '\033[34m')%s$(printf '\033[0m') " "$model_name"

if [[ "$output_style" != "null" ]] && [[ -n "$output_style" ]]; then
    printf "| $(printf '\033[33m')%s$(printf '\033[0m') " "$output_style"
fi

printf "| $(printf '\033[32m')%s$(printf '\033[0m')%s" "$dir_display" "$git_info"

if [[ -n "$context_info" ]]; then
    printf " |%s ctx" "$context_info"
fi

if [[ -n "$cost_info" ]]; then
    printf " |%s" "$cost_info"
fi

printf "\n"
