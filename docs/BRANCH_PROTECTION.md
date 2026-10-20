# Protecting `main`

This is a recommendation for GitHub settings on `ddaa81108-wq/vib-abdo-company-mobile`. Nothing in this repository changes those settings. An owner applies the rule after `.github/workflows/ci.yml` has completed once on `main`. GitHub only offers a check in the rule editor after that check has run.

The release workflow is separate. Leave it off the required-check list. It is manual and tag-driven, and it succeeds without building when the signing secrets are absent. Requiring it would block pull requests. Signing itself is described in `docs/RELEASE.md`.

## Rule

Use a branch ruleset (Settings → Rules → Rulesets → New branch ruleset) or a classic branch protection rule (Settings → Branches). Target `main`.

Apply the rule to everyone, including administrators. A bad commit is reverted with a new pull request. It is not pushed over with `--force`.

## Pull requests

- Require a pull request before merging.
- Require at least one approval.
- Dismiss stale approvals when new commits are pushed.

CODEOWNERS is not in the repo. Add “require review from Code Owners” only after a CODEOWNERS file exists.

## Status checks

`.github/workflows/ci.yml` defines one job. Require that check:

| | |
| --- | --- |
| Workflow `name` | `CI` |
| Job id | `analyze-test-apk` |
| Check name (the job's `name`) | `Analyze, test, and debug APK` |

The check run recorded on a commit is `Analyze, test, and debug APK`. In a ruleset or branch-protection picker it may be listed as `CI / Analyze, test, and debug APK`. Select that one check. It runs `flutter analyze` and `flutter test` for the app and for `packages/api_layer`, then `flutter build apk --debug`.

Also require the branch to be up to date before merging, so a pull request cannot land on a `main` whose checks it never saw.

The debug APK is a compile check. Keep it off Play.

## Force pushes and deletion

- Block force pushes.
- Block deletion of `main`.

## Linear history

Require linear history. `main` is short, release tags are cut from it, and a straight line is what you bisect when a release misbehaves.

Linear history rejects merge commits. In Settings → General → Pull Requests, allow squash merge and turn off merge commits. Rebase merge also stays linear. Squash is the better default here: one commit on `main` per pull request, which is the commit you tag (`v1.2.3`). Tag that squashed commit, not the pre-squash branch tip. `docs/RELEASE.md` describes how the tag must match `pubspec.yaml`.

## Checklist

- [ ] `CI` has completed on `main` at least once
- [ ] Ruleset or branch protection targets `main`
- [ ] Pull request required
- [ ] At least one approval required
- [ ] Stale reviews dismissed
- [ ] Required check: `Analyze, test, and debug APK` (job id `analyze-test-apk`)
- [ ] Branch must be up to date before merging
- [ ] Force pushes blocked
- [ ] Deletion of `main` blocked
- [ ] Linear history required
- [ ] Squash merge allowed
- [ ] Administrators included
- [ ] `Android release` is not a required check

## What this leaves alone

Secrets stay in GitHub Actions secrets. The application id stays `com.example.vib_abdo_company_mobile` until Ali chooses the store id. Applying this page is a GitHub settings change done by a person, outside this pull request.
