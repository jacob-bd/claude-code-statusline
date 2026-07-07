#!/bin/bash

# ── Claude Code Statusline Configurator ───────────────────────────────
# Version: 0.2.0
# Interactive wizard to customize which segments appear in the statusline.
# Usage: bash configure.sh
#
# Compatible with bash 3.2+ (macOS default) — no associative arrays.

CONFIG_FILE="$HOME/.claude/statusline-config.json"

# All available segments: id|label|preview (ANSI-colored)
# Using indexed arrays for bash 3.2 compatibility (macOS)
SEGMENT_COUNT=26
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

toggle_segment() {
    local s="$1"
    if is_enabled "$s"; then
        local new=()
        for e in "${enabled_segments[@]}"; do
            [[ "$e" != "$s" ]] && new+=("$e")
        done
        enabled_segments=("${new[@]}")
    else
        enabled_segments+=("$s")
    fi
}

# ── Render preview bar ────────────────────────────────────────────────

render_preview() {
    local first=true
    for s in "${enabled_segments[@]}"; do
        if [[ "$s" == "newline" ]]; then
            printf "\n   "
            first=true
            continue
        fi
        
        local preview
        preview=$(get_preview_for_id "$s")
        [[ -z "$preview" ]] && continue
        if $first; then
            printf "%b" "$preview"
            first=false
        elif [[ "$s" == "git" ]]; then
            printf " %b" "$preview"
        else
            printf " \033[90m|\033[0m %b" "$preview"
        fi
    done
}

# ── Save config ───────────────────────────────────────────────────────

save_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    local json_array=""
    for s in "${enabled_segments[@]}"; do
        if [[ -n "$json_array" ]]; then
            json_array="$json_array, \"$s\""
        else
            json_array="\"$s\""
        fi
    done
    printf '{\n  "segments": [%s],\n  "context_bar_width": 20,\n  "bar_width": 10\n}\n' "$json_array" > "$CONFIG_FILE"
}

# ── Draw wizard screen ────────────────────────────────────────────────

draw_screen() {
    printf '\033[2J\033[H'

    printf '\n'
    printf '  \033[1;36m╔══════════════════════════════════════════════════════╗\033[0m\n'
    printf '  \033[1;36m║\033[0m  \033[1mClaude Code Statusline Configurator\033[0m               \033[1;36m║\033[0m\n'
    printf '  \033[1;36m╚══════════════════════════════════════════════════════╝\033[0m\n\n'

    # Preview
    local cols width dashes i
    cols=$(tput cols 2>/dev/null || echo 80)
    width=$((cols - 6))
    [[ $width -lt 40 ]] && width=40

    printf "  \033[90m── Preview "
    dashes=$((width - 11))
    for ((i=0; i<dashes; i++)); do printf "─"; done
    printf "\033[0m\n"

    printf "   "
    render_preview
    printf "\n"

    printf "  \033[90m"
    for ((i=0; i<width; i++)); do printf "─"; done
    printf "\033[0m\n\n"

    # Width warning
    local raw_preview clean_preview max_len
    raw_preview=$(render_preview)
    clean_preview=$(echo -e "$raw_preview" | sed 's/\x1b\[[0-9;]*m//g')
    max_len=$(echo "$clean_preview" | awk '{print length}' | sort -nr | head -n1)
    if [[ $max_len -gt 85 ]]; then
        printf "  \033[33m⚠️  Warning: Longest line is (%d chars) and may truncate on narrow terminals.\033[0m\n" "$max_len"
        printf "  \033[33m   Consider disabling segments or using '%% only' versions to save space.\033[0m\n\n"
    fi

    printf '  Toggle segments by typing a number:\n\n'

    for ((i=0; i<SEGMENT_COUNT; i++)); do
        local id="${SEG_ID[$i]}"
        local label="${SEG_LABEL[$i]}"
        local preview="${SEG_PREVIEW[$i]}"
        local num=$((i + 1))

        if is_enabled "$id"; then
            printf "  \033[32m✓\033[0m %2d. \033[1m%-18s\033[0m " "$num" "$label"
        else
            printf "  \033[90m✗\033[0m %2d. \033[90m%-18s\033[0m " "$num" "$label"
        fi
        printf "%b" "$preview"
        printf '\n'
    done

    printf '\n'
    printf '  \033[90m────────────────────────────────────────────────────────────────────────\033[0m\n'
    printf '  \033[1m[1-25]\033[0m toggle  '
    printf '\033[1m[d]\033[0m defaults  '
    printf '\033[1m[p]\033[0m premium 2-line  '
    printf '\033[1m[s]\033[0m save & exit  '
    printf '\033[1m[q]\033[0m quit\n'
    printf '  \033[36m❯\033[0m '
}

# ── Main loop ─────────────────────────────────────────────────────────

main() {
    load_config

    while true; do
        draw_screen
        read -r choice

        case "$choice" in
            [1-9]|1[0-9]|2[0-9])
                local idx=$((choice - 1))
                if [[ $idx -ge 0 && $idx -lt $SEGMENT_COUNT ]]; then
                    toggle_segment "${SEG_ID[$idx]}"
                fi
                ;;
            d|D)
                enabled_segments=("${DEFAULT_SEGMENTS[@]}")
                ;;
            p|P)
                enabled_segments=("timestamp" "model" "style" "newline" "directory" "git" "flex" "tokens_in" "tokens_out" "cost")
                ;;
            s|S)
                save_config
                printf '\033[2J\033[H'
                printf '\n'
                printf '  \033[32m✓ Configuration saved to %s\033[0m\n\n' "$CONFIG_FILE"
                printf '  Your statusline will update on the next Claude Code prompt.\n\n'
                printf '  Enabled segments:\n'
                for s in "${enabled_segments[@]}"; do
                    printf '    • %s\n' "$s"
                done
                printf '\n'
                exit 0
                ;;
            q|Q)
                printf '\033[2J\033[H'
                printf '\n  Exited without saving.\n\n'
                exit 0
                ;;
        esac
    done
}

main
