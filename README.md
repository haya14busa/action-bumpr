# action-bumpr

[![Test](https://github.com/haya14busa/action-bumpr/workflows/Test/badge.svg)](https://github.com/haya14busa/action-bumpr/actions?query=workflow%3ATest)
[![reviewdog](https://github.com/haya14busa/action-bumpr/workflows/reviewdog/badge.svg)](https://github.com/haya14busa/action-bumpr/actions?query=workflow%3Areviewdog)
[![release](https://github.com/haya14busa/action-bumpr/workflows/release/badge.svg)](https://github.com/haya14busa/action-bumpr/actions?query=event%3Apull_request+workflow%3Arelease)

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
  pull_request:
    types: [closed]

jobs:
  release:
    # Skip on Pull Request Close event.
    if: "!(github.event_name == 'pull_request' && !github.event.pull_request.merged)"
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
        with:
          # Specify ref explicitly because it doesn't work with Pull Request closed event.
          # https://github.com/actions/checkout/issues/136
          ref: ${{ github.ref }}

      # Bump version on merging Pull Requests with specific labels. (bump:major,bump:minor,bump:patch)
      - if: github.event.pull_request.merged
        uses: haya14busa/action-bumpr@v1
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
    branches-ignore:
      - '**'
    tags:
      - 'v*.*.*'
  pull_request:
    types: [closed]

jobs:
  release:
    # Skip on Pull Request Close event.
    if: "!(github.event_name == 'pull_request' && !github.event.pull_request.merged)"
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
        # Specify ref explicitly because it doesn't work with Pull Request closed event.
        # https://github.com/actions/checkout/issues/136
        with:
          ref: ${{ github.ref }}

      # Bump version on merging Pull Requests with specific labels. (bump:major,bump:minor,bump:patch)
      - id: bumpr
        if: github.event.pull_request.merged
        uses: haya14busa/action-bumpr@v1

      # Update corresponding major and minor tag. e.g. Update v1 and v1.2 when releasing v1.2.3
      - uses: haya14busa/action-update-semver@v1
        if: "!steps.bumpr.outputs.skip"
        with:
          github_token: ${{ secrets.github_token }}
          tag: ${{ steps.bumpr.outputs.next_version }}
```
