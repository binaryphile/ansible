IFS=$'\n'
set -o noglob
set -o nounset

# _def is the default implementation of the def function.
# The user calls the default implementation when they define the task using def. The default
# implementation accepts a task as arguments and redefines def to run that command, running
# it indirectly by then calling run, or loop if there is a '$1' argument in the task.
_def() {
  (( $# == 0 )) && { _loop_commands; return; }
  (( $# == 1 )) && {
    eval "def:() { $1; }"
    [[ $1 == *'$1'* ]] && loop || run

    return
  }

  local command
  printf -v command '%q ' "$@"
  eval "def:() { $command; }"
  run
}

# become tells the task to run under sudo as user $1
become:() { Become=$1; }

# loop runs def indirectly by looping through stdin and
# feeding each line to `run` as an argument.
loop() {
  while IFS=$' \t\n' read -r line; do
    run $line
  done
}

# loop_commands runs each line of input as its own task.
_loop_commands() {
  while IFS=$' \t\n' read -r line; do
    eval "def:() { $line; }"
    run
  done
}

declare -A Conditions=()  # conditions telling when a task is satisfied

# ok adds a condition to Conditions.
ok:() { Conditions[$Task]=$1; }

declare -A Ok=()            # tasks that were already satisfied
declare -A Changed=()       # tasks that succeeded
declare -A Failed=()        # tasks that failed
Maps=( Ok Changed Failed )  # names of the maps included in the summary

# run runs def after checking that it is not already satisfied and records the result.
# Task must be set externally already.
run() {
  local condition=${Conditions[$Task]:-}
  local task=$Task${1:+ - }${1:-}
  [[ $condition != '' ]] && eval $condition && {
    Ok[$task]=1
    echo -e "[ok]\t\t$task"

    return
  }

  local command
  [[ $Become == '' ]] && 
    command=( def: $* ) ||
    command=( sudo -u $Become bash -c "$(declare -f def:); def: $*" )

  local output rc
  output=$( ${command[*]} 2>&1 ) && rc=$? || rc=$?
  if $rc && eval $condition; then
    Changed[$task]=1
    echo -e "[changed]\t$task"
  else
    Failed[$task]=1
    echo -e "[failed]\t$task"
    echo "$output"
    exit 1
  fi
}

# section announces the section name and runs the named section function.
section() {
  echo -e "\nSection $1"
  $1
}

# summarize is run by the user at the end to report the results by examining the maps.
summarize() {
  echo -e '\nsummary\n-------'

  local m
  for m in ${Maps[*]}; do
    local -n map=$m
    echo "${m,}: ${#map[*]}"
  done
}

# task defines the current task and, if given other arguments, creates a task and runs it.
# Tasks can loop if they include a '$1' argument and get fed items via stdin.
# It resets def if it isn't given a command in arguments.
task:() {
  Task=$1
  Become=''
  unset -v Conditions[$Task]
  def:() { _def "$@"; }

  (( $# == 1 )) && return
  shift

  def: "$@"
}
