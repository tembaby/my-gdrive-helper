# Brief

# Install

> $ gem install google-api-client
> $ gem install launchy

# Usage

* Find (all) directories with the name <DIRECTORY-NAME>, and print all information about directory:
> $ ./my-gdrive-helper.rb --find-directory <DIRECTORY-NAME> --long --verbose

* Same as above but limit scope to specific tree
> $ ./my-gdrive-helper.rb --find-directory <DIRECTORY-NAME> --root <DIRECTORY-ID> --long --verbose

* Iterate all folder and file starting from <DIRECTORY-ID>, just print rich information:
> $ ./my-gdrive-helper.rb --traverse <DIRECTORY-ID> --long --verbose

* Revoke all sharings for all users under directory <DIRECTORY-ID>, except for (File/folder owned by user other than the current logged in user, File/folder shared for current logged in user):
> $ ./my-gdrive-helper.rb --traverse <DIRECTORY-ID> --long --verbose --revoke-sharing

* Same as last one but revoke sharing for specific user:
> $ ./my-gdrive-helper.rb --traverse <DIRECTORY-ID> --long --verbose --revoke-sharing --email person@domain.com

* Just print shared files for email (User):
> $ ./my-gdrive-helper.rb --find-user-shares --email person@domain.com

* Same as above but print and revoke permissions on files/folders:
> $ ./my-gdrive-helper.rb --find-user-shares --email person@domain.com --long --verbose --revoke-sharing

