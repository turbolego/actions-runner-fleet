#!/bin/bash

runner_config_file() {
    local runner_dir="$1"
    if [ -f "$runner_dir/.runner" ]; then
        printf '%s\n' "$runner_dir/.runner"
    elif [ -f "$runner_dir/.runner_migrated" ]; then
        printf '%s\n' "$runner_dir/.runner_migrated"
    else
        printf 'Runner is not configured: %s\n' "$runner_dir" >&2
        return 1
    fi
}

runner_work_dir() {
    local runner_dir="$1" config work_dir
    config=$(runner_config_file "$runner_dir") || return 1
    work_dir=$(jq -er '.workFolder | select(type == "string" and length > 0)' "$config") || {
        printf 'Invalid workFolder in %s\n' "$config" >&2
        return 1
    }
    case "$work_dir" in
        /*) printf '%s\n' "$work_dir" ;;
        *) printf '%s/%s\n' "$runner_dir" "$work_dir" ;;
    esac
}

default_runner_work_dir() {
    local runner_dir="$1" fleet_id
    if [ "$(uname -s)" = "Darwin" ]; then
        # Separate fleets with the same runner names without using protected folders.
        fleet_id=$(printf '%s' "$BASE_DIR" | cksum) || return 1
        fleet_id="${fleet_id%% *}"
        printf '%s/.local/share/actions-runner-fleet/%s/%s/_work\n' \
            "$HOME" "$fleet_id" "$(basename "$runner_dir")"
    else
        printf '%s/_work\n' "$runner_dir"
    fi
}

prepare_runner_workspace() {
    local runner_dir="$1" config work_dir current_dir temp_config physical_home
    config=$(runner_config_file "$runner_dir") || return 1
    current_dir=$(runner_work_dir "$runner_dir") || return 1
    work_dir="$current_dir"
    if [ "$(uname -s)" = "Darwin" ]; then
        work_dir=$(default_runner_work_dir "$runner_dir") || return 1
    fi
    if ! mkdir -p "$work_dir/_temp"; then
        printf 'Cannot create runner workspace: %s\n' "$work_dir" >&2
        return 1
    fi
    work_dir=$(cd "$work_dir" && pwd -P) || return 1
    if [ "$(uname -s)" = "Darwin" ]; then
        physical_home=$(cd "$HOME" && pwd -P) || return 1
        case "$work_dir/" in
            "$physical_home/Documents/"*|"$physical_home/Desktop/"*|"$physical_home/Downloads/"*|\
            "$physical_home/Library/Mobile Documents/"*|"$physical_home/Library/CloudStorage/"*)
                printf 'Runner workspace resolves to a macOS protected folder: %s\n' "$work_dir" >&2
                return 1
                ;;
        esac
    fi
    if [ ! -w "$work_dir" ] || [ ! -w "$work_dir/_temp" ] || [ ! -x "$work_dir" ]; then
        printf 'Runner workspace is not writable/searchable: %s\n' "$work_dir" >&2
        return 1
    fi
    if [ "$work_dir" != "$current_dir" ]; then
        temp_config=$(mktemp "$config.tmp.XXXXXX") || return 1
        if ! jq --arg work "$work_dir" '.workFolder = $work' "$config" > "$temp_config" ||
            ! mv "$temp_config" "$config"; then
            rm -f "$temp_config"
            printf 'Cannot update runner workspace in %s\n' "$config" >&2
            return 1
        fi
        printf 'Runner workspace configured: %s (old workspace retained)\n' "$work_dir" >&2
    fi
    printf '%s\n' "$work_dir"
}
