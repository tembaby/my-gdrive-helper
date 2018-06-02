# Brief

A Ruby script to manipulate Google Drive permission in a mass operation.

Ever find your Google drive in a complete mess with sharing permissions? This script will help tidy up sharing by helping out finding all shared files, finding files shared for specific user(s), traverse specific path, and allow you to revoke some or all permissions on those file and folders.

# Install

* Install necessary gems:
> $ gem install google-api-client<br>
> $ gem install launchy

* Create Applicaiton/project from google developer console

* From developer console get client_secrets.json file and place it in the directory where the Ruby script resides

* XXX This procedure cloud change I guess.

# Usage

* Find (all) directories with the name *DIRECTORY-NAME*, and print all information about directory:
> $ ./my-gdrive-helper.rb --find-directory *DIRECTORY-NAME* --long --verbose

* Same as above but limit scope to specific tree
> $ ./my-gdrive-helper.rb --find-directory *DIRECTORY-NAME* --root *DIRECTORY-ID* --long --verbose

* Iterate all folders and files starting from *DIRECTORY-ID*, just print rich information:
> $ ./my-gdrive-helper.rb --traverse *DIRECTORY-ID* --long --verbose

* Revoke all sharings for all users under directory *DIRECTORY-ID*, except for (File/folder owned by user other than the current logged in user, File/folder shared for current logged in user):
> $ ./my-gdrive-helper.rb --traverse *DIRECTORY-ID* --long --verbose --revoke-sharing

* Same as last one but revoke sharing for specific user(s):
> $ ./my-gdrive-helper.rb --traverse *DIRECTORY-ID* --long --verbose --revoke-sharing --email person@domain.com

* Just print shared files for email (User(s)):
> $ ./my-gdrive-helper.rb --find-user-shares --email person@domain.com

* Same as above but print and revoke permissions on files/folders:
> $ ./my-gdrive-helper.rb --find-user-shares --email person@domain.com --long --verbose --revoke-sharing

