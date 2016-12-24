#!/home/ship/bin/mksh

# HC SVNT DRACONES
# Apparently you are not encouraged to use shell as CGI scripts.
# Use at own risk.

# Meant as CGI script to pull a repository/branch(, build) and publish stuff.
# Listening for a POST including information:
# * User-Agent (to identify service)
# * Signature of POST for identification of legitimacy
# * Full name of repository (USER/REPOSITORY)
# * Branch to use
#
# VAR_DIR/list.txt holds a list of information for every project:
# FULL_NAME BRANCH BUILD_FUNCTION URL SECRET_TOKEN
# with one project per line and each value separated by whitespace.
#
# Optionally using a timer to cap execution per time.
# Put files specific to your service into your VAR_DIR to provide suitable
# functions 'read_post', 'build' and 'get_sig'. Examples in var/.

# Error codes:
# * 70: POST empty.
# * 72: There's already an update in queue.
# * 73: Service identified by User-Agent not known
#      (hence no function to handle POST).
# * 79: Signature of POST didn't match.

# (c) alexh 2016


set -eu

printf "%s\n\n" 'Content-type: text/plain'

# Optional with use of 'check_interval'
WANTED_INTERVAL='10'

USER="$(whoami)"
HOMES_DIR='/home'
WWW_DIR="/var/www/virtual/${USER}"

HOME="${HOMES_DIR}/${USER}"
PATH="${PATH}:${HOME}/bin/"
VAR_DIR="${HOME}/var/git-publish"
SRC_DIR="${HOME}/git"

function identify_service {
  case "${HTTP_USER_AGENT}" in
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
  if [ "${SIGNATURE}" == "${SIG_HASH}" ]; then
    printf "%s\n" 'POST body: Good signature'
  else
    printf "%s\n" 'POST body: Wrong signature'
    exit 79
  fi
}

function id_values {
  ID_VALUES="$( grep -E "^${ID}\ " "${VAR_DIR}"/list.txt )"

  REPO="$( awk '{print $1}'<<<"${ID_VALUES}" )"
  BRANCH="$( awk '{print $2}'<<<"${ID_VALUES}" )"
  BUILD_FUNCTION="$( awk '{print $3}'<<<"${ID_VALUES}" )"
  URL="$( awk '{print $4}'<<<"${ID_VALUES}" )"
  SECRET_TOKEN="$( awk '{print $5}'<<<"${ID_VALUES}" )"

  REPO_DIR="${VAR_DIR}/${REPO}"

  if [ ! -d "${REPO_DIR}" ]; then
    mkdir -p "${REPO_DIR}"
  fi
}

function check_interval {
  CALLTIME="$( date +%s )"
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
  git checkout "${BRANCH}"
  printf "%s" "Git pull: "
  git pull
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
check_signature
CASE='ready'
check_interval
update_stuff
