# zef ecosystem - cli

## fez

fez is the command line tool used to manage your ecosystem user/pass.

### current functionality:

* login
* register
* upload

### todo:

* plugin management
* command extensions via plugins

### building

this is not available in the perl6 ecosystem at the moment so you need to build it manually:

```
git clone git@github.com:tony-o/zeco-cli
cd zeco-cli
zef install .
```

Notes: fez should be *built*, this is to conceal your password whenever you type it in.  PR welcome for making this work with windows.

### register

```
λ local:~$ fez register
>>= Email: xyz@abc.com
>>= Username: tony-o
>>= Password:
>>= registration successful, requesting auth key
>>= login successful, you can now upload dists
```

### login

This is not necessary if you've just registered but you will eventually have to request a new key.

```
λ local:~$ fez login
>>= Username: tony-o
>>= Password:
>>= login successful, you can now upload dists
```

### upload

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
