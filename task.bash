IFS=$'\n'
set -o noglob

group() {
  CurrentGroup=$1
}

ok() {
  local key=$CurrentGroup${CurrentGroup:+.}$CurrentTask
  Conditions[$key]=$1
}

run() {
  local group=''
  case $# in
    1 ) local -a tasks="($1)";;
    2 )
      group=$1
      local -a tasks="($2)"
      ;;
  esac

  [[ $group != '' ]] && echo -e "\n[group $group]"

  local task
  for task in ${tasks[*]}; do
    local key=$group${group:+.}$task
    [[ -v Conditions[$key] ]] && {
      eval ${Conditions[$key]} && {
        echo "[$key] ok"
        Ok[$key]=1
        break
      }
    }

    $key
    case $? in
      0 )
        echo "[$key] changed"
        Changed[$key]=1
        ;;
      * )
        echo "[$key] failed"
        Failed[$key]=1
        ;;
    esac
  done
}

summarize() {
  echo -e "\nsummary\n-------"
  local map
  for map in ${Maps[*]}; do
    local -n m=$map
    local keys=( ${!m[*]} )
    echo "${map,}: ${#keys[*]}"
  done
}

task() {
  CurrentTask=$1
  (( $# == 1 )) && return
  shift

  local key=$CurrentGroup${CurrentGroup:+.}$CurrentTask
  local command
  printf -v command '%q ' "$@"
  eval "$key() {
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
