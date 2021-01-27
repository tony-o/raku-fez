# zef ecosystem - cli

## fez

fez is the command line tool used to manage your ecosystem user/pass.

### current functionality:

* login
* register
* upload
* reset-password
* meta

### todo:

* plugin management
* command extensions via plugins


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
>>= fez:ver<11>:auth<zef:tony-o> looks OK
```

If you're rolling your own tarballs then you can specify the file to checkout with `--file=`, please keep in mind that checkbuild requires access to a tar that can work with compression for _some_ of these checks.

## license

[![License: Artistic-2.0](https://img.shields.io/badge/License-Artistic%202.0-0298c3.svg)](https://opensource.org/licenses/Artistic-2.0)

## authors

@[tony-o](https://github.com/tony-o)

@[patrickbr](https://github.com/patrickbkr)

@[JJ](https://github.com/JJ)

@[melezhik](https://github.com/melezhik)
