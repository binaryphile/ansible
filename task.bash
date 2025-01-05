IFS=$'\n'
set -o noglob

Task=''
declare -A Conditions
ok() { Conditions[$Task]=$1; }

Maps=( Ok Changed Failed )
declare -A ${Maps[*]}
run() {
  [[ -v Conditions[$Task] ]] && {
    eval ${Conditions[$Task]} && {
      echo "[$Task] ok"
      Ok[$Task]=1
      return
    }
  }

  $Task
  case $? in
    0 )
      echo "[$Task] changed"
      Changed[$Task]=1
      ;;
    * )
      echo "[$Task] failed"
      Failed[$Task]=1
      ;;
  esac
}

section() { echo "[section $1]"; }

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
  Task=$1
  (( $# == 1 )) && return
  shift

  local command
  printf -v command '%q ' "$@"
  eval "$Task() {
    $command
  }"
}
