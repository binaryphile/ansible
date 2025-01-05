IFS=$'\n'
set -o noglob

declare -A Conditions
ok() { Conditions[$CurrentTask]=$1; }

Maps=( Ok Changed Failed )
declare -A ${Maps[*]}
run() {
  local task=$CurrentTask
  [[ -v Conditions[$task] ]] && {
    eval ${Conditions[$task]} && {
      echo "[$task] ok"
      Ok[$task]=1
      return
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
  for m in ${Maps[*]}; do
    local -n map=$m
    echo "${map,}: ${#map[*]}"
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
