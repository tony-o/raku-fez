unit package Fez::CLI;

use Fez::Util::Pass;
use Fez::Util::Json;
use Fez::Util::Config;
use Fez::Web;
use Fez::Bundle;
use Zef::Config;

multi MAIN('reset-password') is export {
  my $un = prompt('>>= Username: ') while ($un//'').chars < 3;
  my $response = get(
    '/init-password-reset?auth=' ~ $un.encode.decode("utf8").comb.map({
      $_ ~~ m/^<[a..zA..Z0..9\-_.~]>$/ ?? $_ !! sprintf('%%%X', .ord)
    }).join,
  );
  if ! $response<success>.so {
    say '=<< There was an error communicating with the service, please';
    say '    try again in a few minutes.';
    exit 255;
  }
  say '>>= A reset key was successfully requested, please check your email';
  my $key  = prompt('>>= What is the key in your email? ') while ($key//'') eq '';
  my $pass = getpass('>>= New Password: ') while ($pass//'').chars < 8;
  $response = post('/password-reset', data => {
    auth     => $un,
    key      => $key,
    password => $pass,
  });
  if ! $response<success>.so {
    say "=<< password reset failed: {$response<message>}";
    exit 255;
  }
  write-to-user-config({
    key => $response<key>,
    un  => $un,
  });
  say ">>= password reset successful, you now have a new key and can upload dists";
}

multi MAIN('monkey-zef') is export {
  my $conf-path = %*ENV<ZEF_CONFIG_PATH> // Zef::Config::guess-path();
  say '>>= i plan to patch: ' ~ $conf-path;
  if ! $conf-path.IO.w {
    say '=<< config unwritable! quitting..';
    exit 255;
  }
  my $j = from-j($conf-path.IO.slurp);
  my $k = so $j<Repository>.grep: { $_<short-name> eq 'zef-p6c' };
  my $c = 0;
  if $k {
    say '>>= Skipping zef-p6c ecosystem, already installed.';
  } else {
    say '>>= zef-p6c: A mirror of the p6c ecosystem.';
    my $ok = prompt('>>= Add zef-p6c ecosystem? (y/n) ') while ($ok//'') !~~ m{^(y|yes|n|no)$};
    if $ok ~~ m{^y|yes$} {
      $j<Repository>.push: {
        short-name => 'zef-p6c',
        enabled    => 1,
        module     => 'Zef::Repository::Ecosystems',
        options    => {
          name        => 'zef-p6c',
          auto-update => 1,
          mirrors     => ['http://32.zef.pm/'],
        },
      };
      $c++;
    }
  }
  $k = so $j<Repository>.grep: { $_<short-name> eq 'zef' };
  if $k {
    say '>>= Skipping zef ecosystem, already installed.';
  } else {
    say '>>= zef: This is where modules are uploaded by module authors using fez.';
    my $ok = prompt('>>= Add zef ecosystem? (y/n) ') while ($ok//'') !~~ m{^(y|yes|n|no)$};
    if $ok ~~ m{^y|yes$} {
      $j<Repository>.push: {
        short-name => 'zef',
        enabled    => 1,
        module     => 'Zef::Repository::Ecosystems',
        options    => {
          name        => 'zef',
          auto-update => 1,
          mirrors     => ['http://360.zef.pm/'],
        },
      };
      $c++;
    }
  }
  if $c {
    $conf-path.IO.spurt(to-j($j));
    say '>>= changes saved to zef config';
  } else {
    say '>>= no changes made';
  }
}

multi MAIN('register') is export {
  my ($em, $un, $pw);
  $em = prompt('>>= Email: ') while ($em//'').chars < 6;
  $un = prompt('>>= Username: ') while ($un//'').chars < 3;
  $pw = getpass('>>= Password: ') while ($pw//'').chars < 8;

  my $response = post(
    '/register',
    data => { username => $un, email => $em, password => $pw },
  );

  if ! $response<success>.so {
    say "=<< registration failed: {$response<message>}";
    exit 255;
  }
  say ">>= registration successful, requesting auth key";
  my $*USERNAME = $un;
  my $*PASSWORD = $pw;
  MAIN('login');
}

multi MAIN('login') is export {
  my $un = $*USERNAME // '';
  my $pw = $*PASSWORD // '';
  $un = prompt('>>= Username: ') while ($un//'').chars < 3;
  $pw = getpass('>>= Password: ') while ($pw//'').chars < 8;

  my $response = post(
    '/login',
    data => { username => $un, password => $pw, }
  );
  if ! $response<success>.so {
    say "=<< failed to login: {$response<message>}";
    exit 255;
  }

  write-to-user-config({
    key => $response<key>,
    un  => $un,
  });
  say ">>= login successful, you can now upload dists";
}

multi MAIN('checkbuild', Bool :$auth-mismatch-error = False) is export {
  my $meta = try { from-j('./META6.json'.IO.slurp) } or do {
    say 'Unable to find META6.json';
    exit 255;
  };
  my $error = sub ($e) { say "=<< $e"; exit 255; };

  my $ver = $meta<ver>//$meta<vers>//$meta<version>//'';
  $error('name should be a value') unless $meta<name>;
  $error('ver should not be nil')  if     $ver eq '';
  $error('auth should not be nil') unless $meta<auth>;
  $error('auth should start with "zef:"') unless $meta<auth>.substr(0,4) eq 'zef:';
  $error('ver cannot be "*"') if $ver.trim eq '*';

  #TODO: check for provides and resources matches in `lib` and `resources`

  if $meta<auth>.substr(4) ne (config-value('un')//'<unset>') {
    printf "=<< \"%s\" does not match the username you last logged in with (%s),\n=<< you will need to login before uploading your dist\n\n",
           $meta<auth>.substr(4),
           (config-value('un')//'unset');
    exit 255 if $auth-mismatch-error;
  }

  my $auth = $meta<name>
           ~ ':ver<'  ~ $ver ~ '>'
           ~ ':auth<' ~ $meta<auth>.subst(/\</, '\\<').subst(/\>/, '\\>') ~ '>';
  
  printf ">>= %s looks OK\n", $auth;
}

multi MAIN('meta', Str :$name is copy, Str :$website is copy, Str :$email is copy) is export {
  MAIN('login') unless config-value('key');
  if ! (config-value('key')//0) {
    say '=<< you must login to upload';
    exit 255;
  }
  my %data;
  if ($name//'') eq '' && ($website//'') eq '' && ($email//'') eq '' {
    %data<name>    = prompt('>>= what would you like your display name to show? ').trim;
    %data<website> = prompt('>>= what\'s your website? ').trim;
    %data<email>   = prompt('>>= public email address? ').trim;
  } else {
    %data<name> = $name if ($name//'') ne '';
    %data<website> = $website if ($website//'') ne '';
    %data<email> = $email if ($email//'') ne '';
  }
  for %data.keys {
    %data{$_}:delete if %data{$_} eq '';
  }
  my $response = post(
    '/update-meta',
    headers => {'Authorization' => "Zef {config-value('key')}"},
    :%data,
  );
  if ! $response<success>.so {
    say $response;
    say '=<< there was an error, please try again in a few minutes';
    exit 255;
  }
  say '=<< your meta info has been updated';
}

multi MAIN('upload', Str :$file = '') is export {
  MAIN('login') unless config-value('key');
  if ! (config-value('key')//0) {
    say '=<< you must login to upload';
    exit 255;
  }
  my $fn = $file;
  if '' ne $file && ! $file.IO.f {
    say "Cannot find $file";
    exit 255;
  }
  if '' eq $file {
    MAIN('checkbuild', :auth-mismatch-error);
    try {
      CATCH { default { printf "=<< ERROR: %s\n", .message; exit 255; } }
      $fn = bundle('.'.IO.absolute);
    };
  }
  my $response = get(
    '/upload',
    headers => {'Authorization' => "Zef {config-value('key')}"},
  );
 
  my $upload = post(
     $response<key>,
     :method<PUT>,
     :file($fn.IO.absolute),
  );
  say '>>= Hey! You did it! Your dist will be indexed shortly.';
}

multi MAIN(Bool :h(:$help)?) {
  note qq:to/END/
    Fez - Raku / Perl6 package utility

    USAGE
    
      fez command [args]

    COMMANDS

      register              registers you up for a new account
      login                 logs you in and saves your key info
      upload                creates a distribution tarball and uploads
      meta                  update your public meta info (website, email, name)
      reset-password        initiates a password reset using the email
                            that you registered with
      monkey-zef            modifies your zef configuration for fez repos

    ENV OPTIONS

      FEZ_CONFIG            if you need to modify your config, set this env var

    CONFIGURATION (using: { user-config-path })

      Copy this to a cool location and write your own requestors/bundlers or
      ignore it and use the default curl/wget/git tools for great success.

  END
}
