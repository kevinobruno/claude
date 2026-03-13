#!/bin/bash
# Claude Code statusline - Optimized version (<100ms target)
# Line 1: Context bar with model and usage percentage
# Line 2: [user][host][branch info][path]
# Line 3: [SESSION id][msg|tools][$cost][duration][+lines/-lines]
#
# Session cost: Uses official .cost.total_cost_usd from Claude Code input
# (No need for hardcoded rate tables - Anthropic calculates this server-side)

# ==================== COLORS (Mairan Theme) ====================
# Bold colors matching ~/.oh-my-bash/themes/mairan/mairan.theme.sh
O="\033[1;33m"  # Orange - brackets, host
G="\033[1;32m"  # Green - user, branch, clean status, path
Y="\033[0;33m"  # Yellow/Brown - dirty status, warnings
R="\033[0;31m"  # Red - errors, critical
P="\033[1;35m"  # Purple - model name, system/Claude context
D="\033[0;90m"  # Dim - secondary info
C="\033[0;36m"  # Cyan - unused
W="\033[0;37m"  # Gray/White - initial startup context
Z="\033[0m"     # Reset

# ==================== CONSTANTS ====================
TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
BAR_LEN=12                    # Total bar character width (for inline bar)
BAR_RESERVED=3                # Reserved chars for autocompact zone (~25%)
BAR_USABLE=9                  # Chars for actual usage (BAR_LEN - BAR_RESERVED)
CTX_WINDOW=200000             # Context window size
CTX_RESERVED=50000            # Autocompact zone (~25%)
CTX_USABLE=150000             # Usable context (CTX_WINDOW - CTX_RESERVED)
# Thresholds: 30% degraded, 65% warning, 70% critical, 75% compacting

# Shade density for granular bar animation (1/4 to 4/4)
SHADE_BLOCKS=("" "░" "▒" "▓")

# ==================== PLATFORM COMPATIBILITY ====================
# date commands differ between GNU (Linux) and BSD (macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
  date_to_epoch() { date -j -f "%Y-%m-%dT%H:%M:%S" "${1%%.*}" +%s 2>/dev/null || echo 0; }
  date_fmt() { date -j -f "%Y-%m-%d" "$1" "+%b %d, %Y" 2>/dev/null || echo "$1"; }
else
  date_to_epoch() { date -d "$1" +%s 2>/dev/null || echo 0; }
  date_fmt() { date -d "$1" "+%b %d, %Y" 2>/dev/null || echo "$1"; }
fi

# ==================== HELPER FUNCTIONS ====================
fmt_tok() {
  local t=$1
  [[ -z "$t" || "$t" == "null" || "$t" == "0" ]] && echo "0" && return
  ((t >= 1000000000)) && printf "%.1fB" "$(bc -l <<< "$t/1000000000")" && return
  ((t >= 1000000)) && printf "%.1fM" "$(bc -l <<< "$t/1000000")" && return
  ((t >= 1000)) && printf "%.0fk" "$(bc -l <<< "$t/1000")" && return
  echo "$t"
}

fmt_comma() {
  local n="${1:-0}" result="" len i
  n="${n%.*}"  # Remove decimal part
  [[ -z "$n" || "$n" == "0" ]] && echo "0" && return
  len=${#n}
  for ((i=0; i<len; i++)); do
    ((i > 0 && (len-i) % 3 == 0)) && result+=","
    result+="${n:$i:1}"
  done
  echo "${result:-0}"
}

fmt_dur() {
  local s=$1
  [[ -z "$s" || "$s" == "0" ]] && echo "0m" && return
  local m=$((s/60)) h=$((s/3600)) d=$((s/86400))
  ((d > 0)) && echo "${d}d $((h%24))h" && return
  ((h > 0)) && echo "${h}h $((m%60))m" && return
  echo "${m}m"
}

# Get baseline context (first message's cached content = system overhead)
# Includes both cache_read (cache hit) and cache_creation (cache miss)
get_baseline_tokens() {
  local transcript="$1"
  head -50 "$transcript" | jq -s -r '
    [.[] | .message.usage | select(.) |
      ((.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0))
    ][0] // 0
  ' 2>/dev/null || echo 0
}

# Build context bar from token counts
# Args: $1=initial_tokens (baseline), $2=ours_tokens (growth above baseline)
# Output: colored bar string with smooth fill - each position fills completely before next starts
mk_ctx_bar() {
  local initial=${1:-0} ours=${2:-0}
  local usable=$BAR_USABLE reserved=$BAR_RESERVED
  local quarters=$((usable * 4))

  # Convert tokens to quarters
  local init_q=0 ours_q=0
  if ((initial > 0)); then
    init_q=$(( (initial * quarters + CTX_USABLE - 1) / CTX_USABLE ))
    ((init_q > quarters)) && init_q=$quarters
  fi
  if ((ours > 0)); then
    ours_q=$(( (ours * quarters + CTX_USABLE - 1) / CTX_USABLE ))
    ((ours_q > quarters - init_q)) && ours_q=$((quarters - init_q))
  fi

  # Color based on proximity to autocompact zone (75% of window)
  # Green until 50%, then Yellow (warning), Orange (critical), Red (compacting)
  local total=$((initial + ours))
  local pct=$((total * 100 / CTX_WINDOW))
  local ours_color="$G"
  ((pct >= 50)) && ours_color="$Y"
  ((pct >= 65)) && ours_color="$O"
  ((pct >= 75)) && ours_color="$R"

  # Build bar position by position
  local bar=""
  for ((pos=0; pos<usable; pos++)); do
    local pos_start=$((pos * 4))
    local pos_end=$((pos_start + 4))

    if ((init_q >= pos_end)); then
      # Fully purple (system/Claude context)
      bar+="${P}▓${Z}"
    elif ((init_q > pos_start)); then
      # Partial purple
      local fill=$((init_q - pos_start))
      bar+="${P}${SHADE_BLOCKS[$fill]}${Z}"
    elif ((init_q + ours_q >= pos_end)); then
      # Fully green
      bar+="${ours_color}█${Z}"
    elif ((init_q + ours_q > pos_start)); then
      # Partial green
      local fill=$((init_q + ours_q - pos_start))
      bar+="${ours_color}${SHADE_BLOCKS[$fill]}${Z}"
    else
      # Empty
      bar+="${D}░${Z}"
    fi
  done

  # Threshold marker and reserved segment
  local marker="${D}│${Z}"
  local res_bar=""
  ((reserved > 0)) && res_bar=$(printf '▒%.0s' $(seq 1 $reserved))

  echo "${bar}${marker}${R}${res_bar}${Z}"
}

# Build full-width context bar for prominent display
# Args: $1=initial_tokens, $2=ours_tokens, $3=model, $4=pct
mk_full_ctx_bar() {
  local initial=${1:-0} ours=${2:-0} model=${3:-""} pct=${4:-0}

  # Calculate bar width: terminal width minus decorations
  local decor_len=20
  local bar_total=$((TERM_WIDTH - decor_len))
  ((bar_total < 20)) && bar_total=20
  ((bar_total > 120)) && bar_total=120

  # Calculate separator positions (leaving room for 2 separator chars)
  local bar_width=$((bar_total - 2))
  local pos_50=$((bar_width * 50 / 100))
  local pos_75=$((bar_width * 75 / 100))

  # Calculate filled width based on percentage (round to nearest)
  local filled=$(( (bar_width * pct + 50) / 100 ))
  ((filled > bar_width)) && filled=$bar_width

  # Whole bar color based on thresholds
  local bar_color="$G"
  ((pct > 50)) && bar_color="$Y"
  ((pct > 75)) && bar_color="$R"

  # Emoji based on state
  local ctx_emoji="🧠"
  ((pct > 50)) && ctx_emoji="😵"
  ((pct > 75)) && ctx_emoji="🤯"

  # Build bar with separators at 50% and 75%
  local bar=""
  local pos=0
  for ((i=0; i<bar_total; i++)); do
    if ((i == pos_50 || i == pos_75 + 1)); then
      # Separator
      bar+="${D}│${Z}"
    else
      if ((pos < filled)); then
        bar+="${bar_color}█${Z}"
      else
        bar+="${D}░${Z}"
      fi
      ((pos++))
    fi
  done

  # Format token counts
  local total_tok=$((initial + ours))
  local tok_display=$(fmt_comma "$total_tok")
  local window_display=$(fmt_comma "$CTX_WINDOW")

  # Full line: emoji model [bar] pct% tok/window
  echo "${ctx_emoji} ${P}${model}${Z} [${bar}] $(thresh_col "$pct" 50 75)${pct}%${Z} ${D}(${Z}${tok_display}${D}/${Z}${window_display}${D})${Z}"
}

# Generic threshold color: val, warn_threshold, crit_threshold
thresh_col() {
  local v=${1%.*} w=${2:-60} c=${3:-80}
  [[ -z "$v" ]] && v=0
  ((v >= c)) && echo "$R" || { ((v >= w)) && echo "$Y" || echo "$G"; }
}

hr_12() {
  local h=$1; [[ -z "$h" ]] && echo "?" && return
  ((h==0)) && echo "12am" && return
  ((h<12)) && echo "${h}am" && return
  ((h==12)) && echo "12pm" && return
  echo "$((h-12))pm"
}

# ==================== INPUT PARSING (SINGLE JQ) ====================
# Use "_" placeholder for empty fields to handle consecutive tabs in TSV
input_json=$(cat)
IFS=$'\t' read -r model_id cwd used_pct transcript_path lines_added lines_removed total_cost_usd total_duration_ms <<< \
  "$(echo "$input_json" | jq -r '[.model.id//"_", .workspace.current_dir//"_", .context_window.used_percentage//"_", .transcript_path//"_", .cost.total_lines_added//0, .cost.total_lines_removed//0, .cost.total_cost_usd//0, .cost.total_duration_ms//0] | @tsv')"
# Convert placeholders back to empty strings
[[ "$model_id" == "_" ]] && model_id=""
[[ "$cwd" == "_" ]] && cwd=""
[[ "$used_pct" == "_" ]] && used_pct=""
[[ "$transcript_path" == "_" ]] && transcript_path=""
[[ "$lines_added" == "_" ]] && lines_added=0
[[ "$lines_removed" == "_" ]] && lines_removed=0
[[ "$total_cost_usd" == "_" ]] && total_cost_usd=0
[[ "$total_duration_ms" == "_" ]] && total_duration_ms=0

# Model short name
model=""
case "$model_id" in *opus*) model="opus";; *sonnet*) model="sonnet";; *haiku*) model="haiku";; *) model="${model_id#claude-}"; model="${model%%-*}";; esac

user=$(whoami)

# Abbreviate path
abbrev="$cwd"
[[ "$cwd" == "$HOME"* ]] && abbrev="~${cwd#$HOME}"
IFS='/' read -ra parts <<< "$abbrev"
if ((${#parts[@]} > 4)); then
  abbrev="${parts[0]}/.../$(basename "$(dirname "$cwd")")/$(basename "$cwd")"
fi

# ==================== GIT INFO (BATCHED) ====================
git_info=""
if git rev-parse --git-dir >/dev/null 2>&1; then
  git_status=$(git --no-optional-locks status --porcelain=v2 --branch 2>/dev/null)

  # Single awk call to extract branch and ahead/behind (DRY)
  read -r branch ahead behind <<< $(echo "$git_status" | awk '
    /^# branch.head/ {br=$3}
    /^# branch.ab/ {gsub(/[+-]/,"",$3); gsub(/[+-]/,"",$4); ah=$3; bh=$4}
    END {print br, ah+0, bh+0}
  ')
  [[ -z "$branch" ]] && branch=$(git rev-parse --short HEAD 2>/dev/null)
  ab_info=""; ((ahead+behind > 0)) && ab_info=" {$((ahead+behind))}"

  # Count staged/unstaged/untracked - marian style (single pass)
  staged=0 unstaged=0 untracked=0
  while IFS= read -r line; do
    case "$line" in
      "? "*) ((untracked++)) ;;
      [12]\ *) xy="${line:2:2}"
        [[ "${xy:0:1}" != "." ]] && ((staged++))
        [[ "${xy:1:1}" != "." ]] && ((unstaged++)) ;;
    esac
  done <<< "$git_status"

  # Build [±] indicator (marian style)
  ct="" status="${G}✓${Z}"
  ((staged > 0 && unstaged > 0)) && ct="±"
  ((staged > 0 && unstaged == 0)) && ct="+"
  ((staged == 0 && unstaged > 0)) && ct="!"
  ((untracked > 0)) && [[ -z "$ct" ]] && ct="?"
  [[ -n "$ct" ]] && status="${Y}✗${Z}"
  change_ind=""; [[ -n "$ct" ]] && change_ind="[${Y}${ct}${Z}]"

  # File counts (S:n U:n ?:n)
  fc=""
  ((staged > 0)) && fc+="${G}S:${staged}${Z} "
  ((unstaged > 0)) && fc+="${Y}U:${unstaged}${Z} "
  ((untracked > 0)) && fc+="${R}?:${untracked}${Z} "

  # Diff stats (+lines/-lines) - only if changes exist
  diff=""
  if ((staged + unstaged > 0)); then
    read -r ins del <<< $(git --no-optional-locks diff --numstat HEAD 2>/dev/null | awk '{i+=$1;d+=$2}END{print i+0,d+0}')
    ((ins > 0)) && diff=" {${G}+${ins}${Z}"
    ((del > 0)) && { [[ -n "$diff" ]] && diff+="/${R}-${del}${Z}}" || diff=" {${R}-${del}${Z}}"; }
    ((ins > 0 && del == 0)) && diff+="}"
  fi

  # Combine: [±][branch {ahead} S:n U:n {+ins/-del} ✓/✗]
  git_info="${change_ind}[${G}${branch}${ab_info}${Z} ${fc% }${diff} ${status}]"
fi

# ==================== STATS FILE (SINGLE JQ) ====================
stats_file="$HOME/.claude/stats-cache.json"

# Defaults
total_in=0 total_out=0 cache_read=0 total_msg=0 total_sess=0 peak_hr="" first_date=""
total_cost_accurate=0 longest_dur=0 longest_msgs=0 model_breakdown=""

if [[ -f "$stats_file" ]]; then
  read -r total_in total_out cache_read total_msg total_sess peak_hr first_date \
    total_cost_accurate longest_dur longest_msgs model_breakdown <<< \
    $(jq -r '
      # Total: accurate per-model costs INCLUDING cache tokens
      # Rates from Anthropic docs (Jan 2026): https://platform.claude.com/docs/en/about-claude/pricing
      # Opus 4.5: $5/$25, Sonnet 4.5: $3/$15, Haiku 4.5: $1/$5
      # Cache: read=0.1x input, write=1.25x input
      (.modelUsage | to_entries | map(
        (.key | if contains("opus-4-5") or contains("opus-4-6") then {ip:5, op:25, cr:0.50, cw:6.25}
                elif contains("sonnet-4-5") or contains("sonnet-4-6") then {ip:3, op:15, cr:0.30, cw:3.75}
                elif contains("haiku-4-5") or contains("haiku-4-6") then {ip:1, op:5, cr:0.10, cw:1.25}
                elif contains("haiku-3-5") then {ip:0.80, op:4, cr:0.08, cw:1}
                elif contains("opus") then {ip:15, op:75, cr:1.50, cw:18.75}
                elif contains("sonnet") then {ip:3, op:15, cr:0.30, cw:3.75}
                elif contains("haiku") then {ip:0.25, op:1.25, cr:0.03, cw:0.30}
                else {ip:3, op:15, cr:0.30, cw:3.75} end) as $r |
        (((.value.inputTokens // 0) * $r.ip) +
         ((.value.outputTokens // 0) * $r.op) +
         ((.value.cacheReadInputTokens // 0) * $r.cr) +
         ((.value.cacheCreationInputTokens // 0) * $r.cw)) / 1000000
      ) | add // 0) as $tc |

      # Model breakdown: calculate % of total cost per model (including cache)
      (.modelUsage | to_entries | map(
        (.key | if contains("opus-4-5") or contains("opus-4-6") then {n:"O",ip:5,op:25,cr:0.50,cw:6.25}
                elif contains("sonnet-4-5") or contains("sonnet-4-6") then {n:"S",ip:3,op:15,cr:0.30,cw:3.75}
                elif contains("haiku-4-5") or contains("haiku-4-6") then {n:"H",ip:1,op:5,cr:0.10,cw:1.25}
                elif contains("haiku-3-5") then {n:"H",ip:0.80,op:4,cr:0.08,cw:1}
                elif contains("opus") then {n:"O",ip:15,op:75,cr:1.50,cw:18.75}
                elif contains("sonnet") then {n:"S",ip:3,op:15,cr:0.30,cw:3.75}
                elif contains("haiku") then {n:"H",ip:0.25,op:1.25,cr:0.03,cw:0.30}
                else {n:"?",ip:3,op:15,cr:0.30,cw:3.75} end) as $r |
        {name: $r.n, cost: ((((.value.inputTokens//0)*$r.ip) +
                            ((.value.outputTokens//0)*$r.op) +
                            ((.value.cacheReadInputTokens//0)*$r.cr) +
                            ((.value.cacheCreationInputTokens//0)*$r.cw))/1000000)}
      ) | if $tc > 0 then map("\(.name):\(.cost/$tc*100|floor)%") | join(" ") else "" end) as $mb |

      [
        (.modelUsage | to_entries | map(.value.inputTokens//0) | add // 0),
        (.modelUsage | to_entries | map(.value.outputTokens//0) | add // 0),
        (.modelUsage | to_entries | map(.value.cacheReadInputTokens//0) | add // 0),
        (.totalMessages // 0), (.totalSessions // 0),
        (.hourCounts | to_entries | max_by(.value) | .key // ""),
        (.dailyActivity | sort_by(.date) | .[0].date // ""),
        $tc,
        ((.longestSession.duration // 0) / 1000 | floor),  # Convert ms to seconds
        (.longestSession.messageCount // 0),
        $mb
      ] | @tsv
    ' "$stats_file" 2>/dev/null)
fi

# ==================== SESSION STATS ====================
session_id=""
[[ -n "$transcript_path" ]] && session_id=$(basename "$transcript_path" .jsonl | cut -c1-8)

# Use official cost from Claude Code input (no need to calculate from tokens)
sess_cost=$(printf "%.2f" "${total_cost_usd:-0}")

# Show cost only in pay-as-you-go mode (non-zero cost = API key billing)
sess_cost_display=""
awk "BEGIN{exit !($total_cost_usd > 0)}" 2>/dev/null && \
  sess_cost_display="[\$${sess_cost}]"

# Use official duration from Claude Code input (convert ms to seconds for fmt_dur)
sess_dur_seconds=$((${total_duration_ms%.*} / 1000))
sess_dur=$(fmt_dur "$sess_dur_seconds")

tool_count=0
sess_msg_count=0
initial_tokens=0
ours_tokens=0
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
  tool_count=$(grep -c '"tool_use' "$transcript_path" 2>/dev/null || echo 0)
  sess_msg_count=$(grep -c '"type":"user"' "$transcript_path" 2>/dev/null || echo 0)

  # Get baseline (first message's cache_read = pre-session system context)
  baseline_tokens=$(get_baseline_tokens "$transcript_path")

  # Get latest usage entry for current state
  latest_usage=$(tail -100 "$transcript_path" | jq -s '[.[] | .message.usage // empty] | .[-1]' 2>/dev/null)
  if [[ -n "$latest_usage" && "$latest_usage" != "null" ]]; then
    # Total context = cache_read + cache_creation + input + output
    total_ctx=$(echo "$latest_usage" | jq -r '
      (.cache_read_input_tokens // 0) +
      (.cache_creation_input_tokens // 0) +
      (.input_tokens // 0) +
      (.output_tokens // 0)
    ' 2>/dev/null || echo 0)

    # Initial = baseline (static), Ours = growth above baseline
    initial_tokens=$baseline_tokens
    ours_tokens=$((total_ctx - baseline_tokens))
    ((ours_tokens < 0)) && ours_tokens=0
  fi
fi

# ==================== CALCULATIONS ====================
total_tok=$((total_in + total_out))

# Total cost (use accurate per-model calculation from jq)
total_cost=$(printf "%.2f" "$total_cost_accurate")

# Cache rate
cache_rate=0
((total_in + cache_read > 0)) && cache_rate=$(bc -l <<< "100 * $cache_read / ($cache_read + $total_in)" | xargs printf "%.0f")

# Avg cost
avg_cost="0.00"
((total_sess > 0)) && avg_cost=$(bc -l <<< "$total_cost / $total_sess" | xargs printf "%.2f")

# Format dates
first_fmt=""
[[ -n "$first_date" && "$first_date" != "null" ]] && first_fmt=$(date_fmt "$first_date")
peak_fmt=$(hr_12 "$peak_hr")

# ==================== BUILD OUTPUT (Mairan Colors) ====================

# Calculate display percentage for context
pct=0
if ((initial_tokens > 0 || ours_tokens > 0)); then
  total_tokens=$((initial_tokens + ours_tokens))
  ((total_tokens > 0)) && pct=$((total_tokens * 100 / CTX_WINDOW))
elif [[ -n "$used_pct" && "$used_pct" != "0" ]]; then
  initial_tokens=$((${used_pct%.*} * CTX_WINDOW / 100))
  pct=${used_pct%.*}
fi

# Line 1: Full-width context bar (prominent)
line1=""
if [[ -n "$model" ]]; then
  line1=$(mk_full_ctx_bar "$initial_tokens" "$ours_tokens" "$model" "$pct")
else
  line1="${D}(no model)${Z}"
fi

# Line 2: [user][git][path]
line2="[${G}${user}${Z}]${git_info}[${G}${abbrev}${Z}]"

# Format lines changed for session
lines_diff=""
if ((lines_added > 0 || lines_removed > 0)); then
  lines_diff="[${G}+${lines_added}${Z}/${R}-${lines_removed}${Z}]"
fi

# Line 3: SESSION with msg/tools, cost, duration, lines changed
line3="[${O}SESSION ${G}${session_id}${Z}][${G}${sess_msg_count}${Z} ${D}msg${Z} | ${G}${tool_count}${Z} ${D}tools${Z}]${sess_cost_display}[${G}${sess_dur}${Z}]${lines_diff}"

# ==================== OUTPUT ====================
printf "%b\n%b\n%b" "$line1" "$line2" "$line3"
