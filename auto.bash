# auto turns off auto-conditions for a task.
# The setting only affects the current task.
# It can be enabled or disabled.
auto:() { [[ $1 == off ]] && AutoCheck=0 || AutoCheck=1; }

declare -A AutoConditions=(	# conditions for auto-detected commands
  [ln]='echo "[[ -e $2 ]]"'       # the target path
  [mkdir]='echo "[[ -e $1 ]]"'    # the directory
  [curl]='echo "[[ -e ${2#<} ]]"' # the outfile
)

# CheckForAutoCondition examines the task for commands that we can automatically set a condition for.
CheckForAutoCondition() {
  (( Keyed )) && Condition='eval "$( GetVariables $* )"; '

  local line lines
  ! read -rd '' -a lines <<<"$( declare -f def: )" # ! to avoid error

  for line in ${lines[*]}; do
    local field fields
    IFS=$' \t' read -ra fields <<<"$line"
    (( ${#fields[*]} == 0 )) || [[ "$IFS${!AutoConditions[*]}$IFS" != *"$IFS${fields[0]}$IFS"* ]] && continue

    set --
    for field in ${fields[*]:1}; do
       [[ $field != -* ]] && set -- $* $field
    done

    Condition+=$( eval ${AutoConditions[${fields[0]}]} )
  done
}

# InitTaskEnv initializes all relevant settings for a new task.
InitTaskEnv() {
  # reset strict, shared variables and the def function
  strict on

  AutoCheck=1               # flag to check for automatic conditions for known commands
  BecomeUser=''             # the user to sudo with
  Condition=''              # an expression to tell when the task is already satisfied
  Output=''                 # output from the task, including stderr
  ShowProgress=0            # flag for showing output as the task runs
  UnchangedText=''          # text to test for in the output to see task didn't change anything (i.e. is ok)

  def:() { Def "$@"; }
}

# run runs def after checking that it is not already satisfied and records the result.
# Task must be set externally already.
run() {
  (( AutoCheck )) && [[ $Condition == '' ]] && CheckForAutoCondition

  local task=$Task${1:+ - }${1:-}
  [[ $Condition != '' ]] && ( eval $Condition ) && {
    Ok[$task]=1
    echo -e "[ok]\t\t$task"

    Condition=''

    return
  }

  ! (( ShowProgress )) && (( $# == 0 )) && echo -e "[begin]\t\t$task"

  local rc
  RunCommand $* && rc=$? || rc=$?

  if [[ $UnchangedText != '' && $Output == *"$UnchangedText"* ]]; then
    Ok[$task]=1
    echo -e "[ok]\t\t$task"
  elif (( rc == 0 )) && ( eval $Condition ); then
    Changed[$task]=1
    echo -e "[changed]\t$task"
  else
    echo -e "[failed]\t$task"
    ! (( ShowProgress)) && echo -e "[output:]\n$Output\n"
    echo '[stopped due to failure]'
    (( rc == 0 )) && echo '[task reported success but condition not met]'

    exit $rc
  fi

  Condition=''
}
