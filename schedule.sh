#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECORD_FILE="${SCRIPT_DIR}/record.txt"

# Reset Colors
trap 'echo -ne "\033[0m"' EXIT

# Palette
C_MAIN='\033[38;2;202;169;224m'
C_ACCENT='\033[38;2;145;177;240m'
C_DIM='\033[38;2;129;122;150m'
C_GREEN='\033[38;2;166;209;137m'
C_YELLOW='\033[38;2;229;200;144m'
C_RED='\033[38;2;231;130;132m'
C_BOLD='\033[1m'
C_RESET='\033[0m'

header() {
    clear
    echo -e "${C_MAIN}${C_BOLD}"
    echo "──────────────────────────────────────────"
    echo "             Schedule Manager             "
    echo "──────────────────────────────────────────"
    echo -e "${C_RESET}"
}

error() {
    echo -e "${C_RED}✘ ${C_RESET}$1\n"
}

reorgnize_table() {
    if [ ! -s ${RECORD_FILE} ]; then
	return
    fi

    sed -i 's/| \([0-9]\):/| 0\1:/' ${RECORD_FILE}
    sed -i 's/:\([0-9]\) /:0\1 /' ${RECORD_FILE}
    sort -t'|' -k2 ${RECORD_FILE} -o ${RECORD_FILE}

    local tmp_file="${RECORD_FILE}.tmp"
    local new_id=1
    while IFS= read -r line; do
        content=$(echo "$line" | sed 's/^[0-9]*) //')
        echo "${new_id}) ${content}" >> "$tmp_file"
        ((new_id++))
    done < ${RECORD_FILE}
    mv "$tmp_file" ${RECORD_FILE}
}

show_table() {
    echo -e "${C_MAIN}${C_BOLD}"
    record="$(cat ${RECORD_FILE})"

    if [ -n "${record}" ]; then
	echo "Schedule List"
	echo "──────────────────────────────────────────"
	echo "${record}"

    else
	echo "No schedules yet"
	echo "──────────────────────────────────────────"

    fi
    echo -e "${C_RESET}"
}

menu() {
    echo -e "${C_MAIN}${C_BOLD}${C_ACCENT}1${C_DIM}❯ ${C_RESET}New Schedule"
    if [ -n "${record}" ]; then
	echo -e "${C_MAIN}${C_BOLD}${C_ACCENT}2${C_DIM}❯ ${C_RESET}Delete Schedule"
    fi
    echo -e "${C_MAIN}${C_BOLD}${C_ACCENT}q${C_DIM}❯ ${C_RESET}Exit"

}

refresh() {
    header
    show_table
    menu
}

emit_edit_signal() {
    local pid_file="/tmp/reminder.pid"
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            kill -USR1 "$pid"
        fi
    fi
}

read_key() {
    read -s -n 1 key
    if [[ $key == $'\x1b' ]]; then
        read -s -n 2 rest
        case $rest in
            '[A') echo "UP" ;;
            '[B') echo "DOWN" ;;
            '[C') echo "RIGHT" ;;
            '[D') echo "LEFT" ;;
            *) echo "UDF" ;;
        esac
    elif [[ -z $key ]]; then
        echo "ENTER"
    else
        echo "$key"
    fi
}



reorgnize_table
refresh

if [ ! -f "${RECORD_FILE}" ]; then
    while true; do
        read -rp "No schedule file found. Create it? (Y/n): " choice
        choice="${choice:-Y}"
	choice="${choice,,}"

	if [ "${choice}" = "y" ]; then
	    touch ${RECORD_FILE}
	    echo "Created file: $(realpath ${RECORD_FILE})"
	    break
	elif [ "${choice}" = "n" ]; then
	    echo "Cancelled"
	    exit 0
	else
	    error "Please enter y/n"
	fi
    done
fi

while true; do

	record="$(cat ${RECORD_FILE})"

	refresh
	read -rp "" choice

	if [ "${choice}" = "q" ]; then
	    break
	    
	elif [ "${choice}" = "1" ]; then
	    echo -e "${C_MAIN}${C_BOLD}New Schedule:${C_RESET}"
	    echo -e "${C_MAIN}${C_BOLD}──────────────────────────────────────────${C_RESET}"
	    echo -e "${C_GREEN}Content:${C_RESET}"
	    read -rp "" schedule_content
	    schedule_content=$(sed 's/\x1b[[0-9;]*[a-zA-Z]//g' <<< "$schedule_content")

	    echo -e "${C_GREEN}Reminder Time${C_RESET}:"
	    echo -e "${C_MAIN}${C_BOLD}──────────────────────────────────────────${C_RESET}"
	    tput civis
	    hour=$(date "+%H")
	    minute=$(date "+%M")

	    select_time=(
		$(( 10#${hour} / 10 ))
		$(( 10#${hour} % 10 ))
		$(( 10#${minute} / 10 ))
		$(( 10#${minute} % 10 ))
	    )

	    echo -n "${select_time[0]}${select_time[1]}:${select_time[2]}${select_time[3]}"
	    pos=0

	    while true; do 
		key=$(read_key)
		
			if [[ $key == "UP" ]]; then
			    case $pos in
				0) ((select_time[0] < 2)) && ((select_time[0]++));;
				1) ((select_time[1]++));;
				2) ((select_time[2]++));;
				3) ((select_time[3]++));;
			    esac
			    
	      		elif [[ $key == "DOWN" ]]; then
			    case $pos in
				0) ((select_time[0] > 0)) && ((select_time[0]--));;
				1) ((select_time[1]--));;
				2) ((select_time[2]--));;
				3) ((select_time[3]--));;
			    esac
			    
			elif [[ $key == "LEFT" ]] && [[ $pos -gt 0 ]]; then
			    ((pos--))
			    
			elif [[ $key == "RIGHT" ]] && [[ $pos -lt 3 ]]; then
			    ((pos++))
			fi

		    	min=$((select_time[2] * 10 + select_time[3]))
			hour=$(((select_time[0] * 10 + select_time[1] + (min / 60)) % 24))
			if  (( $min < 0 )); then
			    min=$((min + 60))
			    hour=$((hour - 1))
			fi
			if (( hour < 0 )); then
			    hour=$((hour + 24))
			fi
			
			min=$((min % 60))
			select_time[0]=$((${hour} / 10))
			select_time[1]=$((${hour} % 10))
			select_time[2]=$((${min} / 10))
			select_time[3]=$((${min} % 10))

		case $pos in
		    0) echo -ne "\r${C_YELLOW}${C_BOLD}${select_time[0]}${C_RESET}${select_time[1]}:${select_time[2]}${select_time[3]}" ;;
		    1) echo -ne "\r${select_time[0]}${C_YELLOW}${C_BOLD}${select_time[1]}${C_RESET}:${select_time[2]}${select_time[3]}" ;;
		    2) echo -ne "\r${select_time[0]}${select_time[1]}:${C_YELLOW}${C_BOLD}${select_time[2]}${C_RESET}${select_time[3]}" ;;
		    3) echo -ne "\r${select_time[0]}${select_time[1]}:${select_time[2]}${C_YELLOW}${C_BOLD}${select_time[3]}${C_RESET}" ;;
		esac
		
		if [[ $key == "ENTER" ]]; then break; fi
	    done
	    tput cnorm
	    
	    hour=$((${select_time[0]} * 10 + ${select_time[1]}))
	    min=$((${select_time[2]} * 10 + ${select_time[3]}))
	    schedule_ddl="$hour:$min"
	    while true; do
		echo
		echo -e "${C_MAIN}${C_BOLD}──────────────────────────────────────────${C_RESET}"
		echo "Repeat [y/N]:"
		read -rp "" is_long_turn
		is_long_turn="${is_long_turn:-n}"
		is_long_turn="${is_long_turn,,}"
		if [ ${is_long_turn} = y ] || [ ${is_long_turn} = n ]; then
		    break
		else
		    error "Please enter y/n"
		fi
	    done
	    
	    lines=$(wc -l < ${RECORD_FILE})
	    lines=$((lines + 1))

	    cat >> ${RECORD_FILE} <<EOF
${lines}) ${schedule_content} | ${schedule_ddl} | ${is_long_turn}
EOF
	    reorgnize_table
	    emit_edit_signal

	elif [ "${choice}" = "2" ]; then
	    echo -e "${C_MAIN}${C_BOLD}Delete Schedule:${C_RESET}"
	    echo -e "${C_MAIN}${C_BOLD}──────────────────────────────────────────${C_RESET}"
       	    last="$(tail -n 1 ${RECORD_FILE} | awk -F')' '{print $1}')"
	    if [ ${last} = 1 ]; then
		echo -e "${C_MAIN}Select schedule to delete [1]${C_RESET}"
       	    else
		echo -e "${C_MAIN}Select schedule to delete [1~${last}]${C_RESET}"
	    fi
	    read -rp "" index
	    sed -i "${index}d" ${RECORD_FILE}
	    reorgnize_table
	    emit_edit_signal
	    refresh
	    echo -e "${C_MAIN}Schedule deleted successfully!${C_RESET}"

	fi

done
