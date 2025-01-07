IFS=$'\n' # disable word splitting for most whitespace - this is required
set -uf   # error on unset variable references and turn off globbing - globbing off is required

# auto turns off auto-conditions
auto:() { [[ $1 == off ]] && Auto=0 || Auto=1 }

# become tells the task to run under sudo as user $1
become:() { Become=$1; }

# Def is the default implementation of `def:`.
# The user calls the default implementation when they define the task using `def:`. The default
# implementation accepts a task as arguments and redefines def to run that command, running
# it indirectly by then calling run, or loop if there is a '$1' argument in the task.
Def() {
  (( $# == 0 )) && { LoopCommands; return; } # if no arguments, the inputs are commands
  (( $# == 1 )) && {                         # if one argument, treat it as a quoted script
    eval "def:() { $1; }"
    [[ $1 == *'$1'* ]] && loop || run

    return
  }

  # otherwise compose a simple command from the arguments
  local command
  printf -v command '%q ' "$@"
  eval "def:() { $command; }"
  run
}

# loop runs def indirectly by looping through stdin and
# feeding each line to `run` as an argument.
loop() {
  while IFS=$' \t' read -r line; do
    run $line
  done
}

# LoopCommands runs each line of input as its own task.
LoopCommands() {
  while IFS=$' \t' read -r line; do
    eval "def:() { $line; }"
    run $line
  done
}

# ok adds sets the ok condition.
ok:() { Auto=0; Condition=$1; }

# progress tells the task to show output as it goes.
# We want to see task progression on long-running tasks.
progress:() { [[ $1 == on ]] && ShowProgress=1 || ShowProgress=0; }

declare -A Ok=()            # tasks that were already satisfied
declare -A Changed=()       # tasks that succeeded

# run runs def after checking that it is not already satisfied and records the result.
# Task must be set externally already.
run() {
  (( Auto )) && SetAutoCondition $*
  local task=$Task${1:+ - }${1:-}
  [[ $Condition != '' ]] && eval $Condition && {
    Ok[$task]=1
    echo -e "[ok]\t\t$task"

    return
  }

  if RunCommand $* && eval $Condition; then
    Changed[$task]=1
    echo -e "[changed]\t$task"
  else
    echo -e "[failed]\t$task"
    [[ $Output != '' ]] && echo -e "[output:]\n$Output\n"
    echo '[stopped due to failure]'
    (( rc == 0 )) && echo '[condition not met]'
    exit $rc
  fi
}

# RunCommand runs def and captures the output, optionally showing progress.
# We cheat and refer to the task from the outer scope, so this can only be run by `run`.
RunCommand() {
  local command
  [[ $Become == '' ]] &&
    command=( def: $* ) ||
    command=( sudo -u $Become bash -c "$(declare -f def:); def: $*" )

  (( ShowProgress )) && {
    echo -e "[progress]\t$task"
    "${command[@]}"

    return
  }

  Output=$( "${command[@]}" 2>&1 )
}


# section announces the section name and runs the named section function.
section() {
  echo -e "\n[section $1]"
  $1
}

# SetAutoCondition examines the task for commands that we can automatically set a condition for.
SetAutoCondition() {
  local first second third fourth rest
  while IFS=$' \t' read -r first second third fourth rest; do
    case $first in
      ln|mkdir ) Condition="[[ -e $fourth ]]";;
    esac
  done <<<$(declare -f def:)
}

# strict toggles strict mode for word splitting, globbing, unset variables and error on exit.
# It is used to set expectations properly for third-party code you may need to source.
# "off" turns it off, anything else turns it on.
# It should not be used in the global scope, only when in a function like main or a section.
# We reset this on every task.
# While the script starts by setting strict mode, it leaves out exit on error,
# which *is* covered here.
strict() {
  [[ $1 == off ]] && {
    IFS=$' \t\n'
    set +euf

    return
  }

  IFS=$'\n'
  set -euf
}

# summarize is run by the user at the end to report the results.
summarize() {
cat <<END

[summary]
ok:      ${#Ok[*]}
changed: ${#Changed[*]}
END
}

# task defines the current task and, if given other arguments, creates a task and runs it.
# Tasks can loop if they include a '$1' argument and get fed items via stdin.
# It resets def if it isn't given a command in arguments.
task:() {
  Task=$1


  # reset strict, shared variables and the def function
  strict on

  Auto=1
  Become=''
  Condition=''
  Output=''
  ShowProgress=0

  def:() { Def "$@"; }

  (( $# == 1 )) && return
  shift

  def: "$@"
}
