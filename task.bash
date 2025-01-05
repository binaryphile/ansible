IFS=$'\n'
set -o noglob

group() {
  CurrentGroup=$1
}

ok() {
  local key=$CurrentGroup${CurrentGroup:+-}$CurrentTask
  Conditions[$key]=$1
}

run() {
  local tasklist
  local group=''
  case $# in
    1 ) tasklist=$1;;
    2 )
      group=$1
      tasklist=$2
      ;;
  esac

  [[ $group != '' ]] && echo -e "\ngroup $group"

  local task
  for task in $tasklist; do
    local key=$group${group:+-}$task
    [[ -v Conditions[$key] ]] && {
      eval "${Conditions[$key]}" && {
        echo "[$task] ok"
        Ok[$key]=1
        break
      }
    }

    eval "${Tasks[$key]}"
    case $? in
      0 )
        echo "[$task] changed"
        Changed[$key]=1
        ;;
      * )
        echo "[$task] failed"
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
  (( $# > 1 )) && shift
  local key=$CurrentGroup${CurrentGroup:+-}$CurrentTask
  printf -v Tasks[$key] '%q ' "$@"
}

Maps=(
  Ok
  Changed
  Failed
)
declare -A ${Maps[*]} Conditions Tasks
CurrentGroup=''
CurrentTask=''
