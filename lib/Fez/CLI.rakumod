unit package Fez::CLI;

use Fez::Util::Pass;
use Fez::Util::Json;
use Fez::Util::Config;
use Fez::Util::Date;
use Fez::Util::Uri;
use Fez::Web;
use Fez::Bundle;

multi MAIN(Bool :v(:$version) where .so) {
  say '>>= fez version: ' ~ $?DISTRIBUTION.meta<ver version>.first(*.so);
}

multi MAIN('org', 'create', Str $org-name, Str $org-email) {
  my $response = get('/group?' ~ pct-encode({
                        group => $org-name,
                        email => $org-email,
                      }),
                      headers => {'Authorization' => "Zef {config-value('key')}"});
  if $response<success> {
    say ">>= You're the proud new admin of $org-name";
    $response = get('/groups', headers => {'Authorization' => "Zef {config-value('key')}"});
    if ! $response<success>.so {
      $*ERR.say: "=<< Failed to retrieve user orgs";
      exit 255;
    }
    if $response<success> {
      write-to-user-config({ groups => $response<groups> });
    } else {
      $*ERR.say: "=<< Failed to update config";
      exit 1;
    }
  } else {
    $*ERR.say: "=<< $response<message>";
    exit 255;
  }
}

multi MAIN('org', 'leave', Str $org-name) {
  my $response = post('/groups?' ~ pct-encode({ group => $org-name }),
                      method => 'DELETE',
                      headers => {'Authorization' => "Zef {config-value('key')}"});
  if $response<success> {
    say ">>= You're no longer in $org-name";
    $response = get('/groups', headers => {'Authorization' => "Zef {config-value('key')}"});
    if ! $response<success>.so {
      $*ERR.say: "=<< Failed to retrieve user orgs";
      exit 255;
    }
    if $response<success> {
      write-to-user-config({ groups => $response<groups> });
    } else {
      $*ERR.say: "=<< Failed to update config";
      exit 1;
    }
  } else {
    $*ERR.say: "=<< $response<message>";
    exit 255;
  }
}

multi MAIN('org', 'accept', Str $org-name) {
  my $response = post('/groups?' ~ pct-encode({ group => $org-name }),
                      method => 'PUT',
                      headers => {'Authorization' => "Zef {config-value('key')}"});
  if $response<success> {
    say ">>= You're now a very nice member of $org-name";
    $response = get('/groups', headers => {'Authorization' => "Zef {config-value('key')}"});
    if ! $response<success>.so {
      $*ERR.say: "=<< Failed to retrieve user orgs";
      exit 255;
    }
    if $response<success> {
      write-to-user-config({ groups => $response<groups> });
    } else {
      $*ERR.say: "=<< Failed to update config";
      exit 1;
    }
  } else {
    $*ERR.say: "=<< $response<message>";
    exit 255;
  }
}

multi MAIN('org', 'pending') {
  my $response = get('/groups/invites', headers => {'Authorization' => "Zef {config-value('key')}"});
  if $response<success> {
    say '>>= R Org' if +@($response<groups>);
    for @($response<groups>).sort({ $^a<role> eq $^b<role> ?? $^a<group> cmp $^b<group> !! $^a<role> cmp $^b<role> }) -> %g {
      say ">>= {%g<role>.substr(0,1)} {%g<group>}";
    }
  } else {
    $*ERR.say: "=<< Failed. $response<message>";
    exit 255;
  }
}

multi MAIN('org', 'members', Str $org-name) {
  my $response = post('/groups/members',
                      data => {
                        group => $org-name,
                      },
                      headers => {'Authorization' => "Zef {config-value('key')}"});
  if $response<success> {
    say '>>= R Org Name' if +@($response<members>);
    for @($response<members>).sort({ $^a<role> eq $^b<role> ?? $^a<username> cmp $^b<username> !! $^a<role> cmp $^b<role> }) -> %m {
      say ">>= {%m<role>.substr(0,1)} {%m<username>}"
    }
  } else {
    $*ERR.say: "=<< Failed. $response<message>";
    exit 255;
  }
}

multi MAIN('org', 'invite', Str $org-name, Str $role, Str $user) {
  my $response = post('/groups?' ~ pct-encode({ :$role, group => $org-name, :$user }),
                     headers => {Authorization => "Zef {config-value('key')}"});
  if $response<success> {
    say '>>= Invitation sent';
  } else {
    $*ERR.say: '=<< Failed: ' ~ $response<message>;
    exit 255;
  }
}

multi MAIN('reset-password') is export {
  my $un = prompt('>>= Username: ') while ($un//'').chars < 3;
  my $response = get('/init-password-reset?auth=' ~ pct-encode($un));
  if ! $response<success>.so {
    $*ERR.say: '=<< There was an error communicating with the service, please';
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
    $*ERR.say: "=<< Password reset failed: {$response<message>}";
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
  $em = prompt('>>= Email: ');
  $em = prompt('>>= Email: ') while ($em//'').chars < 6
                                 && 1 == $*ERR.say('=<< Please enter a valid email');
  $un = prompt('>>= Username: ');
  $un = prompt('>>= Username: ') while ($un//'').chars < 3
                                    && 1 == $*ERR.say('=<< Username must be longer than 3 chars');
  $pw = getpass('>>= Password: ');
  $pw = getpass('>>= Password: ')  while ($pw//'').chars < 8
                                      && 1 == $*ERR.say('=<< Password must be longer than 8 chars');

  my $response = post(
    '/register',
    data => { username => $un, email => $em, password => $pw },
  );

  if ! $response<success>.so {
    $*ERR.say: "=<< Registration failed: {$response<message>}";
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
  $un = prompt('>>= Username: ');
  $un = prompt('>>= Username: ') while ($un//'').chars < 3
                                    && 1 == $*ERR.say('=<< Username must be longer than 3 chars');
  $pw = getpass('>>= Password: ');
  $pw = getpass('>>= Password: ')  while ($pw//'').chars < 8
                                      && 1 == $*ERR.say('=<< Password must be longer than 8 chars');

  my $response = post(
    '/login',
    data => { username => $un, password => $pw, }
  );
  if ! $response<success>.so {
    $*ERR.say: "=<< Failed to login: {$response<message>}";
    exit 255;
  }

  my $ukey = $response<key>;
  $response = get('/groups', headers => {'Authorization' => "Zef $ukey"});
  if ! $response<success>.so {
    $*ERR.say: "=<< Failed to retrieve user groups";
    exit 255;
  }

  write-to-user-config({
    key    => $ukey,
    un     => $un,
    groups => $response<groups>,
  });
  say ">>= Login successful, you can now upload dists";
}

multi MAIN('checkbuild', Str :$file = '', Bool :$auth-mismatch-error = False, Bool :$development = False) is export {
  my $skip-meta;
  my $root = '.';
  my $sep = '.'.IO.SPEC.dir-sep;
  my $meta = try {
    if $file eq '' {
      say '>>= Inspecting ./META6.json';
      from-j('./META6.json'.IO.slurp);
    } else {
      printf ">>= Looking in \"%s\" for META6.json\n", $file.IO.resolve.relative;
      my @files = ls($file);
      my @dirs = @files.map({$_.IO.relative.split($sep).first}).unique;
      if @dirs.elems != 1 {
        $*ERR.say: '=<< No single root directory found, all dists must extract to a single directory';
        exit 255;
      }
      $root = @dirs[0];
      my $fn = '';
      for @files -> $f {
        $fn = $f if $f ~~ /^ ('.'|'..')? $sep? $root $sep 'META6.json'$/;
      }
      if (my $data = cat($file, $fn)) {
        from-j($data);
      } else {
        $skip-meta = True;
        False;
      }
    }
  } or do {
    if $skip-meta {
      $*ERR.say: '=<< Unable to verify meta, no tar found.';
    } else {
      $*ERR.say: '=<< Unable to find META6.json';
      exit 255;
    }
  };
  return if $skip-meta;
  my $error = sub ($e, $ec?=255, Bool :$exit = True) {
    $*ERR.say: "=<< $e";
    if $exit {
      $*ERR.say: '=<< If you\'re using git, make sure to commit your changes.' if '.git'.IO ~~ :d;
      printf "=<< To inspect the file, check: %s\n", $file.IO.resolve.relative if $file;
      exit $ec;
    }
  }
  $error('production in META is set to false') if !($meta<production>//True).so
                                               && !$development;

  my $ver = $meta<ver>//$meta<vers>//$meta<version>//'';
  $error('name should be a value', 1) unless $meta<name>;
  $error('ver should not be nil', 2)  if     $ver eq '';
  $error('auth should not be nil', 3) unless $meta<auth>;
  $error('auth should start with "zef:"', 4) unless $meta<auth>.substr(0,4) eq 'zef:';
  $error('ver cannot be "*"', 5) if $ver.trim eq '*';

  my $errors;
  my @files = $file ?? ls($file) !! do {
    my @xs;
    @xs.push('lib'.IO) if 'lib'.IO.d;
    @xs.push('resources'.IO) if 'resources'.IO.d;
    my @l;
    while @xs {
      for @xs.pop.dir -> $f {
        @l.push($f) if ($f.f && $f.basename ~~ /'.'('rakumod'|'pm6')$/)
                    || ($f.relative ~~ /^ 'resources' $sep / && $f.f);
        @xs.push($f) if $f.d;
      }
    }
    |@l;
  };
  if @files[0] ~~ Failure {
    $error('Unable to list tar files', :!exit);
  } else {
    my @provides = |$meta<provides>.values;
    my @resources = |($meta<resources>//[]);
    my %check;
    for @files.grep({(
        ( $file && $_ ~~ m/^('.'|'..')? $sep? $root $sep 'lib'/) 
      ||(!$file && $_ ~~ m/$sep? 'lib'/)
    ) && $_ ~~ m/'.'('pm6'|'rakumod')$/}) -> $f {
      %check{$f}++;
    }
    for @provides.unique -> $f {
      %check{$root.IO.add($f).relative}--;
    }
    for %check.keys.sort -> $f {
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
    for @files.grep({(
        ( $file && $_ ~~ m/^('.'|'..')? $sep? $root $sep 'resources'/)
      ||(!$file && $_ ~~ m/$sep? 'resources'/)
    ) && $_ !~~ m/'/'$/}) -> $f {
      %check{S/^'/'// with $f}++;
    }
    for @resources.unique -> $f {
      %check{$root.IO.add("resources/{$f}").relative}--;
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

  if !($meta<auth>.substr(4) (elem) [(config-value('un')//'<unset>'), |(config-value('groups')//[])]) {
    printf "=<< \"%s\" does not match the username you last logged in with (%s) or a group you belong to,\n=<< you will need to login before uploading your dist\n\n",
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
    $*ERR.say: '=<< You must login to change your info';
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
  my $response;
  while ! ($response<success>//False) {
    $response = try post(
      '/update-meta',
      headers => {'Authorization' => "Zef {config-value('key')}"},
      :%data,
    );

    last if $response<success>;
    if ($response<message>//'') eq 'expired' {
      $*ERR.say: '=<< Key is expired, please login:';
      MAIN('login');
      reload-config;
      next;
    }
    my $error = $response<message> // 'no reason';
    $*ERR.say: '=<< There was an error, please try again in a few minutes';
    exit 255;
  }
  $*ERR.say: '=<< Your meta info has been updated';
}

multi MAIN('org', 'list') is export {
  MAIN('login') unless config-value('key');
  if ! (config-value('key')//0) {
    $*ERR.say: '=<< You must login to upload';
    exit 255;
  }

  my $response = get('/groups', headers => {'Authorization' => "Zef {config-value('key')}"});
  if $response<success>//False {
    say '>>= R Org Name' if +@($response<groups>);
    for @($response<groups>) -> $g {
      say ">>= {$g<role>.substr(0,1)} {$g<group>}";
    }
  } else {
    $*ERR.say: '=<< Something went wrong';
    exit 254;
  }
}

multi MAIN('upload', Str :$file = '', Bool :$save-autobundle = False) is export {
  MAIN('login') unless config-value('key');
  if ! (config-value('key')//0) {
    $*ERR.say: '=<< You must login to upload';
    exit 255;
  }
  my $fn;
  try {
    CATCH { default { printf "=<< ERROR: %s\n", .message; exit 255; } }
    $fn = $file || bundle('.'.IO.absolute);
    if '' ne $file && ! $file.IO.f {
      $*ERR.say: "=<< Cannot find $file";
      exit 255;
    }
  };
  if False && !so MAIN('checkbuild', :file($fn.IO.absolute), :auth-mismatch-error) {
    my $resp = prompt('>>= Upload anyway (y/N)? ') while ($resp//' ') !~~ any('y'|'yes'|'n'|'no'|'');
    if $resp ~~ any('n'|'no'|'') {
      $*ERR.say: '=<< Ok, exiting';
      exit 255;
    }
  }


  my $response;
  while ! ($response<success>//False) {
    $response = get(
      '/upload',
      headers => {'Authorization' => "Zef {config-value('key')}"},
    );

    last if $response<success>;
    if ($response<message>//'') eq 'expired' {
      $*ERR.say: '=<< Key is expired, please login:';
      MAIN('login');
      reload-config;
      next;
    }
    my $error = $response<message> // 'no reason';
    $*ERR.say: "=<< Something went wrong while authenticating: $error. Do you need to run 'fez login' again?";
    exit 255;
  }

  my $upload = post(
     $response<key>,
     :method<PUT>,
     :file($fn.IO.absolute),
  );
  if '' eq $file && !$save-autobundle {
    try {
      CATCH { default {
        $*ERR.say: "=<< Failed to remove temporary file {$fn.relative}: $_";
      } }
      $fn.unlink;
    }
    if $fn.parent.dir.elems == 0 {
      try {
        CATCH { default {
          $*ERR.say: "=<< Failed to remove directory {$fn.parent.relative}: $_";
        } }
        $fn.parent.rmdir;
      }
    }
  }
  say '>>= Hey! You did it! Your dist will be indexed shortly.';
}

multi MAIN('list', Str $name?, Str() :$url = 'http://360.zef.pm/index.json') is export {
  my $response = get('/groups', headers => {'Authorization' => "Zef {config-value('key')}"});
  if ! $response<success>.so {
    $*ERR.say: "=<< Failed to retrieve user orgs, the following list may be incomplete";
  }
  if $response<success> {
    write-to-user-config({ groups => $response<groups> });
  } else {
    $*ERR.say: "=<< Failed to update config";
  }
  my @auths = ["zef:{config-value('un')}", |@($response<groups>).map({"zef:{$_<group>}"})];
  my @dists = (get($url)||[]).grep({$_<auth> (elem) @auths})
                             .grep({!$name.defined || $_<name>.lc.index($name.lc) !~~ Nil})
                             .sort({$^a<name>.lc cmp $^b<name>.lc ~~ Same
                                      ?? Version.new($^a<ver>//$^a<vers>//$^a<version>) cmp 
                                         Version.new($^b<ver>//$^b<vers>//$^b<version>)
                                      !! $^a<name>.lc cmp $^b<name>.lc})
                             .map({$_<dist>});
  say ">>= {+@dists ?? @dists.join("\n>>= ") !! 'No results'}";
}

multi MAIN('remove', Str $dist, Str() :$url = 'http://360.zef.pm/index.json') is export {
  my $d = (get($url)||[]).grep({$_<auth> eq "zef:{config-value('un')}"})
                            .grep({$dist eq $_<dist>})
                            .first;
  if !$d || !$d<path> {
    $*ERR.say: "=<< Couldn't find $dist";
    exit -1;
  }
  try {
    CATCH { default { } }
    my $date = try_dateparse(head( (S/'index.json'?$/$d<path>/ with $url) )<Last-Modified>);
    my $diff = DateTime.now - $date;
    if $diff > 86400 {
      $*ERR.say: "=<< It's past the 24 hour window for removing modules";
      exit 255;
    }
  };
  my $response = try post(
    '/remove',
    headers => {'Authorization' => "Zef {config-value('key')}"},
    :data(dist => $d<dist>),
  );
  if $response<success> {
    say '>>= Request received';
    exit 0;
  }
  $*ERR.say: '=<< Error processing request';
  exit -1;
}

multi MAIN('plugin', Bool :a($all) = False) is export {
  my @base = qw<bundlers requestors>;
  my $user-config = user-config;
  my @keys = $all ?? $user-config.keys.sort !! @base.grep({ $user-config{$_}.defined && +($user-config{$_}) });
  say ">>= User config: {user-config-path}" if +@keys;
  for @keys -> $k {
    say ">>=   $k: ";
    say ">>=     {$user-config{$k}.join("\n>>=     ")}";
  }
  my $env-config = env-config;
  @keys = $all ?? $env-config.keys.sort !! @base.grep({ $env-config{$_}.defined && +($env-config{$_}) });
  say ">>= Environment config: {env-config-path}" if +@keys;
  for @keys -> $k {
    say ">>=   $k: ";
    say ">>=     {$env-config{$k}.join("\n>>=     ")}";
  }
}

multi MAIN('plugin', Str $key where * !~~ 'key'|'un', Str $action where * ~~ 'remove'|'append'|'prepend', Str $value) is export {
  if $action ~~ 'append'|'prepend' {
    my $cfg = user-config{$key}//[];
    write-to-user-config($key => $cfg.^can($action).first.($cfg, $value));
    say ">>= Added {$key}.'$value'";
  } else {
    my $cfg = user-config{$key}//[];
    $cfg = $cfg.grep(* ne $value).unique;
    write-to-user-config($key => $cfg);
    say ">>= Removed {$key}.'$value'";
  }
}

multi MAIN('plugin', Bool :h(:$help)?) is export {
  note qq:to/END/
    Fez - Raku / Perl6 package utility

    USAGE

      fez plugin
        - lists current plugins and config locations
      fez plugin <key> 'remove|append|prepend' <value>
        - removes/appends/prepends <value> from <key>

  END
}

multi MAIN('org', 'help') { MAIN('org', :h); }
multi MAIN('org', Bool :h(:$help)?) {
  note qq:to/END/
    Fez - Raku / Perl6 package utility

    USAGE

      fez org command [args]

    COMMANDS

      create                creates an org in your honor
      list                  lists your current org membership
      members               lists members of \<org-name\>
      pending               shows your current org invites
      accept                accepts an invite listed in pending
      leave                 drops your membership with \<org-name\>
                            note: if you're the last admin of the group this
                                  operation will fail
      invite                invites \<user\> to be a \<role\> user of \<org-name\>
                            note: you must be an admin of the \<org-name\>
                                  to invite other members

  END
}

multi MAIN('help') { MAIN(:h); }
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
      list                  lists the dists for the currently logged in user
      remove                removes a dist from the ecosystem (requires fully
                            qualified dist name, copy from `list` if in doubt)
      org                   org actions, use `fez org help` for more info

    ENV OPTIONS

      FEZ_CONFIG            if you need to modify your config, set this env var

    CONFIGURATION (using: { user-config-path })

      Copy this to a cool location and write your own requestors/bundlers or
      ignore it and use the default curl/wget/git tools for great success.

  END
}

#multi MAIN(*@p, *%n) {
#  ## load extensions
#  my @l = |(user-config<extensions>//[]), |(env-config<extensions>//[]);
#  my %*USAGE;
#  for @l -> $ext {
#    CATCH {
#      default {
#        $*ERR.say: "=<< error loading requested extension: $ext";
#      }
#    }
#    require ::("$ext") <&MAIN>;
#    try {
#      %*USAGE = %*USAGE, | ( try { ::("{$ext}::EXPORT::DEFAULT::%usage"); } // {});
#      ::("{$ext}::EXPORT::DEFAULT::&MAIN").(|@p, |%n);
#      exit 0;
#    };
#  }
#  MAIN(:h);
#  exit 1;
#}
