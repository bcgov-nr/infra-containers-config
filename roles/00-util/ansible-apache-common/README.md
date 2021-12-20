**Apache HTTPD Common/Shared Stuff**

**Description:**

This role is for setting up common/shared things that are used by multiple httpd instances.

Examples include common htpass files, common crontab scripts, etc.

Avoid the temptation to move a bunch of other stuff in here that is already defined in the srv-servername-httpdinstance 
roles. It is valid to think about this, but there may be some small differences between httpd instances that are easier 
to understand and track over time in the context of the server and httpd instance role.