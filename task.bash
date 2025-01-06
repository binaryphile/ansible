IFS=$'\n'
set -o noglob
set -o nounset

# _def is the default implementation of the def function.
# The user calls the default implementation when they define the task using def. The default
# implementation accepts a task as arguments and redefines def to run that command, running
# it indirectly by then calling run, or loop if there is a '$1' argument in the task.
_def() {
  local arg command running=1
  for arg in "$@"; do
    if [[ $arg == *'$1'* ]]; then
      running=0
    else
      printf -v arg %q $arg
    fi
    command+="$arg "
  done
  eval "def() { $command; }"
  (( running )) && run || loop
}

# _resetdef makes _def available as def.
_resetdef() {
  def() { _def "$@"; }
}
_resetdef

# loop runs def indirectly by looping through stdin inputs and calling run.
loop() {
  while IFS=$' \t\n' read -r line; do
    run $line
  done
}

declare -A Conditions  # conditions telling when a task is satisfied
# Task='' # removed so unset task triggers nounset

# ok adds a condition to Conditions.
ok() { Conditions[$Task]=$1; }

declare -A Ok=()            # tasks that were already satisfied
declare -A Changed=()       # tasks that succeeded
declare -A Failed=()        # tasks that failed
Maps=( Ok Changed Failed )  # names of the maps included in the summary

# run runs def after checking that it is not already satisfied and records the result.
# When done, it resets def to the default implementation.
# Task must be set externally already.
run() {
  local condition=${Conditions[$Task]:-}
  local task=$Task${1:+ - }${1:-}
  [[ $condition != '' ]] && eval $condition && {
    Ok[$task]=1
    echo -e "[ok]\t\t$task"
    _resetdef

    return
  }

  local output
  if output=$( def $* 2>&1 ) && eval $condition; then
    Changed[$task]=1
    echo -e "[changed]\t$task"
  else
    Failed[$task]=1
    echo -e "[failed]\t$task"
    echo "$output"
  fi
  _resetdef
}

# section announces the section name and runs the named section function.
section() {
  echo -e "\nSection $1"
  $1
}

# summarize is run by the user at the end to report the results by examining the maps.
summarize() {
  echo -e "\nsummary\n-------"

  for m in ${Maps[*]}; do
    local -n map=$m
    echo "${m,}: ${#map[*]}"
  done
}

# task defines the current task and, if given other arguments, creates a task and runs it.
# Tasks can loop if they include a '$1' argument and get fed items via stdin.
task() {
  Task=$1
  (( $# == 1 )) && return
  shift

  def "$@"
}
