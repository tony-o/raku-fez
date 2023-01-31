unit module Fez::Types;

#`{md
# Fez::Types

This module contains all of the api responses that you might get from fez


## api-response

- .success: returns Bool:D
- .message: returns Str:D, this will typically contain an error message

`}
class api-response {
  has Bool $!success;
  has Str $!message;
  submethod BUILD(:$!success = False, :$!message = Nil) {}

  method success {$!success//False};
  method message {$!message//(self.success??''!!'unknown error')};
}

#`{md
## list-org-response

Inherits api-response's functionality

- groups: returns a `List` of orgs
}
class list-org-response is api-response {
  has @!groups;
  submethod BUILD(:@!groups, *@_, *%_) {nextsame}

  method groups(--> List) { @!groups//[] }
}

#`{md
## members-org-response

Inherits api-response's functionality

- .members: returns a `List` of org members
}
class members-org-response is api-response {
  has @!members;
  submethod BUILD(:@!members, *@_, *%_) {nextsame}

  method members(--> List) { @!members//[] }
}

#`{md
## auth-response

Inherits api-response's functionality

- .auth-response: returns a successful auth response's key, otherwise an empty string
}
class auth-response is api-response {
  has $!key;
  submethod BUILD(:$!key, *@_, *%_) {nextsame}

  method key(--> Str) { $!key//'' }
}
