# action-bumpr

![action-bumpr image](https://user-images.githubusercontent.com/3797062/72686834-dc19a980-3b3b-11ea-9a25-3c5be36d45b1.png)

[![Test](https://github.com/haya14busa/action-bumpr/workflows/Test/badge.svg)](https://github.com/haya14busa/action-bumpr/actions?query=workflow%3ATest)
[![reviewdog](https://github.com/haya14busa/action-bumpr/workflows/reviewdog/badge.svg)](https://github.com/haya14busa/action-bumpr/actions?query=workflow%3Areviewdog)
[![release](https://github.com/haya14busa/action-bumpr/workflows/release/badge.svg)](https://github.com/haya14busa/action-bumpr/actions?query=workflow%3Arelease)

**action-bumpr** bumps semantic version tag on merging Pull Requests with
specific lables (`bump:major`,`bump:minor`,`bump:patch`).

## Input

```yaml
inputs:
  default_bump_level:
    description: "Default bump level if labels are not attached [major,minor,patch]. Do nothing if it's empty"
  dry_run:
    description: "Do not actually tag next version if it's true"
outputs:
  next_version:
    description: "next version"
  skip:
    description: "True if release is skipped. e.g. No labels attached to PR."
```

## Usage

### Simple

```yaml
name: release
on:
  push:
    branches:
      - master

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      # Bump version on merging Pull Requests with specific labels.
      # (bump:major,bump:minor,bump:patch)
      - uses: haya14busa/action-bumpr@v1
```

### Integarate with other release related actions.

Integrate with
[haya14busa/action-update-semver](https://github.com/haya14busa/action-update-semver)
to update major and minor tags on semantic version tag release (e.g. update v1
and v1.2 tag on v1.2.3 release).

```yaml
name: release
on:
  push:
    branches:
      - master
    tags:
      - 'v*.*.*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      # Bump version on merging Pull Requests with specific labels.
      # (bump:major,bump:minor,bump:patch)
      - id: bumpr
        if: "!startsWith(github.ref, 'refs/tags/')"
        uses: haya14busa/action-bumpr@v1

      # Update corresponding major and minor tag.
      # e.g. Update v1 and v1.2 when releasing v1.2.3
      - uses: haya14busa/action-update-semver@v1
        if: "!steps.bumpr.outputs.skip"
        with:
          github_token: ${{ secrets.github_token }}
          tag: ${{ steps.bumpr.outputs.next_version }}
```

### Note
action-bumpr uses push on master event to run workflow instead of pull_request
closed (merged) event because github token doesn't have write permission
for pull_request from fork repository.
