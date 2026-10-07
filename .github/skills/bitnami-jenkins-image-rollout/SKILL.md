---
name: bitnami-jenkins-image-rollout
description: 'Use when running or updating the manually triggered Bitnami Jenkins image build workflow in infra-containers-config.'
argument-hint: 'Optional Bitnami Jenkins image tag; leave blank to build the latest release'
---

# Bitnami Jenkins Image Tag Update

Use this skill to build a Bitnami Jenkins image through the `Build Bitnami Jenkins Image` GitHub Actions workflow in `infra-containers-config`. The default build-only mode does not log in to GHCR or publish an image. Publishing is a separate explicit mode. The workflow does not update consuming repositories, open PRs, or deploy.

## Finding the release tag

Tags come from release commits in [bitnami/containers](https://github.com/bitnami/containers). The workflow can discover the newest Jenkins Debian 12 release automatically. To build a specific older release, use a tag from the [Jenkins Debian 12 commit history](https://github.com/bitnami/containers/commits/main/bitnami/jenkins/2/debian-12), such as `2.580.1-debian-12-r2`. Use the exact tag, including its `-debian-12-rN` suffix.

To check a specific tag from the command line:

```bash
curl -fsSL 'https://api.github.com/search/commits?q=repo%3Abitnami%2Fcontainers+%22Release+<tag>%22' | jq '.items[].commit.message'
```

## Procedure

1. Open the `Build Bitnami Jenkins Image` workflow in GitHub Actions and choose **Run workflow**.
2. Choose `build-only` to resolve the release and build without GHCR credentials or publishing. This is the default and is appropriate for testing workflow changes.
3. Choose `publish` only when ready to publish to GHCR. This mode checks that the versioned tag does not already exist before building and publishing; an existing versioned tag is not overwritten.
4. Leave `jenkins_tag` blank to select the newest official Bitnami Jenkins Debian 12 release, or enter an exact release tag. An explicitly selected older release does not move the `latest` alias. The newest release may update `latest` to its versioned image.
5. Confirm the workflow summary reports the resolved image tag and Bitnami source commit. Build-only success confirms the image builds, but does not test registry login, push permissions, or publishing.
6. Update and deploy the consuming repository separately. The Bitnami image tag remains distinct from the custom `jenkins-*` deployment-state tag, which is created only after production deployment.
