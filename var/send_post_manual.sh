#!/bin/sh

set -eu

while getopts u:r:b:s: name; do
  case $name in
    u)  URL="${OPTARG}";;
    r)  FULL_NAME="${OPTARG}";;
    b)  BRANCH="${OPTARG}";;
    s)  SECRET_TOKEN="${OPTARG}";;
    ?)  exit 2;;
  esac
done

HASH_ALG='sha256'

POST="$(
  printf "%s\n" "${FULL_NAME}"
  printf "%s\n" "${BRANCH}"
)"

SIGNATURE="$(
  printf "%s" "${POST}" \
  | openssl dgst "-${HASH_ALG}" -hmac "${SECRET_TOKEN}" \
  | cut -d ' ' -f 2
)"

HTTP_X_MAN_SIGNATURE="${HASH_ALG}=${SIGNATURE}"

wget -O - --post-data "${POST}" --user-agent='send_post_manual' \
  --header="X-Man-Signature: ${HTTP_X_MAN_SIGNATURE}" \
  "${URL}"
