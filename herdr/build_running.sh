#!/bin/bash
# Prints how many `/build` Claude tabs run, not counting the tab that called this (its own
# ancestors). Eddy, 2026-11-14: the verdict drain runs only after a batch has ended.
# HERDR_BUILD_RUNNING=<n> overrides, for tests.
if [ -n "${HERDR_BUILD_RUNNING:-}" ]; then echo "$HERDR_BUILD_RUNNING"; exit 0; fi
ps -axo pid=,ppid=,command= | awk -v me="$$" '
  { pid=$1; ppid[pid]=$2; $1=""; $2=""; cmd[pid]=$0 }
  END {
    for (p = me; p > 1 && !(p in anc); p = ppid[p]) anc[p] = 1
    n = 0
    for (p in cmd) if (!(p in anc) && cmd[p] ~ /claude .*[" ]\/build /) n++
    print n
  }'
