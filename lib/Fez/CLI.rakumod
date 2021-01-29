unit package Fez::CLI;

use Fez::Util::Pass;
use Fez::Util::Json;
use Fez::Util::Config;
use Fez::Web;
use Fez::Bundle;

multi MAIN(Bool :v(:$version) where .so) {
  say '>>= fez version: ' ~ $?DISTRIBUTION.meta<ver version>.first(*.so);
}

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
    say "=<< Password reset failed: {$response<message>}";
    exit 255;
  }
  write-to-user-config({
    key => $response<key>,
    un  => $un,
  });
  say ">>= Password reset successful, you now have a new key and can upload dists";
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
    say "=<< Registration failed: {$response<message>}";
    exit 255;
  }
  say ">>= Registration successful, requesting auth key";
  my $*USERNAME = $un;
  my $*PASSWORD = $pw;
  MAIN('login');
  MAIN('meta');
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
  say ">>= Login successful, you can now upload dists";
}

multi MAIN('checkbuild', Str :$file = '', Bool :$auth-mismatch-error = False) is export {
  my $skip-meta;
  require ::('Fez::Util::Tar');
  my $meta = try {
    if $file eq '' {
      say '>>= Inspecting ./META6.json';
      from-j('./META6.json'.IO.slurp);
    } else {
      printf ">>= Looking in \"%s\" for META6.json\n", $file.IO.resolve.relative;
      if ::('Fez::Util::Tar').able {
        my $proc = run 'tar', 'xOf', $file, 'META6.json', :out, :err;
        die if $proc.exitcode != 0;
        from-j($proc.out.slurp);
      } else {
        $skip-meta = True;
        False;
      }
    }
  } or do {
    if $skip-meta {
      say '=<< Unable to verify meta, no tar found.';
    } else {
      say '=<< Unable to find META6.json';
      exit 255;
    }
  };
  return if $skip-meta;
  my $error = sub ($e, Bool :$exit = True) {
    say "=<< $e";
    if $exit {
      say '=<< If you\'re using git, make sure to commit your changes.' if '.git'.IO ~~ :d;
      printf "=<< To inspect the file, check: %s\n", $file.IO.resolve.relative if $file;
      exit 255;
    }
  }

  my $ver = $meta<ver>//$meta<vers>//$meta<version>//'';
  $error('name should be a value') unless $meta<name>;
  $error('ver should not be nil')  if     $ver eq '';
  $error('auth should not be nil') unless $meta<auth>;
  $error('auth should start with "zef:"') unless $meta<auth>.substr(0,4) eq 'zef:';
  $error('ver cannot be "*"') if $ver.trim eq '*';

  my $errors;
  my @files    = $file ?? ::('Fez::Util::Tar').ls($file) !! do {
    my @xs;
    @xs.push('lib'.IO) if 'lib'.IO.d;
    @xs.push('resources'.IO) if 'resources'.IO.d;
    my @l;
    while @xs {
      for @xs.pop.dir -> $f {
        @l.push: $f;
        @xs.push($f) if $f.d;
      }
    }
    |@l;
  };
  if @files[0] ~~ Failure {
    $error('Unable to list tar files', :!exit);
  } else {
    my @provides = $meta<provides>.values;
    my @resources = $meta<resources>;
    my %check;
    for @files.grep({$_ ~~ m/^'/'**0..1'lib'/ && $_ ~~ m/'.'('pm6'|'rakumod')$/}) -> $f {
      %check{$f}++;
    }
    for @provides -> $f {
      %check{$f}--;
    }
    for %check.keys -> $f {
      %check{$f}:delete if %check{$f} == 0;
      next unless %check{$f};
      $error(
        sprintf(
          "File \"%s\" in %s not found in %s",
          $f,
          %check{$f} == -1 ?? 'meta<provides>' !! ($file??'tar'!!'dir'),
          %check{$f} ==  1 ?? 'meta<provides>' !! ($file??'tar'!!'dir'),
        ),
        :!exit
      );
    }
    say '>>= meta<provides> looks OK' unless %check.keys;
    $errors++ if %check.keys;

    %check = ();
    for @files.grep({$_ ~~ m/^'/'**0..1'resources'/ && $_ !~~ m/'/'$/}) -> $f {
      %check{S/^'/'// with $f}++;
    }
    for @resources -> $f {
      %check{"resources/{$f}"}--;
    }
    for %check.keys -> $f {
      %check{$f}:delete if %check{$f} == 0;
      next unless %check{$f};
      $error(
        sprintf(
          "File \"%s\" in %s not found in %s",
          $f,
          %check{$f} == -1 ?? 'meta<resources>' !! ($file??'tar'!!'dir'),
          %check{$f} ==  1 ?? 'meta<resources>' !! ($file??'tar'!!'dir'),
        ),
        :!exit
      );
    }
    say '>>= meta<resources> looks OK' unless %check.keys;
    $errors++ if %check.keys;
  }

  if $meta<auth>.substr(4) ne (config-value('un')//'<unset>') {
    printf "=<< \"%s\" does not match the username you last logged in with (%s),\n=<< you will need to login before uploading your dist\n\n",
           $meta<auth>.substr(4),
           (config-value('un')//'unset');
    exit 255 if $auth-mismatch-error;
  }

  my $auth = $meta<name>
           ~ ':ver<'  ~ $ver ~ '>'
           ~ ':auth<' ~ $meta<auth>.subst(/\</, '\\<').subst(/\>/, '\\>') ~ '>';

  if $auth-mismatch-error {
    my $uri = $meta<name>.comb[0].uc         ~ '/' ~
              $meta<name>.comb[1..2].join.uc ~ '/' ~
              $meta<name>.uc ~ '/index.json';
    my @m;
    try {
      CATCH { default {
        printf "=<< Error retrieving \"%s\", unable to verify if version exists.\n", $uri;
      } }
      @m = get("http://360.zef.pm/$uri");
    };
    for @m.grep(*.so) -> $rmeta {
      if $meta<auth> eq $rmeta<auth>
      && $ver eq ($rmeta<ver>//$rmeta<vers>//$rmeta<version>) {
        printf "=<< %s version(%s) appears to exist\n", $meta<name>, $ver;
        exit 255;
      }
    }
  }

  printf ">>= %s looks OK\n", $auth unless $errors;
  printf ">>= %s could use some sprucing up\n", $auth if $errors;
  return False if $errors;
  True;
}

multi MAIN('meta', Str :$name is copy, Str :$website is copy, Str :$email is copy) is export {
  MAIN('login') unless config-value('key');
  if ! (config-value('key')//0) {
    say '=<< You must login to change your info';
    exit 255;
  }
  my %data;
  if ($name//'') eq '' && ($website//'') eq '' && ($email//'') eq '' {
    %data<name>    = prompt('>>= What would you like your display name to show? ').trim;
    %data<website> = prompt('>>= What\'s your website? ').trim;
    %data<email>   = prompt('>>= Public email address? ').trim;
  } else {
    %data<name> = $name if ($name//'') ne '';
    %data<website> = $website if ($website//'') ne '';
    %data<email> = $email if ($email//'') ne '';
  }
  for %data.keys {
    %data{$_}:delete if %data{$_} eq '';
  }
  unless +%data.keys {
    say '>>= Nothing to update';
    exit 0;
  }
  my $response = try post(
    '/update-meta',
    headers => {'Authorization' => "Zef {config-value('key')}"},
    :%data,
  );
  if ! ($response<success>//False).so {
    say '=<< There was an error, please try again in a few minutes';
    exit 255;
  }
  say '=<< Your meta info has been updated';
}

multi MAIN('upload', Str :$file = '') is export {
  MAIN('login') unless config-value('key');
  if ! (config-value('key')//0) {
    say '=<< You must login to upload';
    exit 255;
  }
  my $fn = $file;
  if '' ne $file && ! $file.IO.f {
    say "=<< Cannot find $file";
    exit 255;
  }
  try {
    CATCH { default { printf "=<< ERROR: %s\n", .message; exit 255; } }
    $fn = bundle('.'.IO.absolute);
  };
  if !so MAIN('checkbuild', :file($fn.IO.absolute), :auth-mismatch-error) {
    my $resp = prompt('>>= Upload anyway (y/N)? ') while ($resp//' ') !~~ any('y'|'yes'|'n'|'no'|'');
    if $resp ~~ any('n'|'no'|'') {
      say '=<< Ok, exiting';
      exit 255;
    }
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
