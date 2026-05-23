#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PID_FILE="/tmp/reminder.pid"
RECORD_FILE="$SCRIPT_DIR/record.txt"
LOG_FILE="$SCRIPT_DIR/reminder.log"

echo $$ > "$PID_FILE"

cleanup() { 
    rm -f "$PID_FILE"
    echo "[$(date '+%H:%M:%S')] Service stopped" >> "$LOG_FILE"
    exit 0
}

trap cleanup EXIT

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

read_schedules() {
    descriptions=()  
    times=()         
    is_long_turns=() 
    
    if [ ! -f "$RECORD_FILE" ]; then
        log "Warning: Schedule file does not exist ($RECORD_FILE)"
        return
    fi
    
    while IFS= read -r line; do
        description=$(echo "$line" | awk -F'|' '{print $1}' | sed 's/^[0-9]*) //;s/ $//')
        time=$(echo "$line" | awk -F'|' '{print $2}' | sed 's/^ //;s/ $//')
        is_long_turn=$(echo "$line" | awk -F'|' '{print $3}' | sed 's/^ //;s/ $//')
        
        descriptions+=("${description}")
        times+=("${time}")
        is_long_turns+=("${is_long_turn}")
    done < "$RECORD_FILE"
    
    log "Loaded ${#times[@]} schedule entries"
}

check_notifications() {
    local current_time=$(date "+%H:%M")

    if [ "${current_time}" = "${last_checked_minute}" ]; then
        return
    fi
    last_checked_minute="${current_time}"

    for i in "${!times[@]}"; do
        if [ "${times[$i]}" = "$current_time" ]; then
            # Send desktop notification if notify-send is available
            if command -v notify-send &>/dev/null; then
                notify-send "Schedule Reminder" "${descriptions[$i]}" -t 5000
            fi

            # Play alarm sound if paplay is available
            if command -v /usr/bin/paplay &>/dev/null; then
                paplay_err=$(/usr/bin/paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>&1)
                if [ -n "${paplay_err}" ]; then
                    log "Failed to play sound: ${paplay_err}"
                fi
            else
                log "Warning: paplay not found"
            fi

            local d_description=${descriptions[$i]}

            # Delete non-long-term schedule entries after notification
            if [ "${is_long_turns[$i]}" == "n" ]; then
                line_num=$((i + 1))
                sed -i "${line_num}d" "$RECORD_FILE"
                unset 'times[$i]'
                unset 'is_long_turns[$i]'
                unset 'descriptions[$i]'
                log "Deleted temporary reminder: ${d_description}"
            fi

            log "Sent reminder: ${d_description}"
        fi
    done

    # Reindex arrays after potential deletions
    times=("${times[@]}")
    is_long_turns=("${is_long_turns[@]}")
    descriptions=("${descriptions[@]}")
}

refresh_handler() {
    log "Received refresh signal, reloading schedule file"
    read_schedules
}

trap 'refresh_handler' SIGUSR1

log "Service started, PID: $$"
log "Schedule file: $RECORD_FILE"
log "Log file: $LOG_FILE"
log "Time check interval: 1 second"

read_schedules

while true; do
    check_notifications
    sleep 60
done
