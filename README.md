# git-publish
Publish your project via Webhooks.

HC SVNT DRACONES  
Apparently you are not encouraged to use shell as CGI scripts.  
Use at own risk.

Meant as CGI script to pull a git repository/branch, build and publish stuff.  
Listening for a POST including information:
* User-Agent (to identify service)
* Signature of POST for identification of legitimacy
* Full name of repository (USER/REPOSITORY)
* Branch to use

Optionally using a timer to cap execution per time.  
Put files specific to your service into your VAR_DIR to provide suitable
functions 'read_post' and 'get_sig'. Examples in var/.  

Error codes:
* 70: POST empty.
* 72: There's already an update in queue.
* 73: Service identified by User-Agent not known
     (hence no function to handle POST).
* 79: Signature of POST didn't match.
