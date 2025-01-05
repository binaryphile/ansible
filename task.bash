IFS=$'\n'
set -o noglob

group() { :; }

ok() {
  Conditions[$CurrentTask]=$1
}

run() {
  (( $# > 1 )) && { local group=$1; shift; }
  local -a tasks="( $1 )"

  [[ -v group ]] && echo -e "\n[group $group]"

  local task
  for task in ${tasks[*]}; do
    [[ -v Conditions[$task] ]] && {
      eval ${Conditions[$task]} && {
        echo "[$task] ok"
        Ok[$task]=1
        continue
      }
    }

    $task
    case $? in
      0 )
        echo "[$task] changed"
        Changed[$task]=1
        ;;
      * )
        echo "[$task] failed"
        Failed[$task]=1
        ;;
    esac
  done
}

summarize() {
  echo -e "\nsummary\n-------"

  local map
  local keys=()
  for map in ${Maps[*]}; do
    local -n m=$map
    keys=( ${!m[*]} )
    echo "${map,}: ${#keys[*]}"
  done
}

task() {
  CurrentTask=$1
  (( $# == 1 )) && return
  shift

  local command
  printf -v command '%q ' "$@"
  eval "$CurrentTask() {
    $command
  }"
}

Maps=(
  Ok
  Changed
  Failed
)
declare -A ${Maps[*]} Conditions
CurrentGroup=''
CurrentTask=''
