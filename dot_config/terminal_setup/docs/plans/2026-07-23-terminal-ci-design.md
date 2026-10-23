# Terminal Tooling CI Design

Date: 2026-07-23

## Objective

Add a small, deterministic GitHub Actions gate for the terminal-tooling code before merging the existing private pull request. The workflow must exercise the repository's real tests and static checks without receiving write permissions, credentials, deployment authority, or access to workstation state.

## Selected design

Use one job on GitHub's explicitly supported `ubuntu-24.04` hosted runner. Run on pull requests targeting `main`, pushes to `main`, and manual dispatch. Give `GITHUB_TOKEN` only `contents: read`, cancel superseded runs for the same ref, and cap the job at ten minutes.

Check out the repository with the current official `actions/checkout` v7.0.1 commit SHA and disable persisted credentials. Install the small cross-platform test dependencies from Ubuntu packages, install actionlint v1.7.12 from its pinned Go module, and run:

- actionlint against the workflow;
- the Herdr refresh Bats suite;
- the repository-audit Bats suite;
- ShellCheck and shfmt against the managed scripts;
- Zsh syntax checks against the managed startup files;
- `git diff --check`.

GitHub documents `ubuntu-24.04` as a supported hosted-runner label and supports workflow-level permissions, concurrency cancellation, and timeouts. The checkout action and actionlint versions were verified from their official GitHub releases immediately before implementation.

## Alternatives rejected

- A macOS runner is closer to the workstation but consumes substantially more private-repository minutes and is unnecessary because the tests isolate platform-specific behavior.
- Merging without CI would leave regressions dependent on manual workstation checks.
- A large matrix, third-party package-install action, or self-hosted runner would add cost, permissions, or maintenance without improving this repository's current coverage.

## Failure and recovery

The workflow never mutates external systems. A failed job blocks this merge operationally: inspect the failing step, reproduce it locally, correct the branch, and rerun. If the workflow itself is unsuitable, remove its single YAML file; all local refresh functionality remains unchanged.

## Sources

- GitHub workflow syntax: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax
- GitHub-hosted runners: https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- Checkout releases: https://github.com/actions/checkout/releases
- Actionlint releases: https://github.com/rhysd/actionlint/releases
