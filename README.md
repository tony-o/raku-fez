# zef ecosystem - cli

## fez

fez is the command line tool used to manage your ecosystem user/pass.

### current functionality:

* login
* register
* upload
* monkey-zef

### todo:

* plugin management
* command extensions via plugins

### building

```
zef install fez
```

Notes: fez needs to be *built*, this is to conceal your password whenever you type it in.  PR welcome for making this work with windows.

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

### monkey-zef

You do NOT need to be logged in for this command. Use this command to make to update your existing zef configuration to use fez and zef mirrors.

* fez mirror: this is an automated p6c mirror with the `*` versions of anything stripped out (as `*` supercedes _everything_, this is to avoid a headache)
* zef mirror: this is where you upload/download from when you and other module authors use the `upload` method below.

