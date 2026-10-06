---
name: bitnami-jenkins-image-rollout
description: 'Update the Bitnami Jenkins image tag in infra-containers-config. Use when changing the jenkins_tag input default in the Jenkins image build workflow.'
argument-hint: 'Bitnami Jenkins image tag, for example 2.580.1-debian-12-r2'
---

# Bitnami Jenkins Image Tag Update

Use this skill to set the Bitnami Jenkins image tag in `infra-containers-config`. It only edits the workflow input; it does not dispatch a build or edit consuming repositories.

## Finding the release tag

Tags come from release commits in [bitnami/containers](https://github.com/bitnami/containers). Browse the [Jenkins debian-12 commit history](https://github.com/bitnami/containers/commits/main/bitnami/jenkins/2/debian-12) for commits titled `[bitnami/jenkins] Release <tag> (#<PR>)`, for example `[bitnami/jenkins] Release 2.580.1-debian-12-r2 (#98267)`. Use `<tag>` exactly as written; it must keep the `-debian-12-rN` suffix.

To check a specific tag from the command line:

```bash
curl -fsSL 'https://api.github.com/search/commits?q=repo%3Abitnami%2Fcontainers+%22Release+<tag>%22' | jq '.items[].commit.message'
```

## Procedure

1. Check `git status` and preserve unrelated changes.
2. Confirm the requested tag has a release commit as described above. The build workflow finds the source commit by searching commit messages for the tag.
3. In `.github/workflows/build-bitnami-jenkins-image.yml`, set the `jenkins_tag` input `default` under `on.workflow_dispatch.inputs` to the requested tag. Change nothing else.
4. Parse the YAML, confirm the default equals the requested tag, and run `git diff --check`.
5. Report the updated value. State that no build was dispatched.
