#!/bin/bash
set -e

if [ -n "${GITHUB_WORKSPACE}" ]; then
  git config --global --add safe.directory "${GITHUB_WORKSPACE}" || exit
  cd "${GITHUB_WORKSPACE}" || exit
fi

# Install bump
echo '::group:: Installing bump ...'
VERSION=v1.1.0
TEMP="$(mktemp -d)"
mkdir -p "${TEMP}/bump/bin"
INSTALL_SCRIPT='https://raw.githubusercontent.com/haya14busa/bump/9ab5412f5d96eb624c7e8559acbb11330be9901a/install.sh'
(
  if command -v curl 2>&1 >/dev/null; then
    curl -sfL "${INSTALL_SCRIPT}"
  elif command -v wget 2>&1 >/dev/null; then
    wget -O - "${INSTALL_SCRIPT}"
  else
    echo "curl or wget is required" >&2
    exit 1
  fi
) | sh -s -- -b "${TEMP}/bump/bin" "${VERSION}" 2>&1
bump="${TEMP}/bump/bin/bump"
echo '::endgroup::'

major_labels_regex="^\"$(echo "$INPUT_MAJOR_LABELS" | cut -d ',' -f1- --output-delimiter='"$|^"')\"$"
minor_labels_regex="^\"$(echo "$INPUT_MINOR_LABELS" | cut -d ',' -f1- --output-delimiter='"$|^"')\"$"
patch_labels_regex="^\"$(echo "$INPUT_PATCH_LABELS" | cut -d ',' -f1- --output-delimiter='"$|^"')\"$"

# Setup these env variables. It can exit 0 for unknown label.
# - LABELS
# - PR_NUMBER
# - PR_TITLE
setup_from_labeled_event() {
  label=$(jq -r '.label.name' < "${GITHUB_EVENT_PATH}")
  if echo "${label}" | grep "(major_labels_regex)|(minor_labels_regex)|(patch_labels_regex)" ; then
    echo "Found label=${label}" >&2
    LABELS="${label}"
  else
    echo "Attached label name does not match with any major, minor or patch label. label=${label}" >&2
    exit 0
  fi
  PR_NUMBER=$(jq -r '.pull_request.number' < "${GITHUB_EVENT_PATH}")
  PR_TITLE=$(jq -r '.pull_request.title' < "${GITHUB_EVENT_PATH}")
}

# Setup these env variables.
# - LABELS
# - PR_NUMBER
# - PR_TITLE
setup_from_push_event() {
  pull_request="$(list_pulls | jq ".[] | select(.merge_commit_sha==\"${GITHUB_SHA}\")")"
  LABELS="$( jq '.labels | .[].name' <<< "${pull_request}" )"
  PR_NUMBER="$( jq -r .number <<< "${pull_request}" )"
  PR_TITLE="$( jq -r .title <<< "${pull_request}" )"
}

list_pulls() {
  pulls_endpoint="${GITHUB_API_URL}/repos/${GITHUB_REPOSITORY}/pulls?state=closed&sort=updated&direction=desc"
  if [ -n "${INPUT_GITHUB_TOKEN}" ]; then
    curl -s -H "Authorization: token ${INPUT_GITHUB_TOKEN}" "${pulls_endpoint}"
  else
    echo "INPUT_GITHUB_TOKEN is not available. Subscequent GitHub API call may fail due to API limit." >&2
    curl -s "${pulls_endpoint}"
  fi
}

post_pre_status() {
  head_label="$(jq -r '.pull_request.head.label' < "${GITHUB_EVENT_PATH}" )"
  compare=""
  if [ -n "${CURRENT_VERSION}" ]; then
    compare="**Changes**:[${CURRENT_VERSION}...${head_label}](${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/compare/${CURRENT_VERSION}...${head_label})"
  fi
  post_txt="🏷️ [[bumpr]](https://github.com/haya14busa/action-bumpr)
**Next version**:${NEXT_VERSION}
${compare}"
  FROM_FORK=$(jq -r '.pull_request.head.repo.fork' < "${GITHUB_EVENT_PATH}")
  if [ "${FROM_FORK}" = "true" ]; then
    post_warning "${post_txt}"
  else
    post_comment "${post_txt}"
  fi
}

post_post_status() {
  compare=""
  if [ -n "${CURRENT_VERSION}" ]; then
    compare="**Changes**:[${CURRENT_VERSION}...${NEXT_VERSION}](${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/compare/${CURRENT_VERSION}...${NEXT_VERSION})"
  fi
  post_txt="🚀 [[bumpr]](https://github.com/haya14busa/action-bumpr) [Bumped!](${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID})
**New version**:[${NEXT_VERSION}](${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/releases/tag/${NEXT_VERSION})
${compare}
"
  post_comment "${post_txt}"
}

# It assumes setup func is called beforehand.
# POST /repos/:owner/:repo/issues/:issue_number/comments
post_comment() {
  body_text="$1"
  endpoint="${GITHUB_API_URL}/repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments"
  # Use jq --arg to properly handle multiline strings
  body="$(jq -n --arg body "${body_text}" '{body: $body}')"
  curl -H "Authorization: token ${INPUT_GITHUB_TOKEN}" -d "${body}" "${endpoint}"
}

post_warning() {
  body_text=$(echo "$1" | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/%0A/g')
  echo "::warning ::${body_text}"
}

# Get labels and Pull Request data.
ACTION=$(jq -r '.action' < "${GITHUB_EVENT_PATH}" )
if [ "${ACTION}" = "labeled" ]; then
  setup_from_labeled_event
else
  setup_from_push_event
fi

BUMP_LEVEL="${INPUT_DEFAULT_BUMP_LEVEL}"
if echo "${LABELS}" | grep -qE "$major_labels_regex" ; then
  BUMP_LEVEL="major"
elif echo "${LABELS}" | grep -qE "$minor_labels_regex" ; then
  BUMP_LEVEL="minor"
elif echo "${LABELS}" | grep -qE "$patch_labels_regex" ; then
  BUMP_LEVEL="patch"
fi

if [ -z "${BUMP_LEVEL}" ]; then
  echo "PR with labels for bump not found. Do nothing."
  echo "skip=true" >> "$GITHUB_OUTPUT"
  exit
fi
echo "Bump ${BUMP_LEVEL} version"

# check the repository is shallowed.
# comes from https://stackoverflow.com/questions/37531605/how-to-test-if-git-repository-is-shallow
if "$(git rev-parse --is-shallow-repository)"; then
  # the repository is shallowed, so we need to fetch all history.
  git fetch --tags -f # Fetch existing tags before bump.
  # Fetch history as well because bump uses git history (git tag --merged).
  git fetch --prune --unshallow
fi

CURRENT_VERSION="$("${bump}" "current")" || true
NEXT_VERSION="$("${bump}" "${BUMP_LEVEL}")" || true

# Set next version tag in case existing tags not found.
if [ -z "${NEXT_VERSION}" ] && [ -z "$(git tag)" ]; then
	case "${BUMP_LEVEL}" in
		major)
			NEXT_VERSION="v1.0.0"
			;;
		minor)
			NEXT_VERSION="v0.1.0"
			;;
		patch)
			NEXT_VERSION="v0.0.1"
			;;
	esac
fi

if [ -z "${NEXT_VERSION}" ]; then
  echo "Cannot find next version."
  exit 1
fi
echo "current_version=${CURRENT_VERSION}" >> "$GITHUB_OUTPUT"
echo "next_version=${NEXT_VERSION}" >> "$GITHUB_OUTPUT"

TAG_MESSAGE="${NEXT_VERSION}: PR #${PR_NUMBER} - ${PR_TITLE}"
echo "message=${TAG_MESSAGE}" >> "$GITHUB_OUTPUT"

if [ "${INPUT_DRY_RUN}" = "true" ]; then
  echo "DRY_RUN=true. Do not tag next version."
  echo "PR_NUMBER=${PR_NUMBER}"
  echo "PR_TITLE=${PR_TITLE}"
  echo "TAG_MESSAGE=${TAG_MESSAGE}"
  exit
fi

if [ "${ACTION}" = "labeled" ]; then
  post_pre_status
else
  # Set up Git.
  git config user.name "${INPUT_TAG_AS_USER:-${GITHUB_ACTOR}}"
  git config user.email "${INPUT_TAG_AS_EMAIL:-${GITHUB_ACTOR}@users.noreply.github.com}"

  # Push the next tag.
  git tag -a "${NEXT_VERSION}" -m "${TAG_MESSAGE}"

  if [ -n "${INPUT_GITHUB_TOKEN}" ]; then
    bare_server_url="${GITHUB_SERVER_URL/#*:\/\//}"
    git -c "http.${GITHUB_SERVER_URL}/.extraheader=" \
      push "https://x-access-token:${INPUT_GITHUB_TOKEN}@${bare_server_url}/${GITHUB_REPOSITORY}.git" \
      "${NEXT_VERSION}"
  else
    git push origin "${NEXT_VERSION}"
  fi

  # Post post-bumpr status on merge.
  post_post_status
fi
