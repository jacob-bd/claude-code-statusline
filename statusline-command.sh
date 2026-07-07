#!/bin/bash

# ── Claude Code Statusline ────────────────────────────────────────────
# Configurable statusline for Claude Code.
# Run `bash configure.sh` to customize which segments are displayed.
# Config: ~/.claude/statusline-config.json

# Read JSON input from stdin
input=$(cat)

# ── Load configuration ────────────────────────────────────────────────
CONFIG_FILE="$HOME/.claude/statusline-config.json"
DEFAULT_SEGMENTS='["timestamp","model","style","directory","git","context","cost","quota_5h","quota_7d"]'

if [[ -f "$CONFIG_FILE" ]]; then
    configured_segments=$(jq -r '.segments // empty' "$CONFIG_FILE" 2>/dev/null)
    bar_width=$(jq -r '.context_bar_width // 20' "$CONFIG_FILE" 2>/dev/null)
    quota_bar_width=$(jq -r '.bar_width // 10' "$CONFIG_FILE" 2>/dev/null)
fi
# Fall back to defaults
if [[ -z "$configured_segments" || "$configured_segments" == "null" ]]; then
    configured_segments="$DEFAULT_SEGMENTS"
fi
bar_width=${bar_width:-20}
quota_bar_width=${quota_bar_width:-10}

# Check if a segment is enabled
is_enabled() {
    echo "$configured_segments" | jq -e --arg s "$1" 'index($s) != null' >/dev/null 2>&1
}

# ── Helpers ───────────────────────────────────────────────────────────

build_bar() {
    local pct=$1 width=${2:-10}
    local filled=$((pct * width / 100))
    local empty=$((width - filled))
    local bar="["
    for ((i=0; i<filled; i++)); do bar="${bar}█"; done
    for ((i=0; i<empty; i++)); do bar="${bar}░"; done
    printf '%s]' "$bar"
}

pick_color() {
    local pct=$1
    if [[ $pct -lt 50 ]]; then printf '\033[32m'
    elif [[ $pct -lt 75 ]]; then printf '\033[33m'
    else printf '\033[31m'; fi
}

RST=$(printf '\033[0m')

# ── Segment renderers ─────────────────────────────────────────────────
# Each function prints its content (no leading/trailing pipe).
# The main loop adds separators between non-empty segments.

render_timestamp() {
    printf "$(printf '\033[36m')[%s]${RST}" "$(date +%H:%M:%S)"
}

render_model() {
    local name
    name=$(echo "$input" | jq -r '.model.display_name // empty')
    [[ -n "$name" && "$name" != "null" ]] && printf "$(printf '\033[34m')%s${RST}" "$name"
}

render_effort() {
    local level
    level=$(echo "$input" | jq -r '.effort.level // empty')
    [[ -n "$level" && "$level" != "null" ]] && printf "⚡%s" "$level"
}

render_style() {
    local style
    style=$(echo "$input" | jq -r '.output_style.name // empty')
    [[ -n "$style" && "$style" != "null" ]] && printf "$(printf '\033[33m')%s${RST}" "$style"
}

render_directory() {
    local current_dir project_dir dir_display rel_path
    current_dir=$(echo "$input" | jq -r '.workspace.current_dir // empty')
    project_dir=$(echo "$input" | jq -r '.workspace.project_dir // empty')
    if [[ -n "$current_dir" && "$current_dir" != "null" ]]; then
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
        printf "$(printf '\033[32m')%s${RST}" "$dir_display"
    fi
}

render_git() {
    local current_dir branch git_status
    current_dir=$(echo "$input" | jq -r '.workspace.current_dir // empty')
    [[ -z "$current_dir" || "$current_dir" == "null" ]] && return
    git -C "$current_dir" rev-parse --git-dir > /dev/null 2>&1 || return
    branch=$(git -C "$current_dir" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
    [[ -z "$branch" ]] && return
    git_status=""
    git -C "$current_dir" --no-optional-locks diff --quiet 2>/dev/null || git_status="${git_status}*"
    git -C "$current_dir" --no-optional-locks diff --cached --quiet 2>/dev/null || git_status="${git_status}+"
    [[ -n $(git -C "$current_dir" --no-optional-locks ls-files --others --exclude-standard 2>/dev/null) ]] && git_status="${git_status}?"
    printf "on $(printf '\033[35m')%s${RST}" "${branch}${git_status}"
}

render_context() {
    local used_pct pct remaining_pct size remaining color bar remaining_display
    used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
    if [[ -n "$used_pct" && "$used_pct" != "null" ]]; then
        pct=$(printf '%.0f' "$used_pct")
        [[ $pct -gt 100 ]] && pct=100
        remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
        size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
        color=$(pick_color "$pct")
        bar=$(build_bar "$pct" "$bar_width")
        if [[ -n "$remaining_pct" && "$remaining_pct" != "null" && "$size" != "0" && "$size" != "null" ]]; then
            remaining=$((size * ${remaining_pct%.*} / 100))
            if [[ "$remaining" -ge 1000 ]] 2>/dev/null; then
                printf "%s%s${RST} %s%% %sk left ctx" "$color" "$bar" "$pct" "$((remaining / 1000))"
                return
            fi
        fi
        printf "%s%s${RST} %s%% ctx" "$color" "$bar" "$pct"
    else
        # Fallback for old Claude Code versions
        local usage cache_creation cache_read input_tokens cache_total actual_tokens
        usage=$(echo "$input" | jq '.context_window.current_usage')
        [[ "$usage" == "null" ]] && return
        cache_creation=$(echo "$usage" | jq '.cache_creation_input_tokens // 0')
        cache_read=$(echo "$usage" | jq '.cache_read_input_tokens // 0')
        input_tokens=$(echo "$usage" | jq '.input_tokens // 0')
        cache_total=$((cache_creation + cache_read))
        if [[ $cache_total -gt 0 ]]; then actual_tokens=$cache_total
        else actual_tokens=$((input_tokens + 53000)); fi
        size=$(echo "$input" | jq '.context_window.context_window_size')
        [[ "$size" == "null" || "$size" -le 0 ]] 2>/dev/null && return
        pct=$((actual_tokens * 100 / size))
        [[ $pct -gt 100 ]] && pct=100
        remaining=$((size - actual_tokens))
        [[ $remaining -lt 0 ]] && remaining=0
        color=$(pick_color "$pct")
        bar=$(build_bar "$pct" "$bar_width")
        if [[ $remaining -ge 1000 ]]; then
            printf "%s%s${RST} %s%% %sk left ctx" "$color" "$bar" "$pct" "$((remaining / 1000))"
        else
            printf "%s%s${RST} %s%% ctx" "$color" "$bar" "$pct"
        fi
    fi
}

render_cost() {
    local total_cost cost_display
    # If quota segments are enabled AND rate_limits data exists, skip cost
    if (is_enabled "quota_5h" || is_enabled "quota_7d" || is_enabled "quota_5h_pct" || is_enabled "quota_7d_pct"); then
        local has_quota
        has_quota=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // .rate_limits.seven_day.used_percentage // empty')
        [[ -n "$has_quota" && "$has_quota" != "null" ]] && return
    fi
    total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
    [[ "$total_cost" == "0" || "$total_cost" == "null" ]] && return
    if (( $(echo "$total_cost < 0.01" | bc -l) )); then
        cost_display=$(printf "%.4f" "$total_cost")
    else
        cost_display=$(printf "%.2f" "$total_cost")
    fi
    printf "$(printf '\033[36m')\$%s${RST}" "$cost_display"
}

render_quota_5h() {
    local pct_raw pct color bar
    pct_raw=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
    [[ -z "$pct_raw" || "$pct_raw" == "null" ]] && return
    pct=$(printf '%.0f' "$pct_raw")
    color=$(pick_color "$pct")
    bar=$(build_bar "$pct" "$quota_bar_width")
    printf "%s5h %s %s%%${RST}" "$color" "$bar" "$pct"
}

render_quota_7d() {
    local pct_raw pct color bar
    pct_raw=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
    [[ -z "$pct_raw" || "$pct_raw" == "null" ]] && return
    pct=$(printf '%.0f' "$pct_raw")
    color=$(pick_color "$pct")
    bar=$(build_bar "$pct" "$quota_bar_width")
    printf "%s7d %s %s%%${RST}" "$color" "$bar" "$pct"
}

render_context_pct() {
    local used_pct pct remaining_pct size remaining color remaining_display
    used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
    if [[ -n "$used_pct" && "$used_pct" != "null" ]]; then
        pct=$(printf '%.0f' "$used_pct")
        [[ $pct -gt 100 ]] && pct=100
        remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
        size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
        color=$(pick_color "$pct")
        if [[ -n "$remaining_pct" && "$remaining_pct" != "null" && "$size" != "0" && "$size" != "null" ]]; then
            remaining=$((size * ${remaining_pct%.*} / 100))
            if [[ "$remaining" -ge 1000 ]] 2>/dev/null; then
                printf "Context: %s%s%% %sk left${RST}" "$color" "$pct" "$((remaining / 1000))"
                return
            fi
        fi
        printf "Context: %s%s%%${RST}" "$color" "$pct"
    else
        local usage cache_creation cache_read input_tokens cache_total actual_tokens
        usage=$(echo "$input" | jq '.context_window.current_usage')
        [[ "$usage" == "null" ]] && return
        cache_creation=$(echo "$usage" | jq '.cache_creation_input_tokens // 0')
        cache_read=$(echo "$usage" | jq '.cache_read_input_tokens // 0')
        input_tokens=$(echo "$usage" | jq '.input_tokens // 0')
        cache_total=$((cache_creation + cache_read))
        if [[ $cache_total -gt 0 ]]; then actual_tokens=$cache_total
        else actual_tokens=$((input_tokens + 53000)); fi
        size=$(echo "$input" | jq '.context_window.context_window_size')
        [[ "$size" == "null" || "$size" -le 0 ]] 2>/dev/null && return
        pct=$((actual_tokens * 100 / size))
        [[ $pct -gt 100 ]] && pct=100
        remaining=$((size - actual_tokens))
        [[ $remaining -lt 0 ]] && remaining=0
        color=$(pick_color "$pct")
        if [[ $remaining -ge 1000 ]]; then
            printf "Context: %s%s%% %sk left${RST}" "$color" "$pct" "$((remaining / 1000))"
        else
            printf "Context: %s%s%%${RST}" "$color" "$pct"
        fi
    fi
}

render_quota_5h_pct() {
    local pct_raw pct color
    pct_raw=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
    [[ -z "$pct_raw" || "$pct_raw" == "null" ]] && return
    pct=$(printf '%.0f' "$pct_raw")
    color=$(pick_color "$pct")
    printf "%s5h %s%%${RST}" "$color" "$pct"
}

render_quota_7d_pct() {
    local pct_raw pct color
    pct_raw=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
    [[ -z "$pct_raw" || "$pct_raw" == "null" ]] && return
    pct=$(printf '%.0f' "$pct_raw")
    color=$(pick_color "$pct")
    printf "%s7d %s%%${RST}" "$color" "$pct"
}

render_duration() {
    local ms sec
    ms=$(echo "$input" | jq -r '.cost.total_duration_ms // empty')
    [[ -z "$ms" || "$ms" == "null" || "$ms" == "0" ]] && return
    sec=$((ms / 1000))
    if [[ $sec -ge 3600 ]]; then
        printf "⏱ %dh%dm" "$((sec/3600))" "$(((sec%3600)/60))"
    elif [[ $sec -ge 60 ]]; then
        printf "⏱ %dm%ds" "$((sec/60))" "$((sec%60))"
    else
        printf "⏱ %ds" "$sec"
    fi
}

render_lines() {
    local added removed
    added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
    removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
    [[ "$added" == "0" && "$removed" == "0" ]] && return
    printf "$(printf '\033[32m')+%s${RST}/$(printf '\033[31m')-%s${RST}" "$added" "$removed"
}

render_session() {
    local name
    name=$(echo "$input" | jq -r '.session_name // empty')
    [[ -n "$name" && "$name" != "null" ]] && printf "📌 %s" "$name"
}

render_thinking() {
    local enabled
    enabled=$(echo "$input" | jq -r '.thinking.enabled // empty')
    [[ "$enabled" == "true" ]] && printf "💭 on"
}

render_version() {
    local ver
    ver=$(echo "$input" | jq -r '.version // empty')
    [[ -n "$ver" && "$ver" != "null" ]] && printf "v%s" "$ver"
}

render_pr() {
    local pr_num review
    pr_num=$(echo "$input" | jq -r '.pr.number // empty')
    [[ -z "$pr_num" || "$pr_num" == "null" ]] && return
    review=$(echo "$input" | jq -r '.pr.review_state // empty')
    case "$review" in
        approved) printf "PR #%s $(printf '\033[32m')✓${RST}" "$pr_num" ;;
        changes_requested) printf "PR #%s $(printf '\033[31m')✗${RST}" "$pr_num" ;;
        draft) printf "PR #%s $(printf '\033[90m')draft${RST}" "$pr_num" ;;
        *) printf "PR #%s" "$pr_num" ;;
    esac
}

# ── Main render loop ──────────────────────────────────────────────────
# Walk through configured segments in order, render each, join with " | "

SEGMENT_ORDER=$(echo "$configured_segments" | jq -r '.[]')
first=true

for seg in $SEGMENT_ORDER; do
    output=""
    case "$seg" in
        timestamp)  output=$(render_timestamp) ;;
        model)      output=$(render_model) ;;
        effort)     output=$(render_effort) ;;
        style)      output=$(render_style) ;;
        directory)  output=$(render_directory) ;;
        git)        output=$(render_git) ;;
        context)    output=$(render_context) ;;
        context_pct) output=$(render_context_pct) ;;
        cost)       output=$(render_cost) ;;
        quota_5h)   output=$(render_quota_5h) ;;
        quota_5h_pct) output=$(render_quota_5h_pct) ;;
        quota_7d)   output=$(render_quota_7d) ;;
        quota_7d_pct) output=$(render_quota_7d_pct) ;;
        duration)   output=$(render_duration) ;;
        lines)      output=$(render_lines) ;;
        session)    output=$(render_session) ;;
        thinking)   output=$(render_thinking) ;;
        version)    output=$(render_version) ;;
        pr)         output=$(render_pr) ;;
    esac

    if [[ -n "$output" ]]; then
        if $first; then
            printf "%s" "$output"
            first=false
        else
            # Special case: git follows directory without a pipe separator
            if [[ "$seg" == "git" ]]; then
                printf " %s" "$output"
            else
                printf " | %s" "$output"
            fi
        fi
    fi
done

printf "\n"
