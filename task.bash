IFS=$'\n'
set -o noglob

read -rd '' Def <<'END'
def() {
  local command
  printf -v command '%q ' "$@"
  def() ( $command; ) # notice parens for subshell
  [[ $command != *'$1'* ]] && run || loop
}
END

eval "$Def"

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
  [[ -v Conditions[$Task] ]] && {
    eval ${Conditions[$Task]} && {
      echo "[$Task] ok$suffix"
      Ok[$Task]=1
      eval "$Def"
      return
    }
  }

  local rc
  output=$( def $* ) && eval ${Conditions[$Task]} && rc=$? || rc=$?
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
  eval "$Def"
}

section() {
  echo "[section $1]"
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
