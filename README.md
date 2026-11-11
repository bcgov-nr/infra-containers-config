# infra-containers-config
This repo is like the `infra-apache-config` [Bitbucket] repo, but only for container management (deployment, maintenance)...  

Both leverage Ansible to connect and supply necessary operations to manage respective applications:
* The `infra-apache-config` has used vagrant/CentOS/Ansible
* `infra-containers-config` replaces vagrant and such with [Windows Subsystem for Linux (WSL)](https://docs.microsoft.com/en-us/windows/wsl/about).  There's a script for WSL/Ubuntu setup, in files/scripts.

- infra-containers-config
  - [Containers](#containers)
  - [Authenication](#authentication)
  - [Logs, Log Rotation](#logs)
  - Examples
    - [Example: Ansible Ping](#ping)
    - [Example: Run the playbook](#playbook)

### Containers
---
At the time of writing, this repo only supports the tinyproxy container.  Able to be used in production, also serving as a template for other containers such as Fluent-bit, tomcat, activemq, etc.

### Bitnami Jenkins image builds

The manually triggered **Build Bitnami Jenkins Image** workflow compares the newest
upstream Debian 12 release with the `org.opencontainers.image.version` label on
`ghcr.io/bcgov-nr/infra-containers-config/jenkins:latest` before building. Both
`build-only` and `publish` modes use read-only GHCR access for this comparison.
The job summary reports whether an update is available, the image is already
current, GHCR is newer, or no `latest` image exists. Jenkins version components
and the Bitnami revision are compared numerically (for example, `r10` is newer
than `r2`). Registry errors and missing or invalid version labels fail the check.
For an image index, the comparison reads the Linux AMD64 image's label, matching
the workflow's build platform.

The comparison always uses the newest upstream release, even when `jenkins_tag`
selects an older release. It is informational and does not change the existing
build/publish decisions or update deployments. The default `build-only` mode
does not log in to Docker or publish images.

Run the comparison's mocked-registry tests with
`python3 -m unittest discover -s tests -p 'test_jenkins_release_comparison.py'`.

### Authentication
---
The authentication currently works [using Ansible Vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html) to encrypt user creditials, to decrypt them when the playbooks.  

I had hoped to convert this to leverage the [Hashicorp Vault product](https://www.vaultproject.io/), but have run out of time to fully implement.  What's in the wsl_Ubuntu_setup.sh should be enough to create/get a Vault token, the remaining work would be to replace the Ansible Vault references with the appropriate Hashicorp Vault reference.

### Logs
---
I ran out of time to setup the logrotated conf file for tinyproxy.  The idea was that the mount point "logs" for any container on the host would contain the "hot" logs, and the logrotated would be responsible for creating the "cold" folder & moving logs older than 7 days there before deleting after the desired/specified amount of time.  To be clear, the host logrotated would be responsible for log rotation, not the container.

### Ping
---
Ansible Ping is not the network ping command, and the format to run the command is different.  This example references the Ansible Vault encrypted file to ping the host "freight".

```
ansible -m ping freight -e~/.vault/vault.yml
```
While using WSL/Ubuntu, I learnt that the DNS settings weren't coming to the Ubuntu.  So I had to recreate the `/etc/resolv.conf`, with the following based on `ipconfig /all` on Windows:

```
nameserver 142.32.208.196
nameserver 142.22.202.100
```
But Ubuntu will still overwrite that file, unless you shutdown the WSL from a Windows cmd window: `wsl.exe --shutdown`, and then start the WSL Ubuntu up again. Don't look at me, I didn't write it.

### Playbook
---
Prerequisite: make sure Ansible ping (not network ping) is successful.

To run the playbook:
```
ansible-playbook playbooks/forward-proxy/srv-nrcpod01-tiny.yml
```
