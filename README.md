# infra-containers-config
Like the infra-apache-config [Bitbucket] repo, but only for container management (deployment, maintenance)...

Both leverage Ansible to connect and supply necessary operations to manage respective applications.  The infra-apache-config has used vagrant/CentOS/Ansible - infra-containers-config replaces vagrant and such with Windows Subsystem for Linux (WSL).

Containers will:
- operate as a [systemd service](https://man7.org/linux/man-pages/man1/init.1.html) (to ensure startup at reboot)
- use a [directory] mount to provide access/transparency to log files.  Log file rotation will leverage [logrotated](https://linux.die.net/man/8/logrotate) on the host (not within the container, as containers won't have CRON/etc unless absolutely necessary)
- use a mount for piping the necessary config file(s) into the container
- source their image from a specified location, not local built
