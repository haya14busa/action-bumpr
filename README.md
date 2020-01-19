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
