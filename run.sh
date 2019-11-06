#!/usr/bin/env bash
python=./venv/Scripts/python.exe

logfile="error_$(date '+%Y-%m-%d %H%M%S').log"

function run {
    $python DDNS.py
}

function setval { printf -v "$1" "%s" "$(cat)"; declare -p "$1"; }

eval "$( run 2> >(setval errval) > >(setval outval); )"

[[ -n "$errval" ]] && echo -n $errval > "$logfile"