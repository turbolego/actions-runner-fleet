#!/bin/bash
set -euo pipefail

work_dir="${RUNNER_FLEET_WORK_DIR:?RUNNER_FLEET_WORK_DIR is not set}"

case "$work_dir" in
    /*/_work) ;;
    *)
        printf 'Refusing to clean invalid runner work directory: %s\n' "$work_dir" >&2
        exit 1
        ;;
esac

if [ ! -d "$work_dir" ] || [ -L "$work_dir" ]; then
    printf 'Refusing to clean missing or symlinked runner work directory: %s\n' "$work_dir" >&2
    exit 1
fi

runner_dir="${work_dir%/_work}"
if [ ! -f "$runner_dir/.runner" ] && [ ! -f "$runner_dir/.runner_migrated" ]; then
    printf 'Refusing to clean directory that is not a configured runner: %s\n' "$runner_dir" >&2
    exit 1
fi

printf 'Removing completed job workspace and action cache from %s\n' "$work_dir"
find "$work_dir" -mindepth 1 -maxdepth 1 \
    ! -name '_tool' ! -name '_PipelineMapping' -exec rm -rf {} +

if [ -d "$runner_dir/_diag" ]; then
    find "$runner_dir/_diag" -type f -name '*.log' -mtime +30 -delete
fi
