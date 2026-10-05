---
name: bitnami-jenkins-image-rollout
description: 'Update the Bitnami Jenkins image tag in infra-containers-config. Use when changing the jenkins_tag input default in the Jenkins image build workflow.'
argument-hint: 'Bitnami Jenkins image tag, for example 2.580.1-debian-12-r2'
---

# Bitnami Jenkins Image Tag Update

Use this skill to set the Bitnami Jenkins image tag in `infra-containers-config`. It only edits the workflow input; it does not dispatch a build or edit consuming repositories.

## Procedure

1. Check `git status` and preserve unrelated changes.
2. Confirm the requested release exists in `bitnami/containers` and that its release commit message contains the tag. The build workflow finds the source commit by searching commit messages for the tag.
3. In `.github/workflows/build-bitnami-jenkins-image.yml`, set the `jenkins_tag` input `default` under `on.workflow_dispatch.inputs` to the requested tag. Change nothing else.
4. Parse the YAML, confirm the default equals the requested tag, and run `git diff --check`.
5. Report the updated value. State that no build was dispatched.
