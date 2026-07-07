#!/bin/bash

# ── Claude Code Statusline ────────────────────────────────────────────
# Version: 0.2.0
# Configurable statusline for Claude Code.
# Run `bash configure.sh` to customize which segments are displayed.
# Config: ~/.claude/statusline-config.json

# Read JSON input from stdin
input=$(cat)

# ── Load configuration ────────────────────────────────────────────────
CONFIG_FILE="${STATUSLINE_CONFIG_FILE:-$HOME/.claude/statusline-config.json}"
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

# ── Parse Input Data ──────────────────────────────────────────────────
# Extract all values in a single jq pass to maximize performance
eval $(echo "$input" | jq -r '
    @sh "J_MODEL=\(.model.display_name // "")",
    @sh "J_EFFORT=\(.effort.level // "")",
    @sh "J_STYLE=\(.output_style.name // "")",
    @sh "J_CUR_DIR=\(.workspace.current_dir // "")",
    @sh "J_PROJ_DIR=\(.workspace.project_dir // "")",
    @sh "J_USED_PCT=\(.context_window.used_percentage // "")",
    @sh "J_REM_PCT=\(.context_window.remaining_percentage // "")",
    @sh "J_CTX_SIZE=\(.context_window.context_window_size // 0)",
    @sh "J_OLD_CACHE_CREATE=\(.context_window.current_usage.cache_creation_input_tokens // 0)",
    @sh "J_OLD_CACHE_READ=\(.context_window.current_usage.cache_read_input_tokens // 0)",
    @sh "J_OLD_INPUT=\(.context_window.current_usage.input_tokens // 0)",
    @sh "J_COST=\(.cost.total_cost_usd // 0)",
    @sh "J_DUR_MS=\(.cost.total_duration_ms // 0)",
    @sh "J_LINES_ADD=\(.cost.total_lines_added // 0)",
    @sh "J_LINES_REM=\(.cost.total_lines_removed // 0)",
    @sh "J_SESS_NAME=\(.session_name // "")",
    @sh "J_THINKING=\(.thinking.enabled // "")",
    @sh "J_VERSION=\(.version // "")",
    @sh "J_PR_NUM=\(.pr.number // "")",
    @sh "J_PR_STATE=\(.pr.review_state // "")",
    @sh "J_QUOTA_5H_PCT=\(.rate_limits.five_hour.used_percentage // "")",
    @sh "J_QUOTA_7D_PCT=\(.rate_limits.seven_day.used_percentage // "")",
    @sh "J_TOK_IN=\(.context_window.total_input_tokens // "")",
    @sh "J_TOK_OUT=\(.context_window.total_output_tokens // "")",
    @sh "J_OLD_TOK_IN=\(.context_window.current_usage.input_tokens // "")",
    @sh "J_OLD_TOK_OUT=\(.context_window.current_usage.output_tokens // "")",
    @sh "J_OLD_TOK_CACHED_CREATE=\(.context_window.current_usage.cache_creation_input_tokens // "")",
    @sh "J_OLD_TOK_CACHED_READ=\(.context_window.current_usage.cache_read_input_tokens // "")"
')

# Fallbacks for older Claude Code payload format where total input/output might not be top-level
if [[ -z "$J_TOK_IN" || "$J_TOK_IN" == "null" ]]; then J_TOK_IN=$J_OLD_TOK_IN; fi
if [[ -z "$J_TOK_OUT" || "$J_TOK_OUT" == "null" ]]; then J_TOK_OUT=$J_OLD_TOK_OUT; fi

# Calculate cached
J_TOK_CACHED=$(( ${J_OLD_TOK_CACHED_CREATE:-0} + ${J_OLD_TOK_CACHED_READ:-0} ))

# ── Terminal Width ────────────────────────────────────────────────────
get_terminal_width() {
    if [[ -n "$STATUSLINE_WIDTH" ]]; then echo "$STATUSLINE_WIDTH"; return; fi
    if [[ -n "$COLUMNS" && "$COLUMNS" =~ ^[0-9]+$ ]]; then echo "$COLUMNS"; return; fi
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then echo ""; return; fi
    
    local pid=$$
    local depth=0
    while [[ $depth -lt 8 ]]; do
        local parent_pid
        parent_pid=$(ps -o ppid= -p $pid 2>/dev/null | tr -d ' ')
        [[ -z "$parent_pid" ]] && break
        pid=$parent_pid
        
        local tty
        tty=$(ps -o tty= -p $pid 2>/dev/null | tr -d ' ')
        if [[ -n "$tty" && "$tty" != "??" && "$tty" != "?" ]]; then
            local dev="/dev/$tty"
            local width=""
            if width=$(stty -F "$dev" size 2>/dev/null | awk '{print $2}'); then
                [[ -n "$width" ]] && echo "$width" && return
            elif width=$(stty -f "$dev" size 2>/dev/null | awk '{print $2}'); then
                [[ -n "$width" ]] && echo "$width" && return
            fi
        fi
        depth=$((depth+1))
    done
    tput cols 2>/dev/null || echo ""
}

# ── Helpers ───────────────────────────────────────────────────────────

SEGMENT_ORDER=$(echo "$configured_segments" | jq -r '.[]')

is_enabled() {
    local s="$1"
    # Using space wrapping so we match exact segment names, preventing substring matches (e.g. "lines" matching "lines_added")
    [[ " $SEGMENT_ORDER " == *" $s "* ]]
}

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

format_tokens() {
    local count=$1
    if [[ -z "$count" || "$count" == "null" ]]; then echo ""; return; fi
    if [[ $count -lt 1000 ]]; then
        echo "$count"
    else
        local k=$((count / 1000))
        local d=$(((count % 1000) / 100))
        if [[ $d -eq 0 ]]; then
            echo "${k}k"
        else
            echo "${k}.${d}k"
        fi
    fi
}

# ── Segment renderers ─────────────────────────────────────────────────
# Each function prints its content (no leading/trailing pipe).
# The main loop adds separators between non-empty segments.

render_timestamp() {
    printf "$(printf '\033[36m')[%s]${RST}" "$(date +%H:%M:%S)"
}

render_model() {
    [[ -n "$J_MODEL" && "$J_MODEL" != "null" ]] && printf "$(printf '\033[34m')%s${RST}" "$J_MODEL"
}

render_effort() {
    [[ -n "$J_EFFORT" && "$J_EFFORT" != "null" ]] && printf "⚡%s" "$J_EFFORT"
}

render_style() {
    [[ -n "$J_STYLE" && "$J_STYLE" != "null" ]] && printf "$(printf '\033[33m')%s${RST}" "$J_STYLE"
}

render_directory() {
    local dir_display rel_path
    if [[ -n "$J_CUR_DIR" && "$J_CUR_DIR" != "null" ]]; then
        if [[ "$J_CUR_DIR" == "$J_PROJ_DIR"* ]] && [[ "$J_PROJ_DIR" != "null" ]] && [[ -n "$J_PROJ_DIR" ]]; then
            rel_path="${J_CUR_DIR#$J_PROJ_DIR}"
            if [[ -z "$rel_path" ]]; then
                dir_display="$(basename "$J_PROJ_DIR")"
            else
                dir_display="$(basename "$J_PROJ_DIR")$rel_path"
            fi
        else
            dir_display="$J_CUR_DIR"
        fi
        printf "$(printf '\033[32m')%s${RST}" "$dir_display"
    fi
}

render_git() {
    local branch git_status
    [[ -z "$J_CUR_DIR" || "$J_CUR_DIR" == "null" ]] && return
    git -C "$J_CUR_DIR" rev-parse --git-dir > /dev/null 2>&1 || return
    branch=$(git -C "$J_CUR_DIR" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
    [[ -z "$branch" ]] && return
    git_status=""
    git -C "$J_CUR_DIR" --no-optional-locks diff --quiet 2>/dev/null || git_status="${git_status}*"
    git -C "$J_CUR_DIR" --no-optional-locks diff --cached --quiet 2>/dev/null || git_status="${git_status}+"
    [[ -n $(git -C "$J_CUR_DIR" --no-optional-locks ls-files --others --exclude-standard 2>/dev/null) ]] && git_status="${git_status}?"
    printf "on $(printf '\033[35m')%s${RST}" "${branch}${git_status}"
}

render_context() {
    local pct remaining color bar size
    size=$J_CTX_SIZE
    if [[ -n "$J_USED_PCT" && "$J_USED_PCT" != "null" ]]; then
        pct=$(printf '%.0f' "$J_USED_PCT")
        [[ $pct -gt 100 ]] && pct=100
        color=$(pick_color "$pct")
        bar=$(build_bar "$pct" "$bar_width")
        if [[ -n "$J_REM_PCT" && "$J_REM_PCT" != "null" && "$size" != "0" && "$size" != "null" ]]; then
            remaining=$((size * ${J_REM_PCT%.*} / 100))
            if [[ "$remaining" -ge 1000 ]] 2>/dev/null; then
                printf "%s%s${RST} %s%% %sk left ctx" "$color" "$bar" "$pct" "$((remaining / 1000))"
                return
            fi
        fi
        printf "%s%s${RST} %s%% ctx" "$color" "$bar" "$pct"
    else
        local cache_total actual_tokens
        cache_total=$((J_OLD_CACHE_CREATE + J_OLD_CACHE_READ))
        if [[ $cache_total -gt 0 ]]; then actual_tokens=$cache_total
        else actual_tokens=$((J_OLD_INPUT + 53000)); fi
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
    local cost_display
    if (is_enabled "quota_5h" || is_enabled "quota_7d" || is_enabled "quota_5h_pct" || is_enabled "quota_7d_pct"); then
        if [[ -n "$J_QUOTA_5H_PCT" && "$J_QUOTA_5H_PCT" != "null" ]]; then return; fi
        if [[ -n "$J_QUOTA_7D_PCT" && "$J_QUOTA_7D_PCT" != "null" ]]; then return; fi
    fi
    [[ "$J_COST" == "0" || "$J_COST" == "null" ]] && return
    if (( $(echo "$J_COST < 0.01" | bc -l) )); then
        cost_display=$(printf "%.4f" "$J_COST")
    else
        cost_display=$(printf "%.2f" "$J_COST")
    fi
    printf "$(printf '\033[36m')\$%s${RST}" "$cost_display"
}

render_quota_5h() {
    local pct color bar
    [[ -z "$J_QUOTA_5H_PCT" || "$J_QUOTA_5H_PCT" == "null" ]] && return
    pct=$(printf '%.0f' "$J_QUOTA_5H_PCT")
    color=$(pick_color "$pct")
    bar=$(build_bar "$pct" "$quota_bar_width")
    printf "%s5h %s %s%%${RST}" "$color" "$bar" "$pct"
}

render_quota_7d() {
    local pct color bar
    [[ -z "$J_QUOTA_7D_PCT" || "$J_QUOTA_7D_PCT" == "null" ]] && return
    pct=$(printf '%.0f' "$J_QUOTA_7D_PCT")
    color=$(pick_color "$pct")
    bar=$(build_bar "$pct" "$quota_bar_width")
    printf "%s7d %s %s%%${RST}" "$color" "$bar" "$pct"
}

render_context_pct() {
    local pct remaining color size
    size=$J_CTX_SIZE
    if [[ -n "$J_USED_PCT" && "$J_USED_PCT" != "null" ]]; then
        pct=$(printf '%.0f' "$J_USED_PCT")
        [[ $pct -gt 100 ]] && pct=100
        color=$(pick_color "$pct")
        if [[ -n "$J_REM_PCT" && "$J_REM_PCT" != "null" && "$size" != "0" && "$size" != "null" ]]; then
            remaining=$((size * ${J_REM_PCT%.*} / 100))
            if [[ "$remaining" -ge 1000 ]] 2>/dev/null; then
                printf "Context: %s%s%% %sk left${RST}" "$color" "$pct" "$((remaining / 1000))"
                return
            fi
        fi
        printf "Context: %s%s%%${RST}" "$color" "$pct"
    else
        local cache_total actual_tokens
        cache_total=$((J_OLD_CACHE_CREATE + J_OLD_CACHE_READ))
        if [[ $cache_total -gt 0 ]]; then actual_tokens=$cache_total
        else actual_tokens=$((J_OLD_INPUT + 53000)); fi
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
    local pct color
    [[ -z "$J_QUOTA_5H_PCT" || "$J_QUOTA_5H_PCT" == "null" ]] && return
    pct=$(printf '%.0f' "$J_QUOTA_5H_PCT")
    color=$(pick_color "$pct")
    printf "%s5h %s%%${RST}" "$color" "$pct"
}

render_quota_7d_pct() {
    local pct color
    [[ -z "$J_QUOTA_7D_PCT" || "$J_QUOTA_7D_PCT" == "null" ]] && return
    pct=$(printf '%.0f' "$J_QUOTA_7D_PCT")
    color=$(pick_color "$pct")
    printf "%s7d %s%%${RST}" "$color" "$pct"
}

render_duration() {
    local sec
    [[ -z "$J_DUR_MS" || "$J_DUR_MS" == "null" || "$J_DUR_MS" == "0" ]] && return
    sec=$((J_DUR_MS / 1000))
    if [[ $sec -ge 3600 ]]; then
        printf "⏱ %dh%dm" "$((sec/3600))" "$(((sec%3600)/60))"
    elif [[ $sec -ge 60 ]]; then
        printf "⏱ %dm%ds" "$((sec/60))" "$((sec%60))"
    else
        printf "⏱ %ds" "$sec"
    fi
}

render_lines() {
    [[ "$J_LINES_ADD" == "0" && "$J_LINES_REM" == "0" ]] && return
    printf "$(printf '\033[32m')+%s${RST}/$(printf '\033[31m')-%s${RST}" "$J_LINES_ADD" "$J_LINES_REM"
}

render_session() {
    [[ -n "$J_SESS_NAME" && "$J_SESS_NAME" != "null" ]] && printf "📌 %s" "$J_SESS_NAME"
}

render_thinking() {
    [[ "$J_THINKING" == "true" ]] && printf "💭 on"
}

render_version() {
    [[ -n "$J_VERSION" && "$J_VERSION" != "null" ]] && printf "v%s" "$J_VERSION"
}

render_pr() {
    [[ -z "$J_PR_NUM" || "$J_PR_NUM" == "null" ]] && return
    case "$J_PR_STATE" in
        approved) printf "PR #%s $(printf '\033[32m')✓${RST}" "$J_PR_NUM" ;;
        changes_requested) printf "PR #%s $(printf '\033[31m')✗${RST}" "$J_PR_NUM" ;;
        draft) printf "PR #%s $(printf '\033[90m')draft${RST}" "$J_PR_NUM" ;;
        *) printf "PR #%s" "$J_PR_NUM" ;;
    esac
}

render_tokens_in() {
    local fmt; fmt=$(format_tokens "$J_TOK_IN")
    [[ -n "$fmt" ]] && printf "In: %s" "$fmt"
}

render_tokens_out() {
    local fmt; fmt=$(format_tokens "$J_TOK_OUT")
    [[ -n "$fmt" ]] && printf "Out: %s" "$fmt"
}

render_tokens_cached() {
    local fmt; fmt=$(format_tokens "$J_TOK_CACHED")
    [[ -n "$fmt" && "$J_TOK_CACHED" -gt 0 ]] && printf "Cache: %s" "$fmt"
}

render_tokens_total() {
    local total; total=$(( ${J_TOK_IN:-0} + ${J_TOK_OUT:-0} ))
    local fmt; fmt=$(format_tokens "$total")
    [[ -n "$fmt" && "$total" -gt 0 ]] && printf "Tok: %s" "$fmt"
}

render_cache_hit_rate() {
    local read=$J_OLD_CACHE_READ create=$J_OLD_CACHE_CREATE
    local denom=$((read + create))
    [[ $denom -le 0 ]] && return
    local pct; pct=$(awk -v r="$read" -v d="$denom" 'BEGIN{printf "%.1f", (r/d)*100}')
    printf "Cache Hit: %s%%" "$pct"
}

render_cache_read() {
    local read=$J_OLD_CACHE_READ create=$J_OLD_CACHE_CREATE input=$J_OLD_INPUT
    [[ -z "$read" || "$read" -le 0 ]] 2>/dev/null && return
    local fmt; fmt=$(format_tokens "$read")
    local denom=$((read + create + input))
    if [[ $denom -gt 0 ]]; then
        local pct; pct=$(awk -v r="$read" -v d="$denom" 'BEGIN{printf "%.0f", (r/d)*100}')
        printf "Cache Read: %s (%s%%)" "$fmt" "$pct"
    else
        printf "Cache Read: %s" "$fmt"
    fi
}

render_cache_write() {
    local read=$J_OLD_CACHE_READ create=$J_OLD_CACHE_CREATE input=$J_OLD_INPUT
    [[ -z "$create" || "$create" -le 0 ]] 2>/dev/null && return
    local fmt; fmt=$(format_tokens "$create")
    local denom=$((read + create + input))
    if [[ $denom -gt 0 ]]; then
        local pct; pct=$(awk -v c="$create" -v d="$denom" 'BEGIN{printf "%.0f", (c/d)*100}')
        printf "Cache Write: %s (%s%%)" "$fmt" "$pct"
    else
        printf "Cache Write: %s" "$fmt"
    fi
}

# ── Main render loop ──────────────────────────────────────────────────

TERM_WIDTH=$(get_terminal_width)

# Split into lines by "newline" marker
declare -a lines_arr
current_line=""
for seg in $SEGMENT_ORDER; do
    if [[ "$seg" == "newline" ]]; then
        lines_arr+=("$current_line")
        current_line=""
    else
        current_line="$current_line $seg"
    fi
done
lines_arr+=("$current_line")

for line_segs in "${lines_arr[@]}"; do
    line_out=""
    first_in_group=true
    flex_count=0
    prev_seg=""
    
    for seg in $line_segs; do
        output=""
        case "$seg" in
            flex)        output="__FLEX__"; flex_count=$((flex_count+1)) ;;
            timestamp)   output=$(render_timestamp) ;;
            model)       output=$(render_model) ;;
            effort)      output=$(render_effort) ;;
            style)       output=$(render_style) ;;
            directory)   output=$(render_directory) ;;
            git)         output=$(render_git) ;;
            context)     output=$(render_context) ;;
            context_pct) output=$(render_context_pct) ;;
            cost)        output=$(render_cost) ;;
            quota_5h)    output=$(render_quota_5h) ;;
            quota_5h_pct) output=$(render_quota_5h_pct) ;;
            quota_7d)    output=$(render_quota_7d) ;;
            quota_7d_pct) output=$(render_quota_7d_pct) ;;
            duration)    output=$(render_duration) ;;
            lines)       output=$(render_lines) ;;
            session)     output=$(render_session) ;;
            thinking)    output=$(render_thinking) ;;
            version)     output=$(render_version) ;;
            pr)          output=$(render_pr) ;;
            tokens_in)   output=$(render_tokens_in) ;;
            tokens_out)  output=$(render_tokens_out) ;;
            tokens_cached) output=$(render_tokens_cached) ;;
            tokens_total) output=$(render_tokens_total) ;;
            cache_hit_rate) output=$(render_cache_hit_rate) ;;
            cache_read) output=$(render_cache_read) ;;
            cache_write) output=$(render_cache_write) ;;
        esac

        if [[ -n "$output" ]]; then
            if [[ "$output" == "__FLEX__" ]]; then
                line_out="${line_out}__FLEX__"
                first_in_group=true
            elif $first_in_group; then
                line_out="${line_out}${output}"
                first_in_group=false
            else
                # Special cases: git follows directory, model follows timestamp
                if [[ "$seg" == "git" && "$prev_seg" == "directory" ]]; then
                    line_out="${line_out} ${output}"
                elif [[ "$seg" == "model" && "$prev_seg" == "timestamp" ]]; then
                    line_out="${line_out} ${output}"
                else
                    line_out="${line_out} | ${output}"
                fi
            fi
            prev_seg="$seg"
        fi
    done

    # If line is empty, skip
    [[ -z "$line_out" ]] && continue

    # Resolve flex spaces if any
    if [[ $flex_count -gt 0 ]]; then
        if [[ -n "$TERM_WIDTH" && "$TERM_WIDTH" -gt 0 ]]; then
            # visible length
            visible_text=$(echo -n "$line_out" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/__FLEX__//g')
            vlen=${#visible_text}
            
            # Claude Code applies some left margin (typically ~6 spaces)
            available=$((TERM_WIDTH - vlen - 6))
            [[ $available -lt 0 ]] && available=0
            
            line_out=$(echo -n "$line_out" | awk -v total="$available" -v count="$flex_count" '
            BEGIN {
               sp_per = int(total / count)
               rem = total % count
            }
            {
               res = ""
               while ((i = index($0, "__FLEX__")) > 0) {
                  curr_spaces = sp_per + (rem > 0 ? 1 : 0)
                  if (rem > 0) rem--
                  sp_str = ""
                  for(j=0; j<curr_spaces; j++) sp_str = sp_str " "
                  
                  res = res substr($0, 1, i-1) sp_str
                  $0 = substr($0, i+8)
               }
               res = res $0
               printf "%s", res
            }')
        else
            # unknown width, just convert flex to single space
            line_out="${line_out//__FLEX__/ }"
        fi
    fi

    # Truncate line if it exceeds terminal width
    if [[ -n "$TERM_WIDTH" && "$TERM_WIDTH" -gt 0 ]]; then
        visible_text=$(echo -n "$line_out" | sed 's/\x1b\[[0-9;]*m//g')
        vlen=${#visible_text}
        max_len=$((TERM_WIDTH - 6))
        
        if [[ $vlen -gt $max_len && $max_len -gt 3 ]]; then
            # Truncate using awk to handle ANSI codes properly
            line_out=$(echo -n "$line_out" | awk -v max="$((max_len - 3))" '
            {
                ansi = 0
                len = 0
                out = ""
                for(i=1; i<=length($0); i++) {
                    c = substr($0, i, 1)
                    if (c == "\033") ansi = 1
                    
                    if (ansi == 0) len++
                    
                    if (ansi == 0 && len > max) {
                        out = out "..."
                        break
                    }
                    out = out c
                    if (ansi == 1 && c == "m") ansi = 0
                }
                # append reset to be safe
                print out "\033[0m"
            }')
        fi
    fi

    # Print line with reset prefix and non-breaking spaces
    # awk replaces all regular spaces with \xc2\xa0 (UTF-8 non-breaking space)
    line_out=$(echo -n "$line_out" | awk '{gsub(/ /, "\xc2\xa0"); print}')

    printf "\033[0m%s\n" "$line_out"
done
