#!/bin/sh
set -e

if [ -n "${GITHUB_WORKSPACE}" ]; then
  cd "${GITHUB_WORKSPACE}" || exit
fi

MERGED=$(jq -r .pull_request.merged < "${GITHUB_EVENT_PATH}")

if [ "${MERGED}" != "true" ]; then
  echo "It's not running on pull request merged event."
  exit 1
fi

LABELS=$(jq -r '.pull_request.labels | .[].name' < "${GITHUB_EVENT_PATH}")
BUMP_LEVEL="${INPUT_DEFAULT_BUMP_LEVEL}"
if echo "${LABELS}" | grep "bump:major" ; then
  BUMP_LEVEL="major"
elif echo "${LABELS}" | grep "bump:minor" ; then 
  BUMP_LEVEL="minor"
elif echo "${LABELS}" | grep "bump:patch" ; then 
  BUMP_LEVEL="patch"
fi

if [ -z "${BUMP_LEVEL}" ]; then
  echo "Labels for bump not found. Do nothing."
  exit
fi
echo "Bump ${BUMP_LEVEL} version"

NEXT_VERSION=$(bump ${BUMP_LEVEL})

if [ -z "${NEXT_VERSION}" ]; then
  echo "Cannot find next version."
  exit
fi
echo "::set-output name=next_version::${NEXT_VERSION}"

PR_NUMBER=$(jq -r .pull_request.number < "${GITHUB_EVENT_PATH}")
PR_TITLE=$(jq -r .pull_request.title < "${GITHUB_EVENT_PATH}")
TAG_MESSAGE="${NEXT_VERSION}\nMerged #${PR_NUMBER}: ${PR_TITLE}"

if [ "${INPUT_DRY_RUN}" = "true" ]; then
  echo "DRY_RUN=true. Do not tag next version."
  echo "PR_NUMBER=${PR_NUMBER}"
  echo "PR_TITLE=${PR_TITLE}"
  echo "TAG_MESSAGE=${TAG_MESSAGE}"
  exit
fi
git tag -a "${NEXT_VERSION}" -m "${NEXT_VERSION}\nPR #${PR_NUMBER} - ${PR_TITLE}"
git push origin "${NEXT_VERSION}"
