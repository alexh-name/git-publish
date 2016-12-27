# git-publish
Publish your project via Webhooks.

HC SVNT DRACONES  
Apparently you are not encouraged to use shell as CGI scripts.  
Use at own risk.  

Meant as CGI script to pull a repository/branch(, build) and publish stuff.  
Listening for a POST including information:
* User-Agent (to identify service)
* Signature of POST for identification of legitimacy
* Full name of repository (USER/REPOSITORY)
* Branch to use

VAR_DIR/list.txt holds a list of information for every project:  
```
FULL_NAME BRANCH BUILD_FUNCTION URL SECRET_TOKEN
```
with one project per line and each value separated by whitespace.

Optionally using a timer to cap execution per time.  
Put files specific to your service into your VAR_DIR to provide suitable
functions 'read_post', 'build' and 'get_sig'. Examples in var/.

Error codes:
* 70: POST empty.
* 72: There's already an update in queue.
* 73: Service identified by User-Agent not known
     (hence no function to handle POST).
* 79: Signature of POST didn't match.

External binaries are called by absolute path to prevent attacks by tampering
with PATH [1]. Those are:

* /usr/bin/whoami
* /usr/bin/git
* /bin/date
* /bin/awk
* /bin/grep
* /bin/cut
* /usr/bin/openssl
* (/usr/bin/python for read_post_github or POSTs including JSON in general)

Check whether those are correct for your setup.

[[1] w3.org](https://www.w3.org/Security/faq/wwwsf4.html)
