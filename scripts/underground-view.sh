#!/bin/bash

declare -A DEFAULT

CONF_FILE_PATH="$1"
if [ ! -z "$CONF_FILE_PATH" ]; then
    source $CONF_FILE_PATH
fi

# FETCHERS

function fetch_block_devices () {
    BLOCK_DEVICES=(
        `lsblk | grep -e disk | sed 's/^/\/dev\//g' | awk '{print $1}'`
    )
    echo ${BLOCK_DEVICES[@]}
    return 0
}

function fetch_data_from_user () {
    local PROMPT="$1"
    while :
    do
        read -p "$PROMPT> " DATA
        if [ -z "$DATA" ]; then
            continue
        elif [[ "$DATA" == ".back" ]]; then
            return 1
        fi
        echo "$DATA"; break
    done
    return 0
}

function fetch_ultimatum_from_user () {
    PROMPT="$1"
    while :
    do
        local ANSWER=`fetch_data_from_user "$PROMPT"`
        case "$ANSWER" in
            'y' | 'Y' | 'yes' | 'Yes' | 'YES')
                return 0
                ;;
            'n' | 'N' | 'no' | 'No' | 'NO')
                return 1
                ;;
            *)
        esac
    done
    return 2
}

function fetch_selection_from_user () {
    local PROMPT="$1"
    local OPTIONS=( "${@:2}" "Back" )
    local OLD_PS3=$PS3
    PS3="$PROMPT> "
    select opt in "${OPTIONS[@]}"; do
        case $opt in
            'Back')
                PS3="$OLD_PS3"
                return 1
                ;;
            *)
                local CHECK=`check_item_in_set "$opt" "${OPTIONS[@]}"`
                if [ $? -ne 0 ]; then
                    warning_msg "Invalid option."
                    continue
                fi
                PS3="$OLD_PS3"
                echo "$opt"
                return 0
                ;;
        esac
    done
    PS3="$OLD_PS3"
    return 1
}

function fetch_final_sector () {
    if [ -z "${DEFAULT['final-sector']}" ]; then
        warning_msg "Final Sector not set."
        return 1
    fi
    echo ${DEFAULT['final-sector']}
    return 0
}

function fetch_default_block_size () {
    if [ -z "${DEFAULT['block-size']}" ]; then
        warning_msg "Block Size not set."
        return 1
    fi
    echo ${DEFAULT['block-size']}
    return 0
}

function fetch_default_block_device () {
    if [ -z "${DEFAULT['block-device']}" ]; then
        warning_msg "Block Device not set."
        return 1
    fi
    echo ${DEFAULT['block-device']}
    return 0
}

function fetch_default_sector_number () {
    if [ -z "${DEFAULT['sector-number']}" ]; then
        warning_msg "Sector Number not set."
        return 1
    fi
    echo ${DEFAULT['sector-number']}
    return 0
}

function fetch_default_block_count () {
    if [ -z "${DEFAULT['block-count']}" ]; then
        warning_msg " not set."
        return 1
    fi
    echo ${DEFAULT['block-count']}
    return 0
}

function fetch_default_output_file () {
    if [ -z "${DEFAULT['out-file']}" ]; then
        warning_msg "Output file path not set."
        return 1
    fi
    echo ${DEFAULT['out-file']}
    return 0
}

function fetch_default_temporary_file () {
    if [ -z "${DEFAULT['tmp-file']}" ]; then
        warning_msg "Temporary File path not set."
        return 1
    fi
    echo ${DEFAULT['tmp-path']}
    return 0
}

# SETTERS

function set_default_out_mode () {
    local OUT_MODE="$1"
    if [ -z "$OUT_MODE" ]; then
        echo; error_msg "No Out Mode specified."
        echo; return 1
    fi
    if [[ "$OUT_MODE" != "append" ]] && [[ "$OUT_MODE" != "overwrite" ]]; then
        echo; error_msg "Invalid value ${RED}$OUT_MODE${RESET} for file output mode setting."
        echo; return 2
    fi
    DEFAULT['out-mode']=$OUT_MODE
    return 0
}

function set_final_sector () {
    local FINAL_SECTOR=$1
    if [ -z "$FINAL_SECTOR" ]; then
        echo; error_msg "No Final Sector specified."
        echo; return 1
    fi
    DEFAULT['final-sector']=$FINAL_SECTOR
    return 0
}

function set_default_block_size () {
    local BLOCK_SIZE=$1
    if [ -z "$BLOCK_SIZE" ]; then
        echo; error_msg "No default Block Size specified."
        echo; return 1
    fi
    DEFAULT['block-size']=$BLOCK_SIZE
    return 0
}

function set_default_block_device () {
    local BLOCK_DEVICE=$1
    if [ -z "$BLOCK_DEVICE" ]; then
        echo; error_msg "No default Block Device specified."
        echo; return 1
    fi
    DEFAULT['block-device']=$BLOCK_DEVICE
    return 0
}

function set_default_sector_number () {
    local SECTOR_NUMBER=$1
    if [ -z "$SECTOR_NUMBER" ]; then
        echo; error_msg "No default Sector Number specified."
        echo; return 1
    fi
    DEFAULT['sector-number']=$SECTOR_NUMBER
    return 0
}

function set_default_block_count () {
    local BLOCK_COUNT=$1
    if [ -z "$BLOCK_COUNT" ]; then
        echo; error_msg "No default Block Count specified."
        echo; return 1
    fi
    DEFAULT['block-count']=$BLOCK_COUNT
    return 0
}

function set_default_output_file () {
    OUTPUT_FILE=$1
    if [ -z "$OUTPUT_FILE" ]; then
        echo; error_msg "No default Output File specified."
        echo; return 1
    fi
    DEFAULT['out-file']=$OUTPUT_FILE
    return 0
}

function set_default_temporary_file () {
    TEMPORARY_FILE=$1
    if [ -z "$TEMPORARY_FILE" ]; then
        echo; error_msg "No default Temporary File specified."
        echo; return 1
    fi
    DEFAULT['tmp-file']=$TEMPORARY_FILE
    return 0
}

# CHECKERS

function check_value_is_number () {
    VALUE=$1
    test $VALUE -eq $VALUE &> /dev/null
    if [ $? -ne 0 ]; then
        return 1
    fi
    return 0
}

function check_item_in_set () {
    local ITEM="$1"
    ITEM_SET=( "${@:2}" )
    for SET_ITEM in "${ITEM_SET[@]}"; do
        if [[ "$ITEM" == "$SET_ITEM" ]]; then
            return 0
        fi
    done
    return 1
}

# GENERAL

# VIEWERS

function view_block_device_sector_hexdump () {
    local DEVICE=$1
    local BLOCK_SIZE=$2
    local SECTOR_NUMBER=$3
    local BLOCK_COUNT=$4
    dd if=$DEVICE bs=$BLOCK_SIZE count=$BLOCK_COUNT skip=$SECTOR_NUMBER | \
        hexdump \
            -e '/24 "%004_ax     " ' \
            -e '24/1 "%02x "' \
            -e '"     |"24/1 " %_p" "  |" "\n"' -v | \
            grep '|'
    return $?
}

function underground_view () {
    handle_view_block_device_sector_hexdump
    EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
        return $EXIT_CODE
    fi
    echo; qa_msg "Would you like to save this to file"\
        "${YELLOW}${DEFAULT['out-file']}${RESET}?"
    fetch_ultimatum_from_user "${YELLOW}Y/N${RESET}"
    if [ $? -ne 0 ]; then
        return 1
    fi
    echo; handle_view_block_device_sector_hexdump "save-2-file"
    echo; ok_msg "Block device ${YELLOW}${DEFAULT['block-device']}${RESET}"\
        "inspection of a ${WHITE}${DEFAULT['block-count']}${RESET} block sector range"\
        "[${GREEN}${DEFAULT['sector-number']}-${DEFAULT['final-sector']}${RESET}]"\
        "logged to file ${GREEN}${DEFAULT['out-file']}${RESET} in"\
        "${YELLOW}${DEFAULT['out-mode']}${RESET} mode."
    return 1
}

# INSTALLERS

function apt_install_dependency() {
    local UTIL="$1"
    echo; symbol_msg "${GREEN}+${RESET}" "Installing package ${YELLOW}$UTIL${RESET}..."
    apt-get install $UTIL
    return $?
}

function apt_install_underground_view_dependencies () {
    if [ ${#APT_DEPENDENCIES[@]} -eq 0 ]; then
        info_msg 'No dependencies to fetch using the apt package manager.'
        return 1
    fi
    local FAILURE_COUNT=0
    info_msg "Installing dependencies using apt package manager:"
    for package in "${APT_DEPENDENCIES[@]}"; do
        apt_install_dependency $package
        if [ $? -ne 0 ]; then
            nok_msg "Failed to install ${YELLOW}$SCRIPT_NAME${RESET}"\
                "dependency ${RED}$package${RESET}!"
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
        else
            ok_msg "Successfully installed ${YELLOW}$SCRIPT_NAME${RESET}"\
                "dependency ${GREEN}$package${RESET}."
            INSTALL_COUNT=$((INSTALL_COUNT + 1))
        fi
    done
    if [ $FAILURE_COUNT -ne 0 ]; then
        echo; warning_msg "${RED}$FAILURE_COUNT${RESET} dependency"\
            "installation failures! Try installing the packages manually."
    fi
    return 0
}

# ACTIONS

function action_install_underground_view_dependencies () {
    echo; info_msg "About to install ${WHITE}${#APT_DEPENDENCIES[@]}${RESET}"\
        "${YELLOW}$SCRIPT_NAME${RESET} dependencies."
    ANSWER=`fetch_ultimatum_from_user "Are you sure about this? ${YELLOW}Y/N${RESET}"`
    if [ $? -ne 0 ]; then
        echo; info_msg "Aborting action."
        return 1
    fi
    echo; apt_install_underground_view_dependencies
    local EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
        nok_msg "Software failure!"\
            "Could not install ${RED}$SCRIPT_NAME${RESET} dependencies."
        echo; return 1
    else
        ok_msg "${GREEN}$SCRIPT_NAME${RESET}"\
            "dependency installation complete."
    fi
    echo; return $EXIT_CODE
}

function action_set_file_writer_mode () {
    echo; info_msg "Select file writer output mode."; echo
    while :
    do
        MODE=`fetch_selection_from_user "OutMode" "append" "overwrite"`
        if [ $? -ne 0 ]; then
            echo; return 1
        elif [ -z "$MODE" ]; then
            echo; warning_msg "Invalid input."
            echo; continue
        fi
        break
    done
    set_default_out_mode "$MODE"
    return 0
}

function action_set_default_block_device () {
    display_block_devices
    info_msg "Type full block device path or ${MAGENTA}.back${RESET}."
    VALID_DEVICE_PATHS=( `fetch_block_devices` )
    while :
    do
        BLOCK_DEVICE=`fetch_data_from_user "BlockDevice"`
        if [ $? -ne 0 ]; then
            echo; return 1
        fi
        check_item_in_set "$BLOCK_DEVICE" ${VALID_DEVICE_PATHS[@]}
        if [ $? -ne 0 ]; then
            echo; warning_msg "Invalid block device path ${RED}$BLOCK_DEVICE${RESET}."
            echo; continue
        fi
        set_default_block_device "$BLOCK_DEVICE"
        echo; break
    done
    return 0
}

function action_set_default_block_size () {
    echo; info_msg "Type sector size in bytes or ${MAGENTA}.back${RESET}."
    while :
    do
        BLOCK_SIZE=`fetch_data_from_user "BlockSize"`
        if [ $? -ne 0 ]; then
            echo; return 1
        fi
        check_value_is_number $BLOCK_SIZE
        if [ $? -ne 0 ]; then
            echo; warning_msg "Block size must be a number,"\
                "not ${RED}$BLOCK_SIZE${RESET}."
            echo; continue
        fi
        set_default_block_size $BLOCK_SIZE
        echo; break
    done
    return 0
}

function action_set_default_start_sector_number () {
    echo; info_msg "Type start sector number or ${MAGENTA}.back${RESET}."
    while :
    do
        START_SECTOR=`fetch_data_from_user "StartSector"`
        if [ $? -ne 0 ]; then
            echo; return 1
        fi
        check_value_is_number $START_SECTOR
        if [ $? -ne 0 ]; then
            echo; warning_msg "Start sector must be a number,"\
                "not ${RED}$START_SECTOR${RESET}."
            echo; continue
        fi
        set_default_sector_number $START_SECTOR
        if [ $START_SECTOR -gt ${DEFAULT['final-sector']} ]; then
            set_final_sector $START_SECTOR
        fi
        echo; break
    done
    return 0
}

function action_set_end_sector_number () {
    echo; info_msg "Type end sector number or ${MAGENTA}.back${RESET}."
    while :
    do
        END_SECTOR=`fetch_data_from_user "EndSector"`
        if [ $? -ne 0 ]; then
            echo; return 1
        fi
        check_value_is_number $END_SECTOR
        if [ $? -ne 0 ]; then
            echo; warning_msg "End sector must be a number,"\
                "not ${RED}$END_SECTOR${RESET}."
            echo; continue
        fi
        if [ $END_SECTOR -lt ${DEFAULT['sector-number']} ]; then
            echo; warning_msg "Final sector number cannot be lower than start"\
                "sector ${RED}${DEFAULT['sector-number']}${RESET}."
            echo; continue
        fi
        set_final_sector $END_SECTOR
        SECTOR_COUNT=$(((END_SECTOR - ${DEFAULT['sector-number']}) + 1))
        set_default_block_count $SECTOR_COUNT
        echo; break
    done
    return 0
}

# HANDLERS

function handle_view_block_device_sector_hexdump () {
    local SAVE_TO_FILE_FLAG="$1"
    if [[ "$SAVE_TO_FILE_FLAG" == "save-2-file" ]]; then
        case "${DEFAULT['out-mode']}" in
            'append')
                view_block_device_sector_hexdump \
                    "${DEFAULT['block-device']}" \
                    ${DEFAULT['block-size']} \
                    ${DEFAULT['sector-number']} \
                    ${DEFAULT['block-count']} >> "${DEFAULT['out-file']}"
                local EXIT_CODE=$?
                ;;
            'overwrite')
                view_block_device_sector_hexdump \
                    "${DEFAULT['block-device']}" \
                    ${DEFAULT['block-size']} \
                    ${DEFAULT['sector-number']} \
                    ${DEFAULT['block-count']} > "${DEFAULT['out-file']}"
                local EXIT_CODE=$?
                ;;
            *)
                error_msg "Invalid file writer output mode"\
                    "${RED}${DEFAULT['out-mode']}${RESET}."
                return 2
                ;;
        esac
    else
        view_block_device_sector_hexdump \
            "${DEFAULT['block-device']}" \
            ${DEFAULT['block-size']} \
            ${DEFAULT['sector-number']} \
            ${DEFAULT['block-count']}
        local EXIT_CODE=$?
    fi
    if [ $EXIT_CODE -ne 0 ]; then
        error_msg "Something went wrong."\
            "Could not view hex dump of block device "\
            "${YELLOW}${DEFAULT['block-device']}${RESET} "\
            "sector range ${RED}${DEFAULT['sector-number']} - "\
            "$((${DEFAULT['sector-number']} + ${DEFAUL['block-count']}))"\
            "${RESET}."
        return 2
    fi
    if [[ "$SAVE_TO_FILE" == "save-2-file" ]]; then
        return 1
    fi
    return 0
}

# DISPLAY

function display_block_devices () {
    echo; echo -n "${CYAN}DEVICE${RESET}" && \
        echo ${CYAN}`lsblk | grep -e MOUNTPOINT`${RESET} && \
        lsblk | grep -e disk | sed 's/^/\/dev\//g'
    EXIT_CODE=$?
    echo
    return $EXIT_CODE
}

function display_underground_view_settings () {
    echo "
[ ${CYAN}Block Device${RESET} ]: ${DEFAULT['block-device']}
[ ${CYAN}Block Size${RESET}   ]: ${DEFAULT['block-size']}
[ ${CYAN}Block Count${RESET}  ]: ${DEFAULT['block-count']}
[ ${CYAN}Start Sector${RESET} ]: ${DEFAULT['sector-number']}
[ ${CYAN}End Sector${RESET}   ]: ${DEFAULT['final-sector']}
[ ${CYAN}Output File${RESET}  ]: ${DEFAULT['out-file']}
[ ${CYAN}Output Mode${RESET}  ]: ${DEFAULT['out-mode']}
    "
    return 0
}

function display_file_content () {
    local FILE_PATH="$1"
    if [ ! -f "$FILE_PATH" ]; then
        echo; nok_msg "File ${RED}$FILE_PATH${RESET} not found."
        return 1
    fi
    cat "$FILE_PATH"
    return 0
}

function done_msg () {
    local MSG="$@"
    if [ -z "$MSG" ]; then
        return 1
    fi
    echo "[ ${CYAN}DONE${RESET} ]: $MSG"
    return 0
}

function ok_msg () {
    MSG="$@"
    if [ -z "$MSG" ]; then
        return 1
    fi
    echo "[ ${GREEN}OK${RESET} ]: $MSG"
    return 0
}

function nok_msg () {
    MSG="$@"
    if [ -z "$MSG" ]; then
        return 1
    fi
    echo "[ ${RED}NOK${RESET} ]: $MSG"
    return 0
}

function qa_msg () {
    MSG="$@"
    if [ -z "$MSG" ]; then
        return 1
    fi
    echo "[ ${YELLOW}Q/A${RESET} ]: $MSG"
    return 0
}

function info_msg () {
    MSG="$@"
    if [ -z "$MSG" ]; then
        return 1
    fi
    echo "[ ${YELLOW}INFO${RESET} ]: $MSG"
    return 0
}

function error_msg () {
    MSG="$@"
    if [ -z "$MSG" ]; then
        return 1
    fi
    echo "[ ${RED}ERROR${RESET} ]: $MSG"
    return 0
}

function warning_msg () {
    MSG="$@"
    if [ -z "$MSG" ]; then
        return 1
    fi
    echo "[ ${RED}WARNING${RESET} ]: $MSG"
    return 0
}

function symbol_msg () {
    SYMBOL="$1"
    MSG="${@:2}"
    if [ -z "$MSG" ]; then
        return 1
    fi
    echo "[ $SYMBOL ]: $MSG"
    return 0
}

# CONTROLLERS

function underground_view_control_panel () {
    local OPTIONS=(
        "Set Block Device"
        "Set Block Size"
        "Set Start Sector Number"
        "Set End Sector Count"
        "Set File Writer Mode"
        "Install Dependencies"
        "Back"
    )
    symbol_msg "${BLUE}$SCRIPT_NAME"${RESET} \
        "${CYAN}Control Panel${RESET}"
    display_underground_view_settings
    select opt in "${OPTIONS[@]}"; do
        case "$opt" in
            "Set Block Device")
                action_set_default_block_device; break
                ;;
            "Set Block Size")
                action_set_default_block_size; break
                ;;
            "Set Start Sector Number")
                action_set_default_start_sector_number; break
                ;;
            "Set End Sector Count")
                action_set_end_sector_number; break
                ;;
            "Set File Writer Mode")
                action_set_file_writer_mode; break
                ;;
            "Install Dependencies")
                action_install_underground_view_dependencies; break
                ;;
            "Back")
                return 1
                ;;
            *)
                continue
                ;;
        esac
    done
    return 0
}

function underground_view_controller_main () {
    local OPTIONS=(
        "Sector HexDump View"
        "Control Panel"
        "Back"
    )
    echo; symbol_msg "${BLUE}$SCRIPT_NAME${RESET}" \
        "${CYAN}Logic Trace HexDump Inspector${RESET}"; echo
    select opt in "${OPTIONS[@]}"; do
        case "$opt" in
            "Sector HexDump View")
                echo; init_underground_hexdump_viewer
                break
                ;;
            "Control Panel")
                echo; init_underground_view_control_panel
                break
                ;;
            "Back")
                return 1
                ;;
            *)
                continue
                ;;
        esac
    done
    return 0
}

# INIT

function init_underground_hexdump_viewer () {
    while :
    do
        underground_view
        if [ $? -ne 0 ]; then
            break
        fi
    done
    return 0
}

function init_underground_view_control_panel () {
    while :
    do
        underground_view_control_panel
        if [ $? -ne 0 ]; then
            break
        fi
    done
    return 0
}

function init_underground_view () {
    while :
    do
        underground_view_controller_main
        EXIT_CODE=$?
        if [ $EXIT_CODE -ne 0 ]; then
            clear; ok_msg "Terminating UndergroundView."; exit $EXIT_CODE
        fi
    done
    return 0
}

# MISCELLANEOUS

if [ $EUID -ne 0 ]; then
    warning_msg "UndergroundView requieres elevated privileges. \
Current EUID is ${RED}$EUID${RESET}."
    exit 1
fi

init_underground_view
