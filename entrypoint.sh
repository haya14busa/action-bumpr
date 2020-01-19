#!/bin/sh
set -e

if [ -n "${GITHUB_WORKSPACE}" ]; then
  cd "${GITHUB_WORKSPACE}" || exit
fi

EVENT_PATH="${GITHUB_EVENT_PATH}"
if [ -n "${INPUT_GITHUB_EVENT_PATH}" ]; then
  EVENT_PATH="${INPUT_GITHUB_EVENT_PATH}"
fi

MERGED=$(jq -r .pull_request.merged < "${EVENT_PATH}")

if [ "${MERGED}" != "true" ]; then
  echo "It's not running on pull request merged event."
  exit 1
fi

LABELS=$(jq -r '.pull_request.labels | .[].name' < "${EVENT_PATH}")
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
  echo "::set-output name=skip::true"
  exit
fi
echo "Bump ${BUMP_LEVEL} version"

git fetch --tags # Fetch existing tags before bump.
NEXT_VERSION=$(bump ${BUMP_LEVEL})

if [ -z "${NEXT_VERSION}" ]; then
  echo "Cannot find next version."
  exit 1
fi
echo "::set-output name=next_version::${NEXT_VERSION}"

PR_NUMBER=$(jq -r .pull_request.number < "${EVENT_PATH}")
PR_TITLE=$(jq -r .pull_request.title < "${EVENT_PATH}")
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
