#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

get_bandwidth_for_osx() {
    netstat -ibn | awk 'FNR > 1 {
    interfaces[$1 ":bytesReceived"] = $(NF-4);
    interfaces[$1 ":bytesSent"]     = $(NF-1);
  } END {
    for (itemKey in interfaces) {
      split(itemKey, keys, ":");
      interface = keys[1]
      dataKind = keys[2]
      sum[dataKind] += interfaces[itemKey]
    }

    print sum["bytesReceived"], sum["bytesSent"]
  }'
}

get_bandwidth_for_linux() {
    /bin/ip -j -s link show |
        jq -r '[.[].stats64] | "\(map(.rx.bytes) | add) \(map(.tx.bytes) | add)"'
}

get_bandwidth() {
    local os="$1"

    case $os in
    osx)
        echo -n $(get_bandwidth_for_osx)
        return 0
        ;;
    linux)
        echo -n $(get_bandwidth_for_linux)
        return 0
        ;;
    *)
        echo -n "0 0"
        return 1
        ;;
    esac
}

format_speed() {
    local padding=$(get_tmux_option "@tmux-network-bandwidth-padding" 5)
    local suffix=$(get_tmux_option "@tmux-network-bandwidth-suffix" "B/s")
    local format=$(get_tmux_option "@tmux-network-bandwidth-format" "%f")

    numfmt --to=iec --suffix $suffix --format $format --padding $padding $1
}

main() {
    local sleep_time=$(get_tmux_option "status-interval")
    local old_value=$(get_tmux_option "@network-bandwidth-previous-value")

    if [ -z "$old_value" ]; then
        $(set_tmux_option "@network-bandwidth-previous-value" "-")
        echo -n "Please wait..."
        return 0
    else
        local os=$(os_type)
        local first_measure=($(get_bandwidth $os))
        sleep $sleep_time
        local second_measure=($(get_bandwidth $os))
        local download_speed=$(((${second_measure[0]} - ${first_measure[0]}) / $sleep_time))
        local upload_speed=$(((${second_measure[1]} - ${first_measure[1]}) / $sleep_time))
        $(set_tmux_option "@network-bandwidth-previous-value" "↓$(format_speed $download_speed) ↑$(format_speed $upload_speed)")
    fi

    echo -n "$(get_tmux_option "@network-bandwidth-previous-value")"
}

main
