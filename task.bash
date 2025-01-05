IFS=$'\n'
set -o noglob

group() { echo "[group $1]"; }

ok() { Conditions[$CurrentTask]=$1; }

run() {
  local task=${1:-$CurrentTask}
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
