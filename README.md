# zef ecosystem - cli

To install:

```
$ zef install fez
```

## fez

fez is the command line tool used to manage your ecosystem user/pass.

- [installation](#installation)
- [current functionality](#current-functionality)
- [faq](#faq)
- [articles-about-fez](#articles-about-fez)
- [license](#license)

### installation

as easy as: `zef install fez`

*** Note: if you are having trouble installing fez and you see an error referring to zlib, then please install zlib and try installing fez again prior to opening a bug.

### current functionality:

Fez - Raku dist manager

#### INFORMATION

| command  | info |
|----------|------|
| v\|version | prints out the version of fez you're using |
| _*DIST MANAGEMENT*_ | 
| init | initializes a new module |
| resource | creates a new resource file at the given path, creating the path if necessary |
| depends | add a build or runtime dependency to the meta |
| cmd | list commands this module provides |
| run | runs a command listed in `cmd` |
| refresh | attempts to update the META6 from the file system this does NOT prompt before overwriting |
| license | view or manage the current repo's license |
| _*RELEASE MANAGEMENT*_ |
| review | goes through the current directory to find any errors that might be lurking upon upload |
| upload | creates a distribution tarball and uploads |
| list | lists the dists for the currently logged in user |
| remove | removes a dist from the ecosystem (requires fully qualified dist name, copy from `list` if in doubt) |
| _*USER MANAGEMENT*_ |
| register | registers you up for a new account |
| login | logs you in and saves your key info |
| meta | update your public meta info (website, email, name) |
| reset-password | initiates a password reset using the email that you registered with |
| _*ORG MANAGEMENT*_ |
| org | org actions, use `fez org help` for more info |
| org accept  | Accept an invitation to a fez organisation |
| org create  | Create a fez organisation |
| org invite  | Invite someone to a fez organisation |
| org leave   | Leave a fez organisation |
| org list    | List ??? (modules?) in a fez organisation |
| org members | List members in a fez organisation |
| org meta    | Update a fez organisation's meta information |
| org modify  | ??? Modify a fez organisation |
| org pending | ??? List pending invitations to a fez organisation |


To see more information about any of these commands just run `fez <cmd>`, example:

```
~$ fez resource
Fez - Raku dist manager

USAGE

  fez res <path>

  fez resource <path>

Attempts to create a resource in the current dist and update the meta. Do NOT
include 'resources/' in the path, eg

fez resource usage/default

Will create the file: `resources/usage/default`.
```

## faq

- [do I need to remove modules from cpan](#do-i-need-to-remove-modules-from-cpan)
- [which version will zef choose if my module is also on cpan](#which-version-will-zef-choose-if-my-module-is-also-on-cpan)
- [what's this sdist directory](#whats-this-sdist-directory)

### do i need to remove modules from cpan?

No.  If you want your fez modules to be prioritized then simply bump the version.  Note that you can upload older versions of your modules using a tar.gz and specifing `fez upload --file <path to tar.gz>`.

### which version will zef choose if my module is also on cpan?

zef will prioritize whichever gives the highest version and then the rest depends on which ecosystem is checked first which can vary system to system.

### what's this sdist directory?

when fez bundles your source it outputs to `sdist/<name>.tar.gz` and then uploads that package to the ecosystem.  there are two ways that fez might try to bundle your package. as of `fez:ver<26+>` fez will attempt to remove the sdist/ directory _if no `--file` is manually specified_

## articles about fez

if you'd like to see your article featured here, please send a pr.

* [faq: zef ecosystem](https://deathbyperl6.com/faq-zef-ecosystem/)
* [fez|zef - a raku ecosystem and auth](https://deathbyperl6.com/fez-zef-a-raku-ecosystem-and-auth/)


## license

[![License: Artistic-2.0](https://img.shields.io/badge/License-Artistic%202.0-0298c3.svg)](https://opensource.org/licenses/Artistic-2.0)
