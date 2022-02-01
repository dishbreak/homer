#!/bin/bash

set -e

usage=$(cat <<EOF
$0 - tell your story.

Usage:
    $0 add EVENT_TEXT
    $0 create-thread THREAD_NAME
    $0 list-events

Commands:
    init - sets up homer in the working directory
    add - logs an event.
    open-thread - creates and opens a new thread for collecting events.
    list-events - show all events not linked to a log.
    review - conduct a review of all open threads.

EOF
)

command=$1
shift

function do_init() {
    (which sed >/dev/null) || (>&2 echo "sed is not on your path. install sed and try again!"; exit 1)

    [ -f .eventlog ] || touch .eventlog
    [ -d archive ] || mkdir archive
    [ -d threads ] || mkdir threads

    echo "initialized!"
}

function add_event() {
    if [ $# -gt 1 ]; then
        (>&2 echo "too many args")
        return 
    fi

    printf "$(date '+%Y-%m-%d')\t%s\n" "$1" >> .eventlog
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
$(grep -v "^#" .eventlog | uniq | sort -r | sed "s/^/N\t/")
EOF
    "${EDITOR:-vi}" .review.tmp
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

