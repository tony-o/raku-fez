unit module Fez::CLI;

my Bool $UNATTENDED = False;

use Fez::Logr;
use Fez::Util::Pass;
use Fez::Util::Json;
use Fez::Util::Config;
use Fez::Util::Date;
use Fez::Util::Uri;
use Fez::Util::META6;
use Fez::Util::FS;
use Fez::Web;
use Fez::Bundle;
use Fez::API;

set-loglevel(DEBUG) if (@*ARGS.grep({$_ ~~ m/^'-''v'+$/}).first||' ').chars - 1 != 0;
@*ARGS = @*ARGS.grep({$_ !~~ m/^'-''v'+$/});
$UNATTENDED = @*ARGS.grep(* ~~ '--unattended').elems > 0;
@*ARGS = @*ARGS.grep(* ne '--unattended');
log(DEBUG, 'Running in unattended mode') if $UNATTENDED;

sub pass-wrapper(Str:D $prompt --> Str) {
  if $UNATTENDED {
    log(FATAL, 'Unable to prompt while --unattended is in use');
  }
  getpass($prompt);
}

sub prompt-wrapper(Str:D $prompt --> Str) {
  if $UNATTENDED {
    log(FATAL, 'Unable to prompt while --unattended is in use');
  }
  prompt($prompt);
}

multi MAIN('v') is export is pure {
  MAIN('version');
}
multi MAIN('version') is export is pure {
  say '>>= fez version: ' ~ $?DISTRIBUTION.meta<version>;
}

multi MAIN('o', 'c', Str $org-name, Str $org-email) is export {
  MAIN('org', 'create', $org-name, $org-email);
}
multi MAIN('org', 'create', Str $org-name, Str $org-email) is export {
  my $response = org-create(config-value('key'), $org-name, $org-email);
  if $response.success {
    say ">>= You're the proud new admin of $org-name";
    $response = org-list(config-value('key'));
    if ! $response.success {
      $*ERR.say: "=<< Failed to retrieve user orgs";
      exit 255;
    }
    if $response.success {
      write-to-user-config({ groups => $response.groups });
    } else {
      $*ERR.say: "=<< Failed to update config";
      exit 1;
    }
  } else {
    $*ERR.say: "=<< {$response.message}";
    exit 255;
  }
}

multi MAIN('o', 'l', Str $org-name) is export {
  MAIN('org', 'leave', $org-name);
}
multi MAIN('org', 'leave', Str $org-name) is export {
  my $response = org-leave(config-value('key'), $org-name);
  if $response.success {
    say ">>= You're no longer in $org-name";
    $response = org-list(config-value('key'));
    if ! $response.success {
      $*ERR.say: "=<< Failed to retrieve user orgs";
      exit 255;
    }
    if $response.success {
      write-to-user-config({ groups => $response.groups });
    } else {
      $*ERR.say: "=<< Failed to update config";
      exit 1;
    }
  } else {
    $*ERR.say: "=<< {$response.message}";
    exit 255;
  }
}

multi MAIN('o', 'a', Str $org-name) is export {
  MAIN('org', 'accept', $org-name);
}
multi MAIN('org', 'accept', Str $org-name) is export {
  my $response = org-join(config-value('key'), $org-name);
  if $response.success {
    say ">>= You're now a very nice member of $org-name";
    $response = org-list(config-value('key'));
    if ! $response.success {
      $*ERR.say: "=<< Failed to retrieve user orgs";
      exit 255;
    }
    if $response.success {
      write-to-user-config({ groups => $response.groups });
    } else {
      $*ERR.say: "=<< Failed to update config";
      exit 1;
    }
  } else {
    $*ERR.say: "=<< {$response.message}";
    exit 255;
  }
}

multi MAIN('o', 'p') is export {
  MAIN('org', 'pending');
}
multi MAIN('org', 'pending') is export {
  my $response = org-pending(config-value('key'));
  if $response.success {
    say '>>= No pending invites found' unless $response.groups;
    say '>>= R Org' if $response.groups;
    for $response.groups.sort({ $^a<role> eq $^b<role> ?? $^a<group> cmp $^b<group> !! $^a<role> cmp $^b<role> }) -> %g {
      say ">>= {%g<role>.substr(0,1)} {%g<group>}";
    }
  } else {
    $*ERR.say: "=<< Failed. {$response.message}";
    exit 255;
  }
}

multi MAIN('o', 'm', Str $org-name) is export {
  MAIN('org', 'members', $org-name);
}
multi MAIN('org', 'members', Str $org-name) is export {
  my $response = org-members(config-value('key'), $org-name);
  if $response.success {
    say '>>= No members' unless $response.members; # Weird edge case
    say '>>= R Org Name' if $response.members;
    for $response.members.sort({ $^a<role> eq $^b<role> ?? $^a<username> cmp $^b<username> !! $^a<role> cmp $^b<role> }) -> %m {
      say ">>= {%m<role>.substr(0,1)} {%m<username>}"
    }
  } else {
    $*ERR.say: "=<< Failed. {$response.message}";
    exit 255;
  }
}

multi MAIN('o', 'i', Str $org-name, Str $role, Str $user) is export {
  MAIN('org', 'invite', $org-name, $role, $user);
}
multi MAIN('org', 'invite', Str $org-name, Str $role, Str $user) is export {
  my $response = org-invite(config-value('key'), $org-name, $role, $user);
  if $response.success {
    say '>>= Invitation sent';
  } else {
    $*ERR.say: '=<< Failed: ' ~ $response.message;
    exit 255;
  }
}

multi MAIN('o', 'mod', Str $org-name, Str $role, Str $user) is export {
  MAIN('org', 'modify', $org-name, $role, $user);
}
multi MAIN('org', 'modify', Str $org-name, Str $role, Str $user) is export {
  my $response = org-mod(config-value('key'), $org-name, $role, $user);
  if $response.success {
    say '>>= User\'s role was modified';
  } else {
    $*ERR.say: '=<< Failed: ' ~ $response.message;
    exit 255;
  }
}

multi MAIN('reset') is export {
  MAIN('reset-password');
}
multi MAIN('reset-password') is export {
  my $un = prompt-wrapper('>>= Username: ') while ($un//'').chars < 3;
  my $response = init-reset-password($un);
  if ! $response.success {
    $*ERR.say: '=<< There was an error communicating with the service, please';
    $*ERR.say: '    try again in a few minutes.';
    exit 255;
  }
  say '>>= A reset key was successfully requested, please check your email';
  my $key  = prompt-wrapper('>>= What is the key in your email (ctrl+c to cancel)? ') while ($key//'') eq '';
  my $pass = pass-wrapper('>>= New Password: ') while ($pass//'').chars < 8;
  $response = reset-password($un, $key, $pass);
  if ! $response.success {
    $*ERR.say: "=<< Password reset failed: {$response<message>}";
    exit 255;
  }
  write-to-user-config({
    key => $response.key,
    un  => $un,
  });
  say ">>= Password reset successful, you now have a new key and can upload dists";
}

multi MAIN('reg') is export {
  MAIN('register');
}
multi MAIN('register') is export {
  my ($em, $un, $pw);
  $em = prompt-wrapper('>>= Email: ');
  $em = prompt-wrapper('>>= Email: ') while ($em//'').chars < 6
                                 && 1 == $*ERR.say('=<< Please enter a valid email');
  $un = prompt-wrapper('>>= Username: ');
  $un = prompt-wrapper('>>= Username: ') while ($un//'').chars < 3
                                    && 1 == $*ERR.say('=<< Username must be longer than 3 chars');
  $pw = pass-wrapper('>>= Password: ');
  $pw = pass-wrapper('>>= Password: ')  while ($pw//'').chars < 8
                                      && 1 == $*ERR.say('=<< Password must be longer than 8 chars');

  my $response = register($em, $un, $pw);

  if ! $response.success {
    $*ERR.say: "=<< Registration failed: {$response.message}";
    exit 255;
  }
  say ">>= Registration successful, requesting auth key";
  my $*USERNAME = $un;
  my $*PASSWORD = $pw;
  MAIN('login');
  MAIN('meta');
}

multi MAIN('l') is export {
  MAIN('login');
}
multi MAIN('login') is export {
  my $un = $*USERNAME // '';
  my $pw = $*PASSWORD // '';
  $un = prompt-wrapper('>>= Username: ');
  $un = prompt-wrapper('>>= Username: ') while ($un//'').chars < 3
                                    && 1 == $*ERR.say('=<< Username must be longer than 3 chars');
  $pw = pass-wrapper('>>= Password: ');
  $pw = pass-wrapper('>>= Password: ')  while ($pw//'').chars < 8
                                      && 1 == $*ERR.say('=<< Password must be longer than 8 chars');

  my $response = login($un, $pw);
  if ! $response.success {
    $*ERR.say: "=<< Failed to login: {$response.message}";
    exit 255;
  }

  my $ukey = $response.key;
  $response = org-list($ukey);
  if ! $response.success {
    $*ERR.say: "=<< Failed to retrieve user groups";
    exit 255;
  }

  write-to-user-config({
    key    => $ukey,
    un     => $un,
    groups => $response.groups,
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
        $fn = $f if $f ~~ m/^(".$sep") ** 0..1 $root $sep 'META6.json'$/;
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
      $*ERR.say: '=<< Unable to verify meta';
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
    $error('Unable to list dist files', :!exit);
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

  my @groups = .map({.<group>}) with config-value('groups');
  if !($meta<auth>.substr(4) (elem) [(config-value('un')//'<unset>'), |@groups]) {
    printf "=<< \"%s\" does not match the username you last logged in with (%s) or a group you belong to\n=<< you will need to login before uploading your dist\n\n",
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

multi MAIN('m', Str :$name is copy, Str :$website is copy, Str :$email is copy) is export {
  MAIN('meta', :$name, :$website, :$email);
}
multi MAIN('meta', Str :$name is copy, Str :$website is copy, Str :$email is copy) is export {
  MAIN('login') unless config-value('key');
  if ! (config-value('key')//0) {
    $*ERR.say: '=<< You must login to change your info';
    exit 255;
  }

  my $ukey = "zef:{config-value('un')}";
  my $response = try get('http://360.zef.pm/meta.json');
  if $response{$ukey} {
    say ">>= Name:    {$response{$ukey}<name>//'<none provided>'}";
    say ">>= Email:   {$response{$ukey}<email>//'<none provided>'}";
    say ">>= Website: {$response{$ukey}<website>//'<none provided>'}";
    my $should-update = prompt-wrapper('>>= Would you like to update [y/N]? ').trim;
    if $should-update.uc !~~ 'Y'|'YE'|'YES' {
      exit 0;
    }
  } else {
    say '>>= No existing meta for current user';
  }

  my %data;
  if ($name//'') eq '' && ($website//'') eq '' && ($email//'') eq '' {
    %data<name>    = prompt-wrapper('>>= What would you like your display name to show? ').trim;
    %data<website> = prompt-wrapper('>>= What\'s your website? ').trim;
    %data<email>   = prompt-wrapper('>>= Public email address? ').trim;
  } else {
    %data<name> = $name if ($name//'') ne '';
    %data<website> = $website if ($website//'') ne '';
    %data<email> = $email if ($email//'') ne '';
  }
  for %data.keys {
    %data{$_}:delete if %data{$_} eq '';
  }
  $response = Fez::Types::api-response.new(:!success);
  while ! ($response.success//False) {
    $response = update-meta(config-value('key'), %data<name>, %data<website>, %data<email>);

    last if $response.success;
    if ($response.message//'') eq 'expired' {
      $*ERR.say: '=<< Key is expired, please login:';
      MAIN('login');
      reload-config;
      next;
    }
    my $error = $response.message // 'no reason';
    $*ERR.say: '=<< There was an error, please try again in a few minutes';
    exit 255;
  }
  $*ERR.say: '=<< Your meta info has been updated';
}

multi MAIN('o', 'l') is export {
  MAIN('org', 'list');
}
multi MAIN('org', 'list') is export {
  MAIN('login') unless config-value('key');
  if ! (config-value('key')//0) {
    $*ERR.say: '=<< You must login to upload';
    exit 255;
  }

  my $response = org-list(config-value('key'));
  if $response.success {
    say '>>= Not a member of any orgs, yet' unless $response.groups;
    say '>>= R Org Name' if $response.groups;
    for $response.groups -> $g {
      say ">>= {$g<role>.substr(0,1)} {$g<group>}";
    }
  } else {
    $*ERR.say: '=<< Something went wrong';
    exit 254;
  }
}

multi MAIN('o', 'meta', Str $org-name, Str :$name is copy, Str :$website is copy, Str :$email is copy) is export {
  MAIN('o', 'meta', $org-name, :$name, :$website, :$email);
}
multi MAIN('org', 'meta', Str $org-name, Str :$name is copy, Str :$website is copy, Str :$email is copy) is export {
  MAIN('login') unless config-value('key');
  if ! (config-value('key')//0) {
    $*ERR.say: '=<< You must login to change your org\'s info';
    exit 255;
  }
  my %data;
  if ($name//'') eq '' && ($website//'') eq '' && ($email//'') eq '' {
    %data<name>    = prompt-wrapper('>>= What would you like your display name to show? ').trim;
    %data<website> = prompt-wrapper('>>= What\'s your website? ').trim;
    %data<email>   = prompt-wrapper('>>= Public email address? ').trim;
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
  %data<org> = $org-name;
  my $response = Fez::Types::api-response.new(:!success);
  while ! ($response.success//False) {
    $response = try update-org-meta(config-value('key'), $org-name, %data<name>, %data<website>, %data<email>);

    last if $response.success;
    if ($response.message//'') eq 'expired' {
      $*ERR.say: '=<< Key is expired, please login:';
      MAIN('login');
      reload-config;
      next;
    }
    my $error = $response.message // 'no reason';
    $*ERR.say: '=<< There was an error: ' ~ $error;
    exit 255;
  }
  $*ERR.say: "=<< $org-name\'s meta info has been updated";
}

multi MAIN('up', Str :$file = '', Bool :s($save-autobundle) = False, Bool :f($force) = False) is export {
  MAIN('upload', $file, :$save-autobundle, :$force);
}
multi MAIN('upload', Str :$file = '', Bool :$save-autobundle = False, Bool :$force = False) is export {
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
  if !$force {
    if !so MAIN('checkbuild', :file($fn.IO.absolute), :auth-mismatch-error) {
      my $resp = prompt-wrapper('>>= Upload anyway (y/N)? ') while ($resp//' ').lc !~~ any('y'|'ye'|'yes'|'n'|'no'|'');
      if $resp.lc ~~ any('n'|'no'|'') {
        $*ERR.say: '=<< Ok, exiting';
        exit 255;
      }
    }
  }

  my $response = Fez::Types::api-response.new(:!success);
  while ! ($response.success//False) {
    $response = upload(config-value('key'), $fn.IO);

    last if $response.success;
    if ($response.message//'') eq 'expired' {
      $*ERR.say: '=<< Key is expired, please login:';
      MAIN('login');
      reload-config;
      next;
    }
    my $error = $response.message // 'no reason';
    $*ERR.say: "=<< Something went wrong while authenticating: $error. Do you need to run 'fez login' again?";
    exit 255;
  }

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


multi MAIN('ls', Str $name?, Str() :$url = 'http://360.zef.pm/index.json') is export {
  MAIN('list', $name, $url);
}
multi MAIN('list', Str $name?, Str() :$url = 'http://360.zef.pm/index.json') is export {
  MAIN('login') unless config-value('key');
  my $show-login = False;
  my $response = org-list(config-value('key'));
  if ! $response.success {
    $*ERR.say: "=<< Failed to retrieve user orgs, the following list may be incomplete";
    $show-login = True;
  }
  if $response.success {
    write-to-user-config({ groups => $response.groups });
  } else {
    $*ERR.say: "=<< Failed to update config";
  }
  my @auths = ["zef:{config-value('un')}", |($response.groups//()).map({"zef:{$_<group>}"})];
  my @dists = (get($url)||[]).grep({$_<auth> (elem) @auths})
                             .grep({!$name.defined || $_<name>.lc.index($name.lc) !~~ Nil})
                             .sort({$^a<name>.lc cmp $^b<name>.lc ~~ Same
                                      ?? Version.new($^a<ver>//$^a<vers>//$^a<version>) cmp 
                                         Version.new($^b<ver>//$^b<vers>//$^b<version>)
                                      !! $^a<name>.lc cmp $^b<name>.lc})
                             .map({$_<dist>});
  say ">>= {+@dists ?? @dists.join("\n>>= ") !! 'No results'}";
  $*ERR.say("=<< A login may be required to see updated results") if $show-login;
}

multi MAIN('rm', Str $dist, Str() :$url = 'http://360.zef.pm/index.json') is export {
  MAIN('remove', $dist, $url);
}
multi MAIN('remove', Str $dist, Str() :$url = 'http://360.zef.pm/index.json') is export {
  my $response = org-list(config-value('key'));
  if ! $response.success {
    $*ERR.say: "=<< Failed to retrieve user orgs, the following list may be incomplete";
  }
  if $response.success {
    write-to-user-config({ groups => $response<groups> });
  } else {
    $*ERR.say: "=<< Failed to update config";
  }
  my @auths = ["zef:{config-value('un')}", |@($response.groups//[]).map({"zef:{$_<group>}"})];
  my $d = (get($url)||[]).grep({$_<auth> (elem) @auths})
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
  $response = remove(config-value('key'), $d<dist>);
  if $response.success {
    say '>>= Request received';
    exit 0;
  }
  $*ERR.say: '=<< Error processing request';
  exit -1;
}

multi MAIN('p', Bool :a($all) = False) is export {
  MAIN('plugin', :$all);
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

multi MAIN('o', 'h') { MAIN('org', :h); }
multi MAIN('org', 'help') { MAIN('org', :h); }
multi MAIN('org', Bool :h(:$help)?) is export {
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
      leave                 drops your membership with \<org-name\> *1
      invite                invites a user to join your org, must be an admin
      mod                   use this to modify a user's role, must be an admin
      meta                  update your org's meta

      
    NOTES\*

      1. If you're the last admin of the group you must first modify your role to
      member and then leave the group. The org is then considered abandoned,
      there is no way to use fez to recover the org after this action.

  END
}

multi MAIN('h') { MAIN(:h); }
multi MAIN('help') { MAIN(:h); }
multi MAIN(Bool :h(:$help)?) is export {
  note qq:to/END/
    Fez - Raku / Perl6 package utility

    USAGE

      fez command [args]

    COMMANDS

      INFORMATION

        v|version             prints out the version of fez you're using

      DIST MANAGEMENT

        init                  initializes a new module
        resource              creates a new resource file at the given path, creat-
                              ing the path if necessary
        depends               add a build or runtime dependency to the meta
        cmd                   list commands this module provides
        run                   runs a command listed in `cmd`
        refresh               attempts to update the META6 from the file system
                              this does NOT prompt before overwriting

      RELEASE MANAGEMENT

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

multi USAGE is export {
  @*ARGS.grep(* ~~ 'o'|'org')
    ?? MAIN('org', :help)
    !! MAIN(:help);
}

multi MAIN('ref', Bool:D :d($dry-run) = False) is export {
  MAIN('refresh', :d($dry-run));
}
multi MAIN('refresh', Bool:D :d($dry-run) = False) is export {
  my $cwd = upcurse-meta();
  log(FATAL, 'could not find META6.json') unless $cwd;
  log(DEBUG, "found META6.json in {$cwd.relative}");
  
  log(DEBUG, "scanning files in {$cwd.add('lib').relative}");
  my @files = get-files-in-dir($cwd.add('lib'), -> $f { 
    $f.basename ~~ m/'.'['pm6'|'rakumod']$/;
  });
  log(DEBUG, @files.join("\n"));

  log(DEBUG, 'looking for modules/classes in those files');
  my %rsult = :use({}), :provides({}), :depends({}), :lib-files({});
  scan-files(@files.sort, sub (Str:D $fn, Str:D $fc) {
    %rsult<lib-files>{$fn}++;
    for $fc.lines -> $ln {
      if my $m = $ln ~~ m:g/^ \s* 'use' \s+ $<use-stmt>=(<-[\s;:]>+ % '::')+ <-[\n]>*?';' / {
        my $match-str = "{$m[0]<use-stmt>.join.Str}";
        if $match-str !~~ 'Test'|'NativeCall'|'nqp' {
          %rsult<use>{$match-str}.push: $fn;
          log(DEBUG, '[%s]: uses: %s', $fn, $match-str);
        }
      }
      if $m = $ln ~~ m:g/^ \s* ('unit'\s+)? ('module'|'package'|'class') \s+ $<mod-stmt>=(<-[\s:;]>+ % '::')+ <-[\n]>*? (';'|'{') / {
        if $m.Str ~~ m:g/(^\s* 'unit')|(\s+'is export'(\s+|';'|'{'))/ {
          my $match-str = $m[0]<mod-stmt>.join.Str.trim;
          %rsult<provides>{$match-str}.push: $fn;
          log(DEBUG, '[%s]: provides: %s', $fn, $match-str);
        } else {
          log(DEBUG, '[%s]: %s missing unit or is export, skipping', $fn, $m.Str);
        }
      }
    }
  });

  %rsult<use>.keys.map({ %rsult<depends>{$_}.push(|%rsult<use>{$_}) unless %rsult<provides>{$_}:exists; });

  for %rsult.keys.sort -> $k {
    log(DEBUG, "%s:\n%s", $k, %rsult{$k}.keys.sort.map({ "  $_ => [{%rsult{$k}{$_}.join(", ")}]" }).join("\n"));
  }
  
  my @rsrcs = get-files-in-dir($cwd.add('resources'), -> $f { True })
    .map({ S/^ 'resources' [\/|\\] // given $_; });

  my %meta = from-j($cwd.add('META6.json').slurp);
  %meta<depends> = %rsult<depends>.keys.sort;
  %meta<provides> = %rsult<provides>.keys.sort.map({$_ => %rsult<provides>{$_}.first}).hash;
  %meta<resources> = @rsrcs.sort;

  log(DEBUG, to-j(%meta));

  printf "%s\n", to-j(%meta) if $dry-run;
  $cwd.add('META6.json').spurt(to-j(%meta)) unless $dry-run;
}

multi MAIN('in', Str $module is copy = '') is export {
  MAIN('init', $module);
}
multi MAIN('init', Str $module is copy = '') is export {
  $module          = prompt-wrapper('>>= Module name? ') while ($module//'').chars == 0;
  my @module-parts = $module.split('::', :skip-empty);
  my $module-file  = @module-parts.pop ~ ".rakumod";
  my $module-path  = 'lib'.IO.add(|@module-parts, $module-file);
  my $dist-name = S:g/':'/\-/ given $module;

  log(DEBUG, "module-parts:%s\nmodule-file:%s\nmodule-path:%s\n  dist-name:%s", @module-parts.join(', '), $module-file, $module-path, $dist-name);

  log(FATAL, "'%s' exists, will not proceed\n", $dist-name) if '.'.IO.add($dist-name).e;

  mkdir $dist-name;

  my $root := '.'.IO.add($dist-name, 'lib').IO;
  mkdir $root.absolute;
  while @module-parts.elems {
    $root := $root.add(@module-parts.shift);
    mkdir $root.absolute;
  }

  my $auth = '';
  if ?config-value('un') ne '' {
    log(DEBUG, "found auth zef:%s", config-value('un'));
    $auth = "zef:{config-value('un')}";
  } else {
    log(INFO, "no auth found for the zef ecosystem, creating with empty auth str");
  }

  log(DEBUG, 'creating meta file');
  '.'.IO.add($dist-name, 'META6.json').IO.spurt: to-j({
    "name" => "$dist-name",
    "version" =>  "0.0.1",
    "auth" => "$auth",

    "description" => "A brand new and very nice module",

    "depends" => [],
    "build-depends" => [],

    "resources" => [],

    "provides" => {
      "$module" => "$module-path"
    }
  });

  log(DEBUG, 'creating empty unit module file');
  '.'.IO.add($dist-name, $module-path).IO.spurt: "unit module $module;";

  log(DEBUG, 'making test directory');
  mkdir '.'.IO.add($dist-name, 't');
  
  '.'.IO.add($dist-name, 't', '00-use.t').spurt: qq:to/EOF/;
    use Test;

    plan 1;

    use-ok "$module";
  EOF
}

multi MAIN('dep', Str:D $dist, Bool :$build = False) is export {
  MAIN('depends', $dist, :$build);
}
multi MAIN('depends', Str:D $dist, Bool :$build = False) is export {
  my $cwd = upcurse-meta();
  log(FATAL, 'could not find META6.json') unless $cwd;
  log(DEBUG, "found META6.json in {$cwd.relative}");

  log(DEBUG, 'inspecting meta file');
  my $dep-key = "{$build??'build-'!!''}depends";
  my %meta = from-j($cwd.add('META6.json').slurp);
  if (%meta{$dep-key}||[]).grep($dist).elems == 0 {
    log(DEBUG, "did not find dependency (%s) in %s", $dist, $dep-key);
    %meta{$dep-key} = [] unless %meta{$dep-key};
    %meta{$dep-key}.push($dist);
    $cwd.add('META6.json').spurt: to-j(%meta);
    log(MSG, "%s was not found in %s so it was added", $dist, $dep-key);
  } else {
    log(MSG, "%s already exists in %s", $dist, $dep-key);
  }
}

multi MAIN('cmd') is export {
  MAIN('command');
}
multi MAIN('command') is export {
  my $cwd = upcurse-meta();
  log(FATAL, 'could not find META6.json') unless $cwd;
  log(DEBUG, "found META6.json in {$cwd.relative}");

  my $dist-cfg = $cwd.add('.zef');

  $dist-cfg.spurt(to-j({:commands({
    :test(["zef","test","."]),
  })})) unless $dist-cfg.f;

  my $cfg = from-j($dist-cfg.slurp);

  my $m = max $cfg<commands>.keys.map(*.chars);

  for $cfg<commands>.keys.sort -> $k {
    log(MSG, "%-{$m}s: %s", $k, $cfg<commands>{$k});
  }
}

multi MAIN('r', Str:D $command, :$timeout is copy) is export {
  MAIN('run', $command, :$timeout);
}
multi MAIN('run', Str:D $command, :$timeout is copy) is export {
  my $cwd = upcurse-meta();
  log(FATAL, 'could not find META6.json') unless $cwd;

  my $dist-cfg = $cwd.add('.zef');

  $dist-cfg.spurt(to-j({:commands({
    :test(["zef", "test", "."]),
  })})) unless $dist-cfg.f;

  my $cfg = from-j($dist-cfg.slurp);
  
  log(FATAL, '"%s" command not found\navailable commands: %s', $command, $cfg<commands>.keys.sort.join(', '))
    unless $cfg<commands>{$command};

  my @cmd = |$cfg<commands>{$command};

  my $proc = Proc::Async.new: |@cmd;

  $timeout = $timeout.defined ?? $timeout !! $cfg<command_timeout> || 300;
  react {
    whenever $proc.stdout.lines { $_ ~~ s:g/'%'/%%/; log( INFO, $_); };
    whenever $proc.stderr.lines { $_ ~~ s:g/'%'/%%/; log(ERROR, $_); };
    whenever $proc.start {
      exit 0;
    };
    whenever signal(SIGTERM).merge: signal(SIGINT) {
      once {
        log(INFO, 'Attempting to kill process...');
        try $proc.kill: SIGKILL;
      }
    };
    whenever Promise.in($timeout) {
      try $proc.kill: SIGKILL;
      log(FATAL, 'Process timed out');
    }
  };
}

multi MAIN('res', Str:D $path) is export {
  MAIN('resource', $path);
}
multi MAIN('resource', Str:D $path is copy) is export {
  $path.=trim;
  if $path ~~ m{'#'|'<'|'>'|'$'|'+'|'%'|'!'|'`'|'&'|'*'|'\''|'|'|'{'|'}'|'?'|'"'|'='|':'|' '|'@'|"\r"|"\n"} || $path.encode.decode('ascii', :replacement<->) ne $path {
    log(FATAL, '%s contains a poor choice of characters, please remove any #<>$+%%>!`&*\'|{}?"=: @', $path);
  }


  my $cwd = upcurse-meta();
  log(FATAL, 'could not find META6.json') unless $cwd;

  my $resource-dir =  $cwd.add('resources');

  my &ensure-resource-in-meta = sub {
    log(DEBUG, 'ensuring resource is in meta: %s', $path);
    my %meta = from-j($cwd.add('META6.json').slurp);
    if (%meta<resources>||[]).grep($path).elems == 0 {
      log(MSG, 'Resource is not in META, adding it');
      %meta<resources> = [|%meta<resources>, $path];
      $cwd.add('META6.json').spurt: to-j(%meta);
    }
  };

  if $resource-dir.add($path).e {
    log(MSG, 'Resource exists - not creating any directories or files');
    ensure-resource-in-meta;
    exit 0;
  }

  if $path ~~ m/(^|'/'|'\\')'..'('/'|'\\'|$)/ {
    log(FATAL, "Cannot create resources outside of the project resources/ dir or with relative paths\nWhatever path is provided will automatically reside under {$resource-dir.absolute}");
  }

  my @parts = $path.IO.relative.split($*DISTRO.is-win??'\\'!!'/', :skip-empty);
  my $fname = @parts.pop;
  my $cdir := $resource-dir;

  log(DEBUG, 'resolving: %s', @parts.join('/'));
  while @parts.elems {
    $cdir = $cdir.add(@parts.shift);
    log(DEBUG, "making {$cdir.absolute}") unless $cdir.IO.d;
    log(DEBUG, "skip {$cdir.absolute}") if $cdir.IO.d;
    mkdir $cdir unless $cdir.IO.d;
  }

  log(DEBUG, 'creating resource:');
  $cdir.add($fname).spurt: '';
  ensure-resource-in-meta;
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
