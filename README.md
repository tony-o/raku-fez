# zef ecosystem - cli

## fez

fez is the command line tool used to manage your ecosystem user/pass.

### current functionality:

[![Build Status](http://161.35.142.50/badge/fez-test)](http://161.35.142.50/project/fez-test)

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
