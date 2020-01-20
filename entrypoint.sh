#!/bin/sh
set -e

if [ -n "${GITHUB_WORKSPACE}" ]; then
  cd "${GITHUB_WORKSPACE}" || exit
fi

list_pulls() {
  PULLS_ENDPOINT="https://api.github.com/repos/${GITHUB_REPOSITORY}/pulls?state=closed&sort=updated&direction=desc"
  if [ -n "${INPUT_GITHUB_TOKEN}" ]; then
    echo "Use INPUT_GITHUB_TOKEN to list pull requests." >&2
    curl -s -H "Authorization: token ${INPUT_GITHUB_TOKEN}" "${PULLS_ENDPOINT}"
  else
    echo "INPUT_GITHUB_TOKEN is not available. Subscequent GitHub API call may fail due to API limit." >&2
    curl -s "${PULLS_ENDPOINT}"
  fi
}

# Get labels and Pull Request data.
PULL_REQUEST="$(list_pulls | jq ".[] | select(.merge_commit_sha==\"${GITHUB_SHA}\")")"
LABELS=$(echo "${PULL_REQUEST}" | jq '.labels | .[].name')
PR_NUMBER=$(echo "${PULL_REQUEST}" | jq -r .number)
PR_TITLE=$(echo "${PULL_REQUEST}" | jq -r .title)

BUMP_LEVEL="${INPUT_DEFAULT_BUMP_LEVEL}"
if echo "${LABELS}" | grep "bump:major" ; then
  BUMP_LEVEL="major"
elif echo "${LABELS}" | grep "bump:minor" ; then
  BUMP_LEVEL="minor"
elif echo "${LABELS}" | grep "bump:patch" ; then
  BUMP_LEVEL="patch"
fi

if [ -z "${BUMP_LEVEL}" ]; then
  echo "PR with labels for bump not found. Do nothing."
  echo "::set-output name=skip::true"
  exit
fi
echo "Bump ${BUMP_LEVEL} version"

git fetch --tags # Fetch existing tags before bump.
NEXT_VERSION="$(bump ${BUMP_LEVEL})" || true

# Set next version tag in case existing tags not found.
if [ -z "${NEXT_VERSION}" -a -z "$(git tag)" ]; then
	case "${BUMP_LEVEL}" in
		major)
			NEXT_VERSION="v1.0.0"
			break
			;;
		minor)
			NEXT_VERSION="v0.1.0"
			break
			;;
		patch)
			NEXT_VERSION="v0.0.1"
			break
			;;
	esac
fi

if [ -z "${NEXT_VERSION}" ]; then
  echo "Cannot find next version."
  exit 1
fi
echo "::set-output name=next_version::${NEXT_VERSION}"

TAG_MESSAGE="${NEXT_VERSION}: PR #${PR_NUMBER} - ${PR_TITLE}"
echo "::set-output name=message::${TAG_MESSAGE}"

if [ "${INPUT_DRY_RUN}" = "true" ]; then
  echo "DRY_RUN=true. Do not tag next version."
  echo "PR_NUMBER=${PR_NUMBER}"
  echo "PR_TITLE=${PR_TITLE}"
  echo "TAG_MESSAGE=${TAG_MESSAGE}"
  exit
fi

# Set up Git.
git config user.name "${GITHUB_ACTOR}"
git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"

# Push the next tag.
git tag -a "${NEXT_VERSION}" -m "${TAG_MESSAGE}"
git push origin "${NEXT_VERSION}"
