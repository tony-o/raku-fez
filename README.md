# zef ecosystem - cli

## fez

fez is the command line tool used to manage your ecosystem user/pass.

- [current functionality](#current-functionality)
- [module management](#module-management)
- [plugins](#plugins)
- [faq](#faq)
- [articles-about-fez](#articles-about-fez)
- [license](#license)
- [authors](#authors)

### current functionality:

* login
* register
* upload
* reset-password
* meta
* plugin management
* command extensions via plugins

if you have features or edge cases that would make your migration to fez easier, please open a bug here in github or message me in #raku on freenode (tonyo).

### register

```
λ local:~$ fez register
>>= Email: xyz@abc.com
>>= Username: tony-o
>>= Password:
>>= registration successful, requesting auth key
>>= login successful, you can now upload dists
>>= what would you like your display name to show? tony o
>>= what's your website? DEATHBYPERL6.com
>>= public email address? xxxx
=<< your meta info has been updated
```

### login

This is not necessary if you've just registered but you will eventually have to request a new key.

```
λ local:~$ fez login
>>= Username: tony-o
>>= Password:
>>= login successful, you can now upload dists
```

### meta

Update your meta info - this information is public.

```
λ local:~$ fez meta
>>= what would you like your display name to show? tony o
>>= what's your website? DEATHBYPERL6.com
>>= public email address? xxxx
=<< your meta info has been updated
```

### upload

If you're not logged in for this bit then it will prompt you to do so.

```
λ local:~/projects/perl6-slang-sql-master$ fez upload
>>= Slang::SQL:ver<0.1.2>:auth<zef:tony-o> looks OK
>>= Hey! You did it! Your dist will be indexed shortly.
```

or, if there are errors:

```
λ local:~/Downloads/perl6-slang-sql-master$ fez upload
=<< "tonyo" does not match the username you last logged in with (tony-o),
=<< you will need to login before uploading your dist
```

### reset password

If you've forgotten your password, use this little guy.

```
λ local:~$ fez reset-password
>>= Username: tony-o
>>= A reset key was successfully requested, please check your email
>>= New Password:
>>= What is the key in your email? abcdef...
>>= password reset successful, you now have a new key and can upload dists
```

### checkbuild

This is the check fez runs when you run `fez upload`

```
$ fez checkbuild
>>= Inspecting ./META6.json
>>= meta<provides> looks OK
>>= meta<resources> looks OK
>>= fez:ver<11>:auth<zef:tony-o> looks OK
```

-or if you have errors-

```
$ fez checkbuild
>>= Inspecting ./META6.json
>>= meta<provides> looks OK
=<< File "resources/config.json" in dir not found in meta<resources>
>>= fez:ver<11>:auth<zef:tony-o> could use some sprucing up
```

If you're rolling your own tarballs then you can specify the file to checkout with `--file=`, please keep in mind that checkbuild requires access to a tar that can work with compression for _some_ of these checks.

## module management

### listing your modules

`fez list <filter?>`

```
$ fez list csv
>>= CSV::Parser:ver<0.1.2>:auth<zef:tony-o>
>>= Text::CSV::LibCSV:ver<0.0.1>:auth<zef:tony-o>
```

```
$ fez list
>>= Bench:ver<0.2.0>:auth<zef:tony-o>
>>= Bench:ver<0.2.1>:auth<zef:tony-o>
>>= CSV::Parser:ver<0.1.2>:auth<zef:tony-o>
>>= Data::Dump:ver<0.0.12>:auth<zef:tony-o>
...etc
```

### removing a module

This is highly unrecommended but a feature nonetheless.  This requires you use the full dist name as shown in `list` and is only available within 24 hours of upload. If an error occurs while removing the dist, you'll receive an email.

```
$ fez remove 'Data::Dump:ver<0.0.12>:auth<zef:tony-o>'
>>= Request received
```

## plugins

### plugin

`fez plugin` lists the current plugins in your config file(s).

`fez plugin <key> 'remove'|'append'|'prepend' <value>` does the requested action to <key> in your user config.

#### extensions

fez can now load extensions to `MAIN`.  this happens as a catchall at the bottom of fez and uses the first available extensions that it can and exits afterwards. eg if two extensions provide a command `fez test` then the first one that successfully completes (doesn't die or exit) will be run and then fez will exit.

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

#### using git archive

fez will attempt to run `git archive` which will obey your `.gitignore` files. it is a good idea to put sdist/ in your root gitignore to prevent previously uploaded modules.

#### using tar

if there is a `tar` in path then fez will try to bundle everything not in hidden directories/files (anything starting with a `.`) and ignore the `sdist/` directory.

## articles about fez

if you'd like to see your article featured here, please send a pr.

* [faq: zef ecosystem](https://deathbyperl6.com/faq-zef-ecosystem/)
* [fez|zef - a raku ecosystem and auth](https://deathbyperl6.com/fez-zef-a-raku-ecosystem-and-auth/)


## license

[![License: Artistic-2.0](https://img.shields.io/badge/License-Artistic%202.0-0298c3.svg)](https://opensource.org/licenses/Artistic-2.0)

## authors

@[tony-o](https://github.com/tony-o)

@[patrickbr](https://github.com/patrickbkr)

@[JJ](https://github.com/JJ)

@[melezhik](https://github.com/melezhik)
