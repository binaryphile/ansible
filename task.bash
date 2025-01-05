IFS=$'\n'
set -o noglob

Task=''
declare -A Conditions
ok() { Conditions[$Task]=$1; }

Maps=( Ok Changed Failed )
for map in ${Maps[*]}; do
  declare -A "$map=()"
done
unset -v map

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

  for m in ${Maps[*]}; do
    local -n map=$m
    echo "${m,}: ${#map[*]}"
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
