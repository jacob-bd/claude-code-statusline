#!/bin/bash

# ── Claude Code Statusline Configurator ───────────────────────────────
# Version: 0.2.0
# Interactive wizard to customize which segments appear in the statusline.
# Usage: bash configure.sh
#
# Compatible with bash 3.2+ (macOS default) — no associative arrays.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${STATUSLINE_CONFIG_FILE:-$HOME/.claude/statusline-config.json}"

# All available segments: id|label|preview (ANSI-colored)
# Using indexed arrays for bash 3.2 compatibility (macOS)
SEGMENT_COUNT=33
SEG_ID=()
SEG_LABEL=()
SEG_PREVIEW=()

SEG_ID[0]="timestamp";   SEG_LABEL[0]="Timestamp";       SEG_PREVIEW[0]="\033[36m[10:05:06]\033[0m"
SEG_ID[1]="model";       SEG_LABEL[1]="Model";           SEG_PREVIEW[1]="\033[34mSonnet 5\033[0m"
SEG_ID[2]="effort";      SEG_LABEL[2]="Effort level";    SEG_PREVIEW[2]="⚡med"
SEG_ID[3]="style";       SEG_LABEL[3]="Output style";    SEG_PREVIEW[3]="\033[33mconcise\033[0m"
SEG_ID[4]="directory";   SEG_LABEL[4]="Directory";       SEG_PREVIEW[4]="\033[32mmy-project\033[0m"
SEG_ID[5]="git";         SEG_LABEL[5]="Git status";      SEG_PREVIEW[5]="on \033[35mmain*+\033[0m"
SEG_ID[6]="context";     SEG_LABEL[6]="Context window";  SEG_PREVIEW[6]="\033[33m[████████░░░░░░░░░░░░]\033[0m 42% 114k left ctx"
SEG_ID[7]="cost";        SEG_LABEL[7]="API Cost";        SEG_PREVIEW[7]="\033[36m\$0.85\033[0m"
SEG_ID[8]="quota_5h";    SEG_LABEL[8]="Quota 5h";        SEG_PREVIEW[8]="\033[32m5h [██░░░░░░░░] 24%\033[0m"
SEG_ID[9]="quota_7d";    SEG_LABEL[9]="Quota 7d";        SEG_PREVIEW[9]="\033[33m7d [████░░░░░░] 41%\033[0m"
SEG_ID[10]="duration";   SEG_LABEL[10]="Duration";       SEG_PREVIEW[10]="⏱ 2m34s"
SEG_ID[11]="lines";      SEG_LABEL[11]="Lines changed";  SEG_PREVIEW[11]="\033[32m+48\033[0m/\033[31m-12\033[0m"
SEG_ID[12]="session";    SEG_LABEL[12]="Session name";   SEG_PREVIEW[12]="📌 my-session"
SEG_ID[13]="thinking";   SEG_LABEL[13]="Thinking";       SEG_PREVIEW[13]="💭 on"
SEG_ID[14]="version";    SEG_LABEL[14]="Version";        SEG_PREVIEW[14]="v2.1.200"
SEG_ID[15]="pr";         SEG_LABEL[15]="PR info";        SEG_PREVIEW[15]="PR #42 \033[32m✓\033[0m"
SEG_ID[16]="context_pct";  SEG_LABEL[16]="Context % only";   SEG_PREVIEW[16]="Context: \033[33m42%\033[0m 114k left"
SEG_ID[17]="quota_5h_pct"; SEG_LABEL[17]="Quota 5h % only";  SEG_PREVIEW[17]="\033[32m5h 24%\033[0m"
SEG_ID[18]="quota_7d_pct"; SEG_LABEL[18]="Quota 7d % only";  SEG_PREVIEW[18]="\033[33m7d 41%\033[0m"
SEG_ID[19]="flex";         SEG_LABEL[19]="Flex spacer";      SEG_PREVIEW[19]="<--->"
SEG_ID[20]="newline";      SEG_LABEL[20]="New line";         SEG_PREVIEW[20]="[NEWLINE]"
SEG_ID[21]="tokens_in";    SEG_LABEL[21]="Tokens Input";     SEG_PREVIEW[21]="In: 15.2k"
SEG_ID[22]="tokens_out";   SEG_LABEL[22]="Tokens Output";    SEG_PREVIEW[22]="Out: 3.4k"
SEG_ID[23]="tokens_cached"; SEG_LABEL[23]="Tokens Cached";   SEG_PREVIEW[23]="Cache: 12k"
SEG_ID[24]="tokens_total"; SEG_LABEL[24]="Tokens Total";     SEG_PREVIEW[24]="Tok: 30.6k"
SEG_ID[25]="cache_hit_rate"; SEG_LABEL[25]="Cache Hit Rate"; SEG_PREVIEW[25]="Cache Hit: 87.0%"
SEG_ID[26]="cache_read"; SEG_LABEL[26]="Cache Read"; SEG_PREVIEW[26]="Cache Read: 12k (64%)"
SEG_ID[27]="cache_write"; SEG_LABEL[27]="Cache Write"; SEG_PREVIEW[27]="Cache Write: 3k (16%)"
SEG_ID[28]="quota_5h_reset"; SEG_LABEL[28]="Quota 5h Reset"; SEG_PREVIEW[28]="⏳ resets in 2h5m"
SEG_ID[29]="quota_7d_reset"; SEG_LABEL[29]="Quota 7d Reset"; SEG_PREVIEW[29]="⏳ resets in 2d3h"
SEG_ID[30]="vim_mode"; SEG_LABEL[30]="Vim Mode"; SEG_PREVIEW[30]="🔵 NORMAL"
SEG_ID[31]="worktree"; SEG_LABEL[31]="Git Worktree"; SEG_PREVIEW[31]="🌳 feature-x"
SEG_ID[32]="api_duration"; SEG_LABEL[32]="API Duration"; SEG_PREVIEW[32]="⏱ api 1m12s"

DEFAULT_SEGMENTS=(timestamp model style directory git context cost quota_5h quota_7d)

# Current state: ordered list of enabled segment IDs
enabled_segments=()

# ── Helpers ───────────────────────────────────────────────────────────

get_preview_for_id() {
    local id="$1"
    for ((i=0; i<SEGMENT_COUNT; i++)); do
        if [[ "${SEG_ID[$i]}" == "$id" ]]; then
            printf "%b" "${SEG_PREVIEW[$i]}"
            return
        fi
    done
}

get_label_for_id() {
    local id="$1"
    local i
    for ((i=0; i<SEGMENT_COUNT; i++)); do
        if [[ "${SEG_ID[$i]}" == "$id" ]]; then
            printf "%s" "${SEG_LABEL[$i]}"
            return
        fi
    done
}

format_enabled_row() {
    local idx="$1" id="$2" is_cursor="$3" is_moving="$4"
    local label preview marker
    label=$(get_label_for_id "$id")
    preview=$(get_preview_for_id "$id")
    if $is_moving; then
        marker="◆"
    elif $is_cursor; then
        marker="▸"
    else
        marker=" "
    fi
    printf "%s %2d. %-18s %b" "$marker" "$((idx+1))" "$label" "$preview"
}

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        local segs
        segs=$(jq -r '.segments[]' "$CONFIG_FILE" 2>/dev/null)
        if [[ -n "$segs" ]]; then
            enabled_segments=()
            while IFS= read -r s; do
                enabled_segments+=("$s")
            done <<< "$segs"
            return
        fi
    fi
    enabled_segments=("${DEFAULT_SEGMENTS[@]}")
}

is_enabled() {
    local s="$1"
    for e in "${enabled_segments[@]}"; do
        [[ "$e" == "$s" ]] && return 0
    done
    return 1
}

setup_terminal() {
    if [[ -t 0 ]]; then
        SAVED_STTY=$(stty -g 2>/dev/null || echo "")
        stty -icanon -echo min 1 time 0 2>/dev/null || true
    fi
}

restore_terminal() {
    if [[ -n "${SAVED_STTY:-}" ]]; then
        stty "$SAVED_STTY" 2>/dev/null || true
    fi
}

move_segment_up() {
    local idx=$1
    if [[ $idx -gt 0 ]]; then
        local tmp="${enabled_segments[$idx]}"
        enabled_segments[$idx]="${enabled_segments[$((idx-1))]}"
        enabled_segments[$((idx-1))]="$tmp"
        cursor=$((idx-1))
    fi
}

move_segment_down() {
    local idx=$1
    local last=$((${#enabled_segments[@]} - 1))
    if [[ $idx -lt $last ]]; then
        local tmp="${enabled_segments[$idx]}"
        enabled_segments[$idx]="${enabled_segments[$((idx+1))]}"
        enabled_segments[$((idx+1))]="$tmp"
        cursor=$((idx+1))
    fi
}

remove_segment_at() {
    local idx=$1
    local new=()
    local i
    for ((i=0; i<${#enabled_segments[@]}; i++)); do
        [[ $i -ne $idx ]] && new+=("${enabled_segments[$i]}")
    done
    enabled_segments=("${new[@]}")
    local last=$((${#enabled_segments[@]} - 1))
    [[ $cursor -gt $last ]] && cursor=$last
    [[ $cursor -lt 0 ]] && cursor=0
    return 0
}

append_segment() {
    local id="$1"
    enabled_segments+=("$id")
}

reset_to_defaults() {
    enabled_segments=("${DEFAULT_SEGMENTS[@]}")
    cursor=0
}

is_multi_allowed() {
    [[ "$1" == "flex" || "$1" == "newline" ]]
}

is_available_to_add() {
    local id="$1"
    is_multi_allowed "$id" && return 0
    is_enabled "$id" && return 1
    return 0
}

get_available_segment_ids() {
    local i id
    for ((i=0; i<SEGMENT_COUNT; i++)); do
        id="${SEG_ID[$i]}"
        is_available_to_add "$id" && printf "%s\n" "$id"
    done
}

read_key() {
    local key rest
    IFS= read -rsn1 key
    if [[ "$key" == $'\x1b' ]]; then
        if IFS= read -rsn1 -t 1 rest && [[ "$rest" == "[" ]]; then
            local rest2
            if IFS= read -rsn1 -t 1 rest2; then
                case "$rest2" in
                    A) echo "UP"; return ;;
                    B) echo "DOWN"; return ;;
                esac
            fi
        fi
        echo "ESC"
        return
    fi
    if [[ -z "$key" || "$key" == $'\n' || "$key" == $'\r' ]]; then
        echo "ENTER"
        return
    fi
    echo "CHAR:$key"
}

# ── Save config ───────────────────────────────────────────────────────

segments_to_json() {
    local json_array=""
    local s
    for s in "${enabled_segments[@]}"; do
        if [[ -n "$json_array" ]]; then
            json_array="$json_array, \"$s\""
        else
            json_array="\"$s\""
        fi
    done
    printf '{\n  "segments": [%s],\n  "context_bar_width": 20,\n  "bar_width": 10\n}\n' "$json_array"
}

save_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    segments_to_json > "$CONFIG_FILE"
}

build_mock_json() {
    local cwd; cwd=$(pwd)
    local five_h_reset seven_d_reset
    five_h_reset=$(( $(date +%s) + 7200 ))
    seven_d_reset=$(( $(date +%s) + 259200 ))
    cat <<JSON
{
  "model": {"display_name": "Sonnet 5"},
  "output_style": {"name": "concise"},
  "effort": {"level": "med"},
  "workspace": {"current_dir": "$cwd", "project_dir": "$cwd"},
  "context_window": {
    "used_percentage": 42,
    "remaining_percentage": 58,
    "context_window_size": 200000,
    "total_input_tokens": 15200,
    "total_output_tokens": 3400,
    "current_usage": {
      "input_tokens": 15200,
      "output_tokens": 3400,
      "cache_creation_input_tokens": 10000,
      "cache_read_input_tokens": 2000
    }
  },
  "cost": {"total_cost_usd": 0.85, "total_duration_ms": 154000, "total_api_duration_ms": 12000, "total_lines_added": 48, "total_lines_removed": 12},
  "session_name": "my-session",
  "thinking": {"enabled": true},
  "version": "2.1.200",
  "pr": {"number": 42, "review_state": "approved"},
  "rate_limits": {
    "five_hour": {"used_percentage": 24, "resets_at": $five_h_reset},
    "seven_day": {"used_percentage": 41, "resets_at": $seven_d_reset}
  },
  "vim": {"mode": "NORMAL"}
}
JSON
}

render_live_preview() {
    local tmp_config cols lines output
    tmp_config=$(mktemp)
    segments_to_json > "$tmp_config"
    cols=$(tput cols 2>/dev/null || echo 80)
    lines=$(tput lines 2>/dev/null || echo 24)
    output=$(build_mock_json | STATUSLINE_CONFIG_FILE="$tmp_config" COLUMNS="$cols" LINES="$lines" bash "$SCRIPT_DIR/statusline-command.sh" 2>/dev/null)
    rm -f "$tmp_config"
    printf '%s' "$output"
}

# render_live_preview shells out to a whole bash process (jq, tput, git...),
# so it's too slow to call on every redraw. Cursor movement alone never
# changes enabled_segments, so cache the rendered preview and only
# recompute it when the segment list actually changes.
get_cached_preview() {
    local key="${enabled_segments[*]}"
    if [[ "$key" != "${PREVIEW_CACHE_KEY:-}" ]]; then
        PREVIEW_CACHE=$(render_live_preview)
        PREVIEW_CACHE_KEY="$key"
    fi
    printf '%s' "$PREVIEW_CACHE"
}

# ── Draw wizard screen ────────────────────────────────────────────────

draw_main_screen() {
    local cur="$1" mode="$2"
    printf '\033[2J\033[H\n'
    printf '  \033[1;36m╔══════════════════════════════════════════════════════╗\033[0m\n'
    printf '  \033[1;36m║\033[0m  \033[1mClaude Code Statusline Configurator\033[0m               \033[1;36m║\033[0m\n'
    printf '  \033[1;36m╚══════════════════════════════════════════════════════╝\033[0m\n\n'

    printf '  \033[90m── Preview ──────────────────────────────────────────────\033[0m\n'
    printf '   '
    get_cached_preview
    printf '\n'
    printf '  \033[90m───────────────────────────────────────────────────────────\033[0m\n\n'

    if [[ "$mode" == "move" ]]; then
        printf '  Your statusline   \033[33m◆ moving \xe2\x80\x94 \xe2\x86\x91/\xe2\x86\x93 reposition, Enter/Esc to drop\033[0m\n\n'
    else
        printf '  Your statusline   \xe2\x86\x91/\xe2\x86\x93 select \xc2\xb7 Enter move \xc2\xb7 a add \xc2\xb7 d remove\n\n'
    fi

    local i=0
    local id
    for id in "${enabled_segments[@]}"; do
        local is_cursor=false is_moving=false
        [[ $i -eq $cur ]] && is_cursor=true
        [[ $i -eq $cur && "$mode" == "move" ]] && is_moving=true
        printf '  %s\n' "$(format_enabled_row "$i" "$id" "$is_cursor" "$is_moving")"
        i=$((i+1))
    done

    printf '\n  \033[1m[a]\033[0m add   \033[1m[r]\033[0m reset to defaults   \033[1m[s]\033[0m save & exit   \033[1m[q]\033[0m quit\n'
}

draw_picker_screen() {
    local sel="$1"
    printf '\033[2J\033[H\n'
    printf '  \033[1;36m── Add a segment \xe2\x80\x94 \xe2\x86\x91/\xe2\x86\x93 select \xc2\xb7 Enter add \xc2\xb7 Esc cancel \xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\033[0m\n\n'

    local available; available=($(get_available_segment_ids))
    local i=0
    local id
    for id in "${available[@]}"; do
        local label preview marker
        label=$(get_label_for_id "$id")
        preview=$(get_preview_for_id "$id")
        if [[ $i -eq $sel ]]; then marker="▸"; else marker=" "; fi
        printf "  %s %-20s %b\n" "$marker" "$label" "$preview"
        i=$((i+1))
    done
    if [[ ${#available[@]} -eq 0 ]]; then
        printf '  \033[90m(no segments available to add)\033[0m\n'
    fi
    printf '\n'
}

# ── Main loop ─────────────────────────────────────────────────────────

main() {
    trap restore_terminal EXIT
    setup_terminal
    load_config
    cursor=0
    local mode="normal"
    local picker_cursor=0

    while true; do
        if [[ "$mode" == "picker" ]]; then
            draw_picker_screen "$picker_cursor"
        else
            draw_main_screen "$cursor" "$mode"
        fi

        local key; key=$(read_key)

        if [[ "$mode" == "move" ]]; then
            case "$key" in
                UP) move_segment_up "$cursor" ;;
                DOWN) move_segment_down "$cursor" ;;
                ENTER|ESC) mode="normal" ;;
            esac
            continue
        fi

        if [[ "$mode" == "picker" ]]; then
            local available; available=($(get_available_segment_ids))
            local avail_count=${#available[@]}
            case "$key" in
                UP) [[ $picker_cursor -gt 0 ]] && picker_cursor=$((picker_cursor-1)) ;;
                DOWN) [[ $picker_cursor -lt $((avail_count-1)) ]] && picker_cursor=$((picker_cursor+1)) ;;
                ENTER)
                    if [[ $avail_count -gt 0 ]]; then
                        append_segment "${available[$picker_cursor]}"
                        cursor=$((${#enabled_segments[@]} - 1))
                    fi
                    mode="normal"
                    picker_cursor=0
                    ;;
                ESC) mode="normal"; picker_cursor=0 ;;
            esac
            continue
        fi

        case "$key" in
            UP) [[ $cursor -gt 0 ]] && cursor=$((cursor-1)) ;;
            DOWN) [[ $cursor -lt $((${#enabled_segments[@]} - 1)) ]] && cursor=$((cursor+1)) ;;
            ENTER) [[ ${#enabled_segments[@]} -gt 0 ]] && mode="move" ;;
            CHAR:a) mode="picker"; picker_cursor=0 ;;
            CHAR:d)
                [[ ${#enabled_segments[@]} -gt 0 ]] && remove_segment_at "$cursor"
                ;;
            CHAR:r) reset_to_defaults ;;
            CHAR:s)
                save_config
                printf '\033[2J\033[H\n'
                printf '  \033[32m\xe2\x9c\x93 Configuration saved to %s\033[0m\n\n' "$CONFIG_FILE"
                printf '  Your statusline will update on the next Claude Code prompt.\n\n'
                exit 0
                ;;
            CHAR:q)
                printf '\033[2J\033[H\n  Exited without saving.\n\n'
                exit 0
                ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
