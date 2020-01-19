#!/bin/sh
set -e

if [ -n "${GITHUB_WORKSPACE}" ]; then
  cd "${GITHUB_WORKSPACE}" || exit
fi

# Sample: Get star count of INPUT_REPO.
get_repo() {
  if [ -n "${INPUT_GITHUB_TOKEN}" ]; then
    echo "Use INPUT_GITHUB_TOKEN to get release data." >&2
    curl -s -H "Authorization: token ${INPUT_GITHUB_TOKEN}" "https://api.github.com/repos/${INPUT_REPO}"
  else
    echo "INPUT_GITHUB_TOKEN is not available. Subscequent GitHub API call may fail due to API limit." >&2
    curl -s "https://api.github.com/repos/${INPUT_REPO}"
  fi
}
STAR_COUNT=$(get_repo | jq -r '.stargazers_count')
if [ -z "${STAR_COUNT}" ] || [ "${STAR_COUNT}" = "null" ]; then
  echo "cannot get star count from ${INPUT_REPO}"
  exit 1
fi

echo "::set-output name=star::${STAR_COUNT}"
