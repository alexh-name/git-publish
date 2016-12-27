#!/bin/mksh
# (c) alexh 2016

set -eu

printf "%s\n\n" 'Content-type: text/plain'

# Optional with use of 'check_interval'
WANTED_INTERVAL='10'

USER="$( /usr/bin/whoami )"
HOMES_DIR='/home'
WWW_DIR="/var/www/virtual/${USER}"

HOME="${HOMES_DIR}/${USER}"
VAR_DIR="${HOME}/var/git-publish"
SRC_DIR="${HOME}/git"

function identify_service {
  case "${HTTP_USER_AGENT}" in
    send_post_manual)
      printf "%s\n" 'Service identified as send_post_manual. Hi!'
      . "${VAR_DIR}"/read_post_manual
      ;;
    GitHub-Hookshot/*)
      printf "%s\n" 'Service identified as GitHub.'
      . "${VAR_DIR}"/read_post_github
      ;;
    *)
      printf "%s\n" "I don't know service ${HTTP_USER_AGENT}."
      exit 73
      ;;
  esac
}

POST="$(cat)"
if [ -z "${POST}" ]; then
  printf "%s\n" 'POST empty'
  exit 70
fi

function check_signature {
  get_sig
  if [ "${SIGNATURE}" == "${POST_SIG}" ]; then
    printf "%s\n" 'POST body: Good signature'
  else
    printf "%s\n" 'POST body: Wrong signature'
    exit 79
  fi
}

function id_values {
  ID_VALUES="$( /bin/grep -E "^${ID}\ " "${VAR_DIR}"/list.txt )"

  REPO="$( /bin/awk '{print $1}'<<<"${ID_VALUES}" )"
  BRANCH="$( /bin/awk '{print $2}'<<<"${ID_VALUES}" )"
  BUILD_FUNCTION="$( /bin/awk '{print $3}'<<<"${ID_VALUES}" )"
  URL="$( /bin/awk '{print $4}'<<<"${ID_VALUES}" )"
  SECRET_TOKEN="$( /bin/awk '{print $5}'<<<"${ID_VALUES}" )"

  REPO_DIR="${VAR_DIR}/${REPO}"

  if [ ! -d "${REPO_DIR}" ]; then
    mkdir -p "${REPO_DIR}"
  fi
}

function check_interval {
  CALLTIME="$( /bin/date +%s )"
  if [ ! -f "${REPO_DIR}"/last.txt ];then
    printf "%d\n" '0' >"${REPO_DIR}"/last.txt
  fi
  LAST_CALLTIME="$( <"${REPO_DIR}"/last.txt )"
  INTERVAL="$(( ${CALLTIME} - ${LAST_CALLTIME} ))"
  TIME_LEFT="$(( ${WANTED_INTERVAL} - ${INTERVAL} ))"
  if [ ! -f "${REPO_DIR}"/waiting.txt ];then
    printf "%d\n" '0' >"${REPO_DIR}"/waiting.txt
  fi
  WAITING="$( <"${REPO_DIR}"/waiting.txt )"
  if [ "${WAITING}" == 1 ]; then
    CASE='waiting'
  else
    if (( "${INTERVAL}" > "${WANTED_INTERVAL}" )); then
      CASE='ready'
    else
      CASE='too_soon'
    fi
  fi
}

function update {
  cd "${SRC_DIR}"/"${REPO}"
  printf "%s" "Git checkout: "
  /usr/bin/git checkout "${BRANCH}"
  printf "%s" "Git pull: "
  /usr/bin/git pull
  . "${VAR_DIR}"/"${BUILD_FUNCTION}"
  build
  rsync -qaP --del --exclude-from='.gitignore' dest/ "${WWW_DIR}"/"${URL}"/
  printf "%s\n" 'Synced'
}

function update_stuff {
  case "${CASE}" in
  waiting)
    printf "Update in queue. %d seconds left.\n" "${TIME_LEFT}"
    exit 72
    ;;
  ready)
    printf "%s\n" "${CALLTIME}" >"${REPO_DIR}"/last.txt
    ;;
  too_soon)
    printf "%d\n" '1' >"${REPO_DIR}"/waiting.txt
    TIME_LEFT="$(( ${WANTED_INTERVAL} - ${INTERVAL} ))"
    printf "Waiting for %d seconds.\n" "${TIME_LEFT}"
    sleep "${TIME_LEFT}"
    ;;
  esac
  if [ ! -f "${REPO_DIR}"/progress.txt ]; then
    printf "%d\n" '0' >"${REPO_DIR}"/progress.txt
  fi
  progress="$(<"${REPO_DIR}"/progress.txt)"
  while (( "${progress}" == '1' )); do
    progress="$(<"${REPO_DIR}"/last.txt)"
    printf "%s\n" 'Earlier update in progress. Waiting...'
    sleep 1
  done
  printf "%s\n" 'Ready'
  printf "%d\n" '1' >"${REPO_DIR}"/progress.txt
  update
  printf "%s\n" "${CALLTIME}" >"${REPO_DIR}"/last.txt
  printf "%d\n" '0' >"${REPO_DIR}"/progress.txt
  printf "%d\n" '0' >"${REPO_DIR}"/waiting.txt
}

identify_service
read_post
id_values
check_signature
CASE='ready'
check_interval
update_stuff
