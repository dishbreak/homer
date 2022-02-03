#!/bin/bash

set -e

exec_name=$(basename "$0")

usage=$(cat <<EOF
homer- tell your story.

Usage:
    $exec_name add EVENT_TEXT
    $exec_name open-thread THREAD_NAME
    $exec_name list-events

Commands:
    init - sets up homer in the working directory
    add - logs an event.
    open-thread - creates and opens a new thread for collecting events.
    list-events - show all events not linked to a log.
    review - conduct a review of all open threads.

EOF
)

homer_editor=${EDITOR:-vi}
homer_home=${HOMER_HOME:-${HOME}/.homer}

if [ $# -eq 0 ]; then
    (>&2 echo "$usage")
    exit
fi

command=$1
shift

function do_init() {
    (which sed >/dev/null) || (>&2 echo "sed is not on your path. install sed and try again!"; exit 1)

    [ -f "${homer_home}/.eventlog" ] || touch "${homer_home}/.eventlog"
    [ -d "${homer_home}/archive" ] || mkdir "${homer_home}/archive"
    [ -d "${homer_home}/threads" ] || mkdir "${homer_home}/threads"

    echo "initialized!"
}

function add_event() {
    if [ $# -gt 1 ]; then
        (>&2 echo "too many args")
        return
    fi

    printf "$(date '+%Y-%m-%d')\t%s\n" "$1" | sed "s!/!_!" >> .eventlog
    (uniq .eventlog | sort -r) > .eventlog.swp
    mv .eventlog .eventlog.bak
    mv .eventlog.swp .eventlog
}

function open_thread() {
    if [ $# -gt 1 ]; then
        (>&2 echo "too many args")
        return
    fi

    thread_dir="threads/$1"
    if [ -d "$thread_dir" ]; then
        (>&2 echo "thread already exists")
        return
    fi

    mkdir "$thread_dir"
    touch "$thread_dir/eventlog"
}

function list_events() {
    events=$(grep -v "^#" .eventlog)
    event_count=$(echo "$events"| wc -l)
    echo "$events"
    echo "found $event_count event(s)"
}

function review_events() {
    find ./threads -type d -mindepth 1 | sort | sed "s|^\./threads/||" > .threads.tmp
    cat <<EOF > .review.tmp
# These are your open threads.
$(cat -n .threads.tmp)

# These are the following **unlinked* events.
# To link the event to a thread, replace N with its number
# Don't remove the following line.
##~~~
$(grep -v "^#" .eventlog | uniq | sort -r | sed "s!^!N	!")
EOF
    "$homer_editor" .review.tmp
    sed -ne '/^##~~~$/,$ p' <.review.tmp | sed '1d' > .events.tmp
    rm .review.tmp
    while read -r event; do
        code=$(echo "$event" | cut -f1)
        if [ "$code" = "N" ]; then
            continue
        fi

        thread=$(sed -n "${code}p" <.threads.tmp)
        declare -p thread
        if [ "$thread" = "" ]; then
            continue
        fi

        contents=$(echo "$event" | cut -f2-)
        echo "$contents"
        echo "$contents" >> "threads/$thread/eventlog"
        sed -e "s/^$contents$/# $contents/" .eventlog > .eventlog.swp
        mv .eventlog .eventlog.bak
        mv .eventlog.swp .eventlog
    done < .events.tmp
    rm .events.tmp
    rm .threads.tmp
}

[ -d "${homer_home}" ] || mkdir "${homer_home}"
(
    cd "${homer_home}"
    case "$command" in
        init)
            do_init
            ;;
        add)
            add_event "$1"
            ;;
        open-thread)
            open_thread "$1"
            ;;
        list-events)
            list_events
            ;;
        review-events)
            review_events
            ;;
        *)
            ( >&2 echo "not yet implemented")
    esac
)

