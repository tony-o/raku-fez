unit module Fez::API;
#`{md
# Fez::API

This module contains all of the interaction you can perform with the fez|zef ecosystem.  Enjoy

}

use Fez::Util::Uri;
use Fez::Web;
use Fez::Types; #qw<&api-response>;

#`{md
## org-create

You, too, can create orgs

params:

1. api-key: required
1. name: required, the org name to create
1. email: required, the email to use for this account

returns: _api-response_
}
sub org-create(Str:D $api-key, Str:D $org-name, Str:D $org-email --> Fez::Types::api-response) is export {
  Fez::Types::api-response.new: |get('/group?' ~ pct-encode({
      group => $org-name,
      email => $org-email,
    }),
    headers => {:Authorization("Zef {$api-key} ")},
  );
}

#`{md
## org-join

Allows you to accept an org invitation

params:

1. api-key: required
1. name: required, the name of the org you have a pending invite for

returns: _api-response_
}
sub org-join(Str:D $api-key, Str:D $org-name --> Fez::Types::api-response) is export {
  Fez::Types::api-response.new:
    |post('/groups?' ~ pct-encode({:group($org-name)}),
          :method<PUT>,
          :headers({:Authorization("Zef {$api-key}")}));
}


#`{md
## org-leave

Allows you to leave an org.  If you're the last admin of the org then you must first set your role to `member`.  This is to avoid an accidentally orphaned org

1. api-key: required,
1. name: required, the name of the org you'd like to leave

returns: _api-response_
}
sub org-leave(Str:D $api-key, Str:D $org-name --> Fez::Types::api-response) is export {
  Fez::Types::api-response.new:
    |post('/groups?' ~ pct-encode({:group($org-name)}),
          :method<DELETE>,
          :headers({:Authorization("Zef {$api-key}")}));
}

#`{md
## org-pending

Lists your pending org invites

1. api-key: required

returns: _list-org-response_
}
sub org-pending(Str:D $api-key --> Fez::Types::list-org-response) is export {
  Fez::Types::list-org-response.new:
    |get('/groups/invites', :headers({:Authorization("Zef {$api-key}")}));
}

#`{md
## org-list

Lists the orgs you currently belong to

1. api-key: required

returns: _list-org-response_
}
sub org-list(Str:D $api-key --> Fez::Types::list-org-response) is export {
  Fez::Types::list-org-response.new:
    |get('/groups', :headers({:Authorization("Zef {$api-key}")}));
}

#`{md
## org-members

Lists the members of an org.  All members of an org are public

1. api-key: required

returns: _members-org-response_
}
sub org-members(Str:D $api-key, Str:D $org-name --> Fez::Types::members-org-response) is export {
  Fez::Types::members-org-response.new:
    |post('/groups/members',
          :data({:group($org-name)})
          :headers({:Authorization("Zef {$api-key}")}));
}

#`{md
## org-invite

Invites a user to an org.  You must be an admin of that org

1. api-key: required
1. username: required, org to invite user to
1. role: required, `member`|`admin`
1. user: user to invite

returns: _api-response_
}
sub org-invite(Str:D $api-key, Str:D $org-name, Str:D $role, Str:D $user --> Fez::Types::api-response) is export {
  Fez::Types::api-response.new:
    |post('/groups?' ~ pct-encode({ :$role, :$user, :group($org-name) }),
          :headers({:Authorization("Zef {$api-key}")}));
}

#`{md
## org-mod

Changes a user's role.  You must be an admin of the org to do this

1. api-key: required
1. name: required, org to alter user's role
1. role: required, `member`|`admin`
1. user: user to alter

returns: _api-response_
}
sub org-mod(Str:D $api-key, Str:D $org-name, Str:D $role, Str:D $user --> Fez::Types::api-response) is export {
  Fez::Types::api-response.new:
    |post('/groups?' ~ pct-encode({ :$role, :$user, :group($org-name) }),
          :method<PATCH>,
          :headers({:Authorization("Zef {$api-key}")}));
}

#`{md
## init-password-reset

Initializes a password reset

1. username: required, the username you'd like to initiate a password reset for

returns: _api-response_
}
sub init-reset-password(Str:D $username --> Fez::Types::api-response) is export {
  Fez::Types::api-response.new:
    |get('/init-password-reset?auth=' ~ pct-encode($username));
}

#`{md
## password-reset

Resets the password

1. username: required, the username you'd like to initiate a password reset for
1. key: required, the key emailed to user (initiated by calling `init-password-reset`)
1. password: required, the user's new password

returns: _auth-response_
}
sub reset-password(Str:D $username, Str:D $key, Str:D $password --> Fez::Types::auth-response) is export {
  Fez::Types::auth-response.new:
    |post('/password-reset',
          :data({ :auth($username), :$key, :$password }));
}

#`{md
## register

Creates an auth, if not exists.  Orgs and users share an auth namespace.  This does *NOT* log you in, you
must call `login` after this to obtain an api key.

1. email: required, the user's email to send password reset, ecosystem notifications to, etc
1. username: required, the auth to create
1. password: required, the user's password

returns: _api-response_
}
sub register(Str:D $email, Str:D $username, Str:D $password --> Fez::Types::api-response) is export {
  Fez::Types::api-response.new:
    |post('/register',
          :data({ :$username, :$email, :$password }));
}

#`{md
## login

Logs the user in and creates an `api-key` for use with other functions

1. username: required
1. password: required

returns: _auth-response_
}
sub login(Str:D $username, Str:D $password --> Fez::Types::auth-response) is export {
  Fez::Types::auth-response.new:
    |post('/login',
          :data({ :$username, :$password }));
}

#`{md
## update-meta

Updates the user's meta

1. api-key: required
1. display name: optional, if an empty string is given then no update will be made
1. website: optional, if an empty string is given then no update will be made
1. display email: optional, if an empty string is given then no update will be made

returns: _api-response_
}
sub update-meta(Str:D $api-key, Str $name, Str $website, Str $email --> Fez::Types::api-response) is export {
  my $payload = {};
  $payload<name>    = $name    if $name    ne '';
  $payload<website> = $website if $website ne '';
  $payload<email>   = $email   if $email   ne '';
  Fez::Types::api-response.new:
    |post('/update-meta',
          :data($payload),
          :headers({:Authorization("Zef {$api-key}")}));
}

#`{md
## update-org-meta

Updates the org's meta

1. api-key: required
1. org: required, the org name to change meta data for
1. display name: optional, if an empty string is given then no update will be made
1. website: optional, if an empty string is given then no update will be made
1. display email: optional, if an empty string is given then no update will be made

returns: _api-response_
}
sub update-org-meta(Str:D $api-key, Str:D $org, Str $name, Str $website, Str $email --> Fez::Types::api-response) is export {
  Fez::Types::api-response.new:
    |post('/groups/meta',
          :data({ :$org,
                  ($name ne ''   ?? :$name    !! %()),
                  ($website ne ''?? :$website !! %()),
                  ($email ne ''  ?? :$email   !! %())}),
          :headers({:Authorization("Zef {$api-key}")}));
}

#`{md
## upload

Uploads a dist to the fez|zef ecosystem

1. api-key: required
1. file: required, path to a file to upload

returns: _api-response_
}
sub upload(Str:D $api-key, IO() $file where *.f --> Fez::Types::api-response) is export {
  DEPRECATED 'Fez::API::direct-upload';
  my Fez::Types::auth-response $response.=new:
    |get('/upload',
         :headers({:Authorization("Zef {$api-key}")}));

  if ! $response.success {
    return Fez::Types::api-response.new(:!success, :message($response.message));
  }

  Fez::Types::api-response.new:
    :success(try { post($response.key, :method<PUT>, :file($file.absolute))//'' } eq '' ?? True !! False);
}

#`{md
## direct-upload

Uploads a dist to the fez|zef ecosystem

1. api-key: required
1. file: required, path to a file to upload

returns: _api-response_
}
sub direct-upload(Str:D $api-key, IO() $file where *.f --> Fez::Types::api-response) is export {
  Fez::Types::api-response.new:
    |post('/upload',
          :headers({:Authorization("Zef {$api-key}")}),
          :file($file.absolute)
    );
}

#`{md
## remove

USE SPARINGLY.  Removes a dist from the ecosystem. This will fail if the dist has been uploaded more than 24 hours before
this command is dispatched.  The intent of this method is to give some room for module authors to remit sensitive data.

1. api-key: required
1. dist: required, the full dist string you'd see in the `fez list` output

returns: _api-response_
}
sub remove(Str:D $api-key, Str:D $dist --> Fez::Types::api-response) is export {
  try {
  Fez::Types::api-response.new:
    |post('/remove',
          :data({:$dist}),
          :headers({:Authorization("Zef {$api-key}")}));
  } // Fez::Types::api-response.new(:!success);
}
