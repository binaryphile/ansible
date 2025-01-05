IFS=$'\n'
set -o noglob

_initdef() {
  def() {
    _redef "$@"
    [[ $* != *'$1'* ]] && run || loop
  }
}
_initdef

_redef() {
  local command
  printf -v command '%q ' "$@"
  def() { $command; }
}

loop() {
  while read -r line; do
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
    echo "[$Task] ok$suffix"
    _initdef

    return
  }

  local output rc
  output=$( def $* ) && eval ${Conditions[$Task]:-} && rc=$? || rc=$?
  case $rc in
    0 )
      Changed[$Task]=1
      echo "[$Task] changed$suffix"
      ;;
    * )
      Failed[$Task]=1
      echo "[$Task] failed$suffix"
      echo "$output"
      ;;
  esac
  _initdef
}

section() {
  echo -e "\n[section $1]"
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
