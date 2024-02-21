#!/bin/bash

# Function that prints the usage info
show_usage() { cat <<EOL
USAGE:
    \` ${0##*/} [OPTIONS] <HOST> <PORT> [<PROTOCOL> (default: tcp)] \`

SYNOPSIS:
    Unless altered by [OPTIONS], ${0##*/} will attempt to connect to <HOST> on <PORT> over <PROTOCOL>
    No output will be returned, and the exit code will be that of the attempted connection.

EXAMPLE:
    \` ${0##*/} example.com 80 \`

SUPPORTED PROTOCOLS:
    tcp , udp

OPTIONS:
    -h, --help         Show this helpful usage information.
    -p, --ping         Ping the host before checking port connectivity.
    -t, --timeout      Specify the timeout duration (default: 0.01).
    -v, --verbose      Verbose output.

EOL
}

# Initialize global variables
declare -g QUIET=true PING=false TIMEOUT_DURATION="0.01"

# Function that handles messages with associated exit codes (error messages and usage info)
give_help() { 
    $QUIET || { 
        (($# > 1)) && { 
            echo "${@:2}"$'\n'; 
            echo "Use the \`-h\` or \`--help\` option to review usage information."; 
        } || show_usage; 
    }; 
    exit ${1:-0}; 
}

# Parse input
shopt -s extglob
declare -a POSITIONAL_ARGS=()
for((i=1; i<=$#; i++)); do
    case "${!i,,}" in
        +(\-)@(h)?(elp))
            QUIET=false
            give_help ;;
        +(\-)@(p)?(ing))
            PING=true ;;
        +(\-)@(v)?(erbose))
            QUIET=false ;;
        +(\-)@(t)?(imeout))
            if ((i+1<=$#)); then
                i=$((i+1))  # Move to the next argument to get the timeout value
                TIMEOUT_DURATION="${!i}"
                if ! [[ $TIMEOUT_DURATION =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                    give_help 2 "Invalid timeout value: '$TIMEOUT_DURATION'"
                fi
            else
                give_help 2 "Option --timeout requires a value"
            fi ;;
        *)
            # Handle non-option arguments
            POSITIONAL_ARGS+=("${!i}")
            ;;
    esac
done

# Restore positional parameters to what remains after option parsing
set -- "${POSITIONAL_ARGS[@]}"

check_connectivity() {
    (($# >= 2)) || give_help 2 "(Err) Must specify a <HOST> and <PORT>"
    local host="$1"
    local port="$2"
    local protocol="${3:-tcp}"
    [[ "${protocol,,}" == @(tcp|udp) ]] || give_help 3 "Unsupported protocol: '$3'"

    # Ping first
    if $PING ; then
        if ! ping -c 1 "$host" &>/dev/null; then
            $QUIET || echo "Ping to '$host' failed. Host might be down."
            return 1
        fi
    fi

    # Attempt to connect to the specified host and port with timeout
    if ! timeout "$TIMEOUT_DURATION" bash -c "</dev/${protocol,,}/${host}/${port}" &>/dev/null; then
        if [ $? -eq 124 ]; then  # Timeout occurred
            $QUIET || echo "Connection to '${host}:${port}' over ${protocol,,} timed out."
        else
            $QUIET || echo "Failed to connect to '${host}:${port}' over ${protocol,,}."
        fi
        return 1
    else
        $QUIET || echo "Successfully connected to '${host}:${port}' over ${protocol,,}."
    fi
}

# Call check_connectivity with the processed and remaining arguments
check_connectivity "$@"

