IFS=$'\n'
set -o noglob

_initdef() {
  def() {
    local arg command running=1
    for arg in "$@"; do
      if [[ arg == '$1' ]]; then
        running=0
      else
        printf -v arg %q $arg
      fi
      command+="$arg "
    done
    eval "def() { $command; }"

    (( running )) && run || loop
  }
}
_initdef

loop() {
  while IFS=$' \t\n' read -r line; do
    run $line
  done
}

Task=''
declare -A Conditions

ok() { Conditions[$Task]=$1; }

declare -A Ok=() Changed=() Failed=()
Maps=( Ok Changed Failed )

run() {
  local suffix=${1:+ - }${1:-}
  [[ -v Conditions[$Task] ]] && eval ${Conditions[$Task]} && {
    Ok[$Task]=1
    echo -e "[ok]\t\t$Task$suffix"
    _initdef

    return
  }

  local output rc
  output=$( def $* 2>&1 ) && eval ${Conditions[$Task]:-} && rc=$? || rc=$?
  case $rc in
    0 )
      Changed[$Task]=1
      echo -e "[changed]\t$Task$suffix"
      ;;
    * )
      Failed[$Task]=1
      echo -e "[failed]\t$Task$suffix"
      echo "$output"
      ;;
  esac
  _initdef
}

section() {
  echo -e "\nSection $1"
  $1
}

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

  def "$@"
}
