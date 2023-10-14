#!/bin/bash

set -eu
set -o errexit
set -o pipefail
set -o nounset

# Function to URL-encode strings
urlencode() {
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
}

# Main script
main() {
    local netrcPath="$1"
    local machine=$(urlencode "${2}")
    local username=$(urlencode "${3}")
    local password=$(urlencode "${4}")

    if [ -z "$netrcPath" ] || [ -z "$machine" ] || [ -z "$username" ] || [ -z "$password" ]; then
        echo "NetrcPath, machine, username, and password are required."
        exit 1
    fi

    # Check and set file permissions
    if [ -f "$netrcPath" ]; then
        chmod 600 "$netrcPath"
    fi

    # Append to the file
    echo "machine ${machine}" >> "$netrcPath"
    echo "  login ${username}" >> "$netrcPath"
    echo "  password ${password}" >> "$netrcPath"
    chmod 600 "$netrcPath"
}

# Run the script with passed arguments
main "$@"
