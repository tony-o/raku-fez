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
use Fez::Util::Glob;
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
  log(MSG, 'fez version: %s', $?DISTRIBUTION.meta<version>);
}

multi MAIN('o', 'c', Str $org-name, Str $org-email) is export {
  MAIN('org', 'create', $org-name, $org-email);
}
multi MAIN('org', 'create', Str $org-name, Str $org-email) is export {
  my $response = org-create(config-value('key'), $org-name, $org-email);
  if $response.success {
    log(MSG, 'You\'re the proud new admin of %s', $org-name);
    $response = org-list(config-value('key'));
    if ! $response.success {
      log(FATAL, 'Failed to retrieve user orgs');
    }
    if $response.success {
      write-to-user-config({ groups => $response.groups });
    } else {
      log(FATAL, 'Failed to update config');
    }
  } else {
    log(FATAL, $response.message);
  }
}

multi MAIN('o', 'l', Str $org-name) is export {
  MAIN('org', 'leave', $org-name);
}
multi MAIN('org', 'leave', Str $org-name) is export {
  my $response = org-leave(config-value('key'), $org-name);
  if $response.success {
    log(MSG, 'You\'re no longer in %s', $org-name);
    $response = org-list(config-value('key'));
    if ! $response.success {
      log(FATAL, 'Failed to retrieve user orgs');
    }
    if $response.success {
      write-to-user-config({ groups => $response.groups });
    } else {
      log(FATAL, 'Failed to update config');
    }
  } else {
    log(FATAL, $response.message);
  }
}

multi MAIN('o', 'a', Str $org-name) is export {
  MAIN('org', 'accept', $org-name);
}
multi MAIN('org', 'accept', Str $org-name) is export {
  my $response = org-join(config-value('key'), $org-name);
  if $response.success {
    log(MSG, 'You\'re now a very nice member of %s', $org-name);
    $response = org-list(config-value('key'));
    if ! $response.success {
      log(FATAL, 'Failed to retrieve user orgs');
    }
    if $response.success {
      write-to-user-config({ groups => $response.groups });
    } else {
      log(FATAL, 'Failed to update config');
    }
  } else {
    log(FATAL, $response.message);
  }
}

multi MAIN('o', 'p') is export {
  MAIN('org', 'pending');
}
multi MAIN('org', 'pending') is export {
  my $response = org-pending(config-value('key'));
  if $response.success {
    log(MSG, 'No pending invites found') unless $response.groups;
    log(MSG, 'R Org') if $response.groups;
    for $response.groups.sort({ $^a<role> eq $^b<role> ?? $^a<group> cmp $^b<group> !! $^a<role> cmp $^b<role> }) -> %g {
      log(MSG, '%s %s', %g<role>.substr(0,1), %g<group>);
    }
  } else {
    log(FATAL, $response.message);
  }
}

multi MAIN('o', 'm', Str $org-name) is export {
  MAIN('org', 'members', $org-name);
}
multi MAIN('org', 'members', Str $org-name) is export {
  my $response = org-members(config-value('key'), $org-name);
  if $response.success {
    log(MSG, 'No members') unless $response.members; # Weird edge case
    log(MSG, 'R Org Name') if $response.members;
    for $response.members.sort({ $^a<role> eq $^b<role> ?? $^a<username> cmp $^b<username> !! $^a<role> cmp $^b<role> }) -> %m {
      log(MSG, '%s %s', %m<role>.substr(0,1), %m<username>);
    }
  } else {
    log(FATAL, $response.message);
  }
}

multi MAIN('o', 'i', Str $org-name, Str $role, Str $user) is export {
  MAIN('org', 'invite', $org-name, $role, $user);
}
multi MAIN('org', 'invite', Str $org-name, Str $role, Str $user) is export {
  my $response = org-invite(config-value('key'), $org-name, $role, $user);
  if $response.success {
    log(MSG, 'Invitation sent');
  } else {
    log(FATAL, $response.message);
  }
}

multi MAIN('o', 'mod', Str $org-name, Str $role, Str $user) is export {
  MAIN('org', 'modify', $org-name, $role, $user);
}
multi MAIN('org', 'modify', Str $org-name, Str $role, Str $user) is export {
  my $response = org-mod(config-value('key'), $org-name, $role, $user);
  if $response.success {
    log(MSG, 'User\'s role was modified');
  } else {
    log(FATAL, $response.message);
  }
}

multi MAIN('reset') is export {
  MAIN('reset-password');
}
multi MAIN('reset-password') is export {
  my $un = prompt-wrapper('>>= Username: ') while ($un//'').chars < 3;
  my $response = init-reset-password($un);
  if ! $response.success {
    log(FATAL, ['There was an error communicating with the service, please',
                'try again in a few minutes.'].join("\n"));
  }
  log(MSG, 'A reset key was successfully requested, please check your email');
  my $key  = prompt-wrapper('>>= What is the key in your email (ctrl+c to cancel)? ') while ($key//'') eq '';
  my $pass = pass-wrapper('>>= New Password: ') while ($pass//'').chars < 8;
  $response = reset-password($un, $key, $pass);
  if ! $response.success {
    log(FATAL, 'Password reset failed: %s', $response<message>);
  }
  write-to-user-config({
    key => $response.key,
    un  => $un,
  });
  log(MSG, 'Password reset successful, you now have a new key and can upload dists');
}

multi MAIN('reg') is export {
  MAIN('register');
}
multi MAIN('register') is export {
  my ($em, $un, $pw);
  $em = prompt-wrapper('>>= Email: ');
  $em = prompt-wrapper('>>= Email: ') while ($em//'').chars < 6
                                         && Nil ~~ log(ERROR, 'Please enter a valid email');
  $un = prompt-wrapper('>>= Username: ');
  $un = prompt-wrapper('>>= Username: ') while ($un//'').chars < 3
                                            && Nil ~~ log(ERROR, 'Username must be longer than 3 chars');
  $pw = pass-wrapper('>>= Password: ');
  $pw = pass-wrapper('>>= Password: ')  while ($pw//'').chars < 8
                                           && Nil ~~ log(ERROR, 'Password must be longer than 8 chars');

  my $response = register($em, $un, $pw);

  if ! $response.success {
    log(FATAL, 'Registration failed: %s', $response.message);
  }
  log(MSG, 'Registration successful, requesting auth key');
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
                                            && Nil ~~ log(ERROR, 'Username must be longer than 3 chars');
  $pw = pass-wrapper('>>= Password: ');
  $pw = pass-wrapper('>>= Password: ')  while ($pw//'').chars < 8
                                           && log(ERROR, 'Password must be longer than 8 chars');

  my $response = login($un, $pw);
  if ! $response.success {
    log(FATAL, 'Failed to login: %s', $response.message);
  }

  my $ukey = $response.key;
  $response = org-list($ukey);
  if ! $response.success {
    log(FATAL, 'Failed to retrieve user groups');
  }

  write-to-user-config({
    key    => $ukey,
    un     => $un,
    groups => $response.groups,
  });
  log(MSG, 'Login successful, you can now upload dists');
}

multi MAIN('rev') is export {
  MAIN('review');
}
multi MAIN('review') is export {
  my $has-error = False;
  my %findings  = MAIN('ref', :d, :q);
  my @manifest  = ls(%findings<meta-dir>, -> $t { %findings<ignorer>.rmatch($t.relative) })
      .sort({ $^a.lc cmp $^b.lc });
  my $repo-cfg  = %findings<meta-dir>.add('.fez').f
               ?? (try {
                 CATCH { default { log(FATAL, 'error reading .fez: %s', $_); } };
                 from-j(%findings<meta-dir>.add('.fez').slurp)
               })
               !! {};

  log(MSG, "Bundle manifest:\n  %s", @manifest.join("\n  "));

  my %metas = (
    'Depends'       => 'depends',
    'Provides'      => 'provides',
    'Build depends' => 'build-depends',
    'Test depends'  => 'test-depends',
    'Resources'     => 'resources',
  );
  my ($ok, $key, $left, $right, $l-diff, $r-diff, $ignores);
  for %metas.keys.sort -> $k {
    $key = %metas{$k};
    $left  = %findings<meta>{$key} ~~ Hash
          ?? %findings<meta>{$key}.keys.Set
          !! %findings<meta>{$key}.Set;
    $right = %findings<new-meta>{$key} ~~ Hash
          ?? %findings<new-meta>{$key}.keys.Set
          !! %findings<new-meta>{$key}.Set;
    $ignores = Set.new('NativeCall', 'Test', 'nqp', |$repo-cfg{"ignore-{$key}"}//Set.new);
    $l-diff  = ($left (-) $right) (-) $ignores;
    $r-diff  = ($right (-) $left) (-) $ignores;

    $ok = $l-diff.elems == 0 && $r-diff.elems == 0;

    $has-error ||= !$ok;

    log(MSG, "%s%s ok", $k, $ok??''!!' not');
    if !$ok {
      my $str = $r-diff
        .keys
        .map({sprintf '%s', $_})
        .join("\n    ");

      log(MSG,"  not in meta:\n    %s",  $str) if $r-diff.elems;

      $str = $l-diff
        .keys
        .map({sprintf '%s', $_})
        .join("\n    ");

      log(MSG, "  in meta but unexpected:\n    %s", $str) if $l-diff.elems;
    }
  }
  log(WARN, '`.rakumod` should be used for module extensions, not `.pm6`')
    if %findings<modfiles>.grep({ $_.ends-with('.pm6') });
  
  if %findings<meta><production>:exists {
    log(WARN,
        ['"production" in META is deprecated. Please create a .fez file with the json object',
         '  {"production":%s}',
         'to continue using this functionality after v53',
        ].join("\n"),
        %findings<meta><production> ?? 'true' !! 'false');
  }
  if ($repo-cfg<production>:exists && !$repo-cfg<production>.so) || (%findings<meta><production>:exists && !%findings<meta><production>.so) {
    log(ERROR, '"production" in project config is set to false');
    $has-error = True;
  }

  my $ver = %findings<meta><ver>
         ?? 'ver'
         !! %findings<meta><vers>
         ?? 'vers'
         !! 'version';
  if $ver ne 'version' {
    log(ERROR, '"version" is the correct version specifier to use (found:%s)', $ver);
    $has-error = True;
  }
  unless %findings<meta><name>//False {
    log(ERROR, 'name should be a value');
    $has-error = True;
  }
  if (%findings<meta>{$ver}//'') eq '' {
    log(ERROR, 'ver should not be nil', 2);
    $has-error = True;
  }
  unless %findings<meta><auth>//False {
    log(ERROR, 'auth should not be nil', 3);
    $has-error = True;
  }
  if %findings<meta>{$ver}.trim eq '*' {
    log(ERROR, 'ver cannot be "*"', 5);
    $has-error = True;
  }
  my @group-auths = (config-value('groups')//[]).map({"zef:{$_<group>}"});
  @group-auths.push("zef:{config-value('un')}") if config-value('un');
  unless %findings<meta><auth> ~~ any(@group-auths) {
    log(
      ERROR,
      "auth does not match logged in user or user's groups\n  expected: %s\n  got: %s",
      @group-auths.raku,
      %findings<meta><auth>, 
    );
    $has-error = True;
  }

  exit 1 if $has-error && !($*DIST//False);

  $has-error;
}

multi MAIN('m', Str :n(:$name) is copy, Str :w(:$website) is copy, Str :e(:$email) is copy) is export {
  MAIN('meta', :$name, :$website, :$email);
}
multi MAIN('meta', Str :n(:$name) is copy, Str :w(:$website) is copy, Str :e(:$email) is copy) is export {
  MAIN('login') unless config-value('key');
  if ! (config-value('key')//0) {
    log(ERROR, 'You must login to change your info');
    exit 255;
  }

  my $ukey = "zef:{config-value('un')}";
  my $response = get('http://360.zef.pm/meta.json');
  if $response{$ukey} {
    log(MSG, 'Name:    %s', $response{$ukey}<name>//'<none provided>');
    log(MSG, 'Email:   %s', $response{$ukey}<email>//'<none provided>');
    log(MSG, 'Website: %s', $response{$ukey}<website>//'<none provided>');
    my $should-update = prompt-wrapper('>>= Would you like to update [y/N]? ').trim;
    if $should-update.uc !~~ 'Y'|'YE'|'YES' {
      exit 0;
    }
  } else {
    log(MSG, 'No existing meta for current user');
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
    $response = update-meta(config-value('key'), %data<name> // '', %data<website> // '', %data<email> // '');

    last if $response.success;
    if ($response.message//'') eq 'expired' {
      log(ERROR, 'Key is expired, please login:');
      MAIN('login');
      reload-config;
      next;
    }
    my $error = $response.message // 'no reason';
    log(FATAL, "There was an error, please try again in a few minutes\nMessage from server: %s", $error);
  }
  log(MSG, 'Your meta info has been updated');
}

multi MAIN('o', 'l') is export {
  MAIN('org', 'list');
}
multi MAIN('org', 'list') is export {
  MAIN('login') unless config-value('key');
  if ! (config-value('key')//0) {
    log(FATAL, 'You must login to upload');
  }

  my $response = org-list(config-value('key'));
  if $response.success {
    log(MSG, 'Not a member of any orgs, yet') unless $response.groups;
    log(MSG, 'R Org Name') if $response.groups;
    for $response.groups -> $g {
      log(MSG, '%s %s', $g<role>.substr(0,1), $g<group>);
    }
  } else {
    log(FATAL, $response.message);
  }
}

multi MAIN('o', 'meta', Str $org-name, Str :n(:$name) is copy, Str :w(:$website) is copy, Str :e(:$email) is copy) is export {
  MAIN('o', 'meta', $org-name, :$name, :$website, :$email);
}
multi MAIN('org', 'meta', Str $org-name, Str :n(:$name) is copy, Str :w(:$website) is copy, Str :e(:$email) is copy) is export {
  MAIN('login') unless config-value('key');
  if ! (config-value('key')//0) {
    log(FATAL, 'You must login to change your org\'s info');
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
    log(MSG, 'Nothing to update');
  }
  %data<org> = $org-name;
  my $response = Fez::Types::api-response.new(:!success);
  while ! ($response.success//False) {
    $response = try update-org-meta(config-value('key'), $org-name, %data<name>, %data<website>, %data<email>);

    last if $response.success;
    if ($response.message//'') eq 'expired' {
      log(ERROR, '=<< Key is expired, please login:');
      MAIN('login');
      reload-config;
      next;
    }
    my $error = $response.message // 'no reason';
    log(FATAL, 'There was an error: %s', $error);
  }
  log(MSG, '%s\'s meta info has been updated', $org-name);
}

multi MAIN('up', Str :i(:$file) = '', Bool :d(:$dry-run) = False, Bool :s(:$save-autobundle) = False, Bool :f(:$force) = False) is export {
  MAIN('upload', :i($file), :s($save-autobundle), :f($force));
}
multi MAIN('upload', Str :i(:$file) = '', Bool :d(:$dry-run) = False,  Bool :s(:$save-autobundle) = False, Bool :f(:$force) = False) is export {
  MAIN('login') unless config-value('key');
  if ! (config-value('key')//0) {
    log(FATAL, 'You must login to upload');
  }
  my $fn = $file;
  try {
    CATCH { default { log(FATAL, 'Bundling error: %s', .message); } }
    if !$file {
      our $*DIST = True;
      my $has-error = MAIN('review');
      if $has-error && !$force {
        my $resp = prompt-wrapper('>>= Upload anyway (y/N)? ') while ($resp//' ').lc !~~ any('y'|'ye'|'yes'|'n'|'no'|'');
        if $resp.lc ~~ any('n'|'no'|'') {
          log(FATAL, 'Ok, exiting');
        }
      }
      $fn = bundle('.'.IO.absolute);
    } elsif ! $file.IO.f {
      log(FATAL, 'Cannot find %s', $file);
    }
  };

  if $dry-run {
    log(INFO, 'Exiting now because --dry-run (or -d) was supplied');
    exit 0;
  }

  my $response = Fez::Types::api-response.new(:!success);
  while ! ($response.success//False) {
    $response = upload(config-value('key'), $fn.IO);

    last if $response.success;
    if ($response.message//'') eq 'expired' {
      log(ERROR, 'Key is expired, please login:');
      MAIN('login');
      reload-config;
      next;
    }
    my $error = $response.message // 'no reason';
    log(FATAL, "Something went wrong while authenticating: %s.\nDo you need to run 'fez login' again?", $error);
  }

  if '' eq $file && !$save-autobundle {
    try {
      CATCH { default {
        log(ERROR, 'Failed to remove temporary file %s: %s', $fn.relative, $_);
      } }
      $fn.unlink;
    }
    if $fn.parent.dir.elems == 0 {
      try {
        CATCH { default {
          log(ERROR, 'Failed to remove directory %s: %s', $fn.parent.relative, $_);
        } }
        $fn.parent.rmdir;
      }
    }
  }
  log(MSG, 'Hey! You did it! Your dist will be indexed shortly.');
}


multi MAIN('ls', Str $name?, Str() :$url = 'http://360.zef.pm/index.json') is export {
  MAIN('list', $name, :$url);
}
multi MAIN('list', Str $name?, Str() :$url = 'http://360.zef.pm/index.json') is export {
  MAIN('login') unless config-value('key');
  my $show-login = False;
  my $response = org-list(config-value('key'));
  if ! $response.success {
    log(ERROR, 'Failed to retrieve user orgs, the following list may be incomplete');
    $show-login = True;
  }
  if $response.success {
    write-to-user-config({ groups => $response.groups });
  } else {
    log(ERROR, 'Failed to update config');
  }
  my @auths = ["zef:{config-value('un')}", |($response.groups//()).map({"zef:{$_<group>}"})];
  my @dists = (get($url)||[]).grep({$_<auth> (elem) @auths})
                             .grep({!$name.defined || $_<name>.lc.index($name.lc) !~~ Nil})
                             .sort({$^a<name>.lc cmp $^b<name>.lc ~~ Same
                                      ?? Version.new($^a<ver>//$^a<vers>//$^a<version>) cmp 
                                         Version.new($^b<ver>//$^b<vers>//$^b<version>)
                                      !! $^a<name>.lc cmp $^b<name>.lc})
                             .map({$_<dist>});
  if +@dists {
    log(MSG, $_) for @dists;
  } else {
    log(MSG, 'No results');
  }
  log(WARN, 'A login may be required to see updated results') if $show-login;
}

multi MAIN('rm', Str $dist, Str() :$url = 'http://360.zef.pm/index.json') is export {
  MAIN('remove', $dist, $url);
}
multi MAIN('remove', Str $dist, Str() :$url = 'http://360.zef.pm/index.json') is export {
  my $response = org-list(config-value('key'));
  if ! $response.success {
    log(ERROR, 'Failed to retrieve user orgs, the following list may be incomplete');
  }
  if $response.success {
    write-to-user-config({ groups => $response<groups> });
  } else {
    log(ERROR, 'Failed to update config');
  }
  my @auths = ["zef:{config-value('un')}", |@($response.groups//[]).map({"zef:{$_<group>}"})];
  my $d = (get($url)||[]).grep({$_<auth> (elem) @auths})
                            .grep({$dist eq $_<dist>})
                            .first;
  if !$d || !$d<path> {
    log(FATAL, 'Couldn\'t find %s', $dist);
  }
  try {
    CATCH { default { } }
    my $date = try_dateparse(head( (S/'index.json'?$/$d<path>/ with $url) )<Last-Modified>);
    my $diff = DateTime.now - $date;
    if $diff > 86400 {
      log(FATAL, 'It\'s past the 24 hour window for removing modules');
    }
  };
  $response = remove(config-value('key'), $d<dist>);
  if $response.success {
    log(MSG, 'Request received');
  }
  log(FATAL, 'Error processing request');
}

multi MAIN('p', Bool :a(:$all) = False) is export {
  MAIN('plugin', :a($all));
}
multi MAIN('plugin', Bool :a(:$all) = False) is export {
  my @base = qw<bundlers requestors>;
  my $user-config = user-config;
  my @keys = $all ?? $user-config.keys.sort !! @base.grep({ $user-config{$_}.defined && +($user-config{$_}) });
  log(MSG, 'User config: %s', user-config-path) if +@keys;
  for @keys -> $k {
    log(MSG, '   %s:', $k);
    log(MSG, '     %s', $user-config{$k});
  }
  my $env-config = env-config;
  @keys = $all ?? $env-config.keys.sort !! @base.grep({ $env-config{$_}.defined && +($env-config{$_}) });
  log(MSG, 'Environment config: %s', env-config-path) if +@keys;
  for @keys -> $k {
    log(MSG, '   %s:', $k);
    log(MSG, '     %s', $env-config{$k}.join("\n     "));
  }
}

multi MAIN('p', Str $key where * !~~ 'key'|'un', Str $action where * ~~ 'remove'|'append'|'prepend', Str $value) is export {
  MAIN('plugin', $key, $action, $value);
}
multi MAIN('plugin', Str $key where * !~~ 'key'|'un', Str $action where * ~~ 'remove'|'append'|'prepend', Str $value) is export {
  if $action ~~ 'append'|'prepend' {
    my $cfg = user-config{$key}//[];
    write-to-user-config($key => $cfg.^can($action).first.($cfg, $value));
    log(MSG, 'Added %s.\'%s\'', $key, $value);
  } else {
    my $cfg = user-config{$key}//[];
    $cfg = $cfg.grep(* ne $value).unique;
    write-to-user-config($key => $cfg);
    log(MSG, 'Removed %s.\'%s\'', $key, $value);
  }
}

constant template-repl-vals = {
  '$user-config-path'   => user-config-path,
  '$system-config-path' => env-config-path,
};
sub template-repl(Str:D $in is copy, %replacements = template-repl-vals --> Str) {
  for %replacements.pairs -> $p {
    $in = $in.subst($p.key, $p.value, :g);
  }

  $in;
}

constant \HELP-HEADER = 'Fez - Raku dist manager';
multi MAIN('h') is export { MAIN(:help); }
multi MAIN('help') is export { MAIN(:help); }
multi MAIN(Bool :h(:$help)?) is export {
  say HELP-HEADER ~ "\n";
  say template-repl(%?RESOURCES<usage/_>.slurp);
}

multi USAGE is export {
  my (@usage, $rx);
  my @keys  = |@*ARGS.grep({!$_.starts-with('-')});
  my @max-usage = @keys.elems == 1
               ?? $?DISTRIBUTION.meta<resources>.grep({"usage/$_" eq @keys[0]}).first//()
               !! ();
  if @max-usage == 0 {
    for @keys.combinations.grep(*.elems) -> @combo {
      $rx   = '^\'usage/\'.*?\'' ~ @combo.join('\'<-[_]>*_\'') ~ '\'<-[_]>*';
      @usage = $?DISTRIBUTION.meta<resources>.grep({$_ ~~ rx/ <$rx> /});
      @max-usage = @usage if +@usage > +@max-usage;
    }
  }
  if +@max-usage > 1 {
    my @options = @max-usage.map({$_.=substr(6); $_ = S:g/'_'/ / given $_; });
    say HELP-HEADER ~ "\n";
    say "Did you mean any of the following?\n  fez {@options.join("\n  fez ")}\n";
  } elsif +@max-usage == 1 {
    say HELP-HEADER ~ "\n";
    say template-repl(%?RESOURCES{@max-usage[0]}.slurp);
  } else {
    MAIN(:help);
  }
}

multi MAIN('ref', Bool:D :d(:$dry-run) = False, :q(:$quiet) = False) is export {
  MAIN('refresh', :$dry-run, :$quiet);
}
multi MAIN('refresh', Bool:D :d(:$dry-run) = False, :q(:$quiet) = False) is export {
  my %findings;
  my $cwd = upcurse-meta();
  log(FATAL, 'could not find META6.json') unless $cwd;
  
  my $repo-cfg  = $cwd.add('.fez').f
               ?? (try {
                 CATCH { default { log(FATAL, 'error reading .fez: %s', $_); } };
                 from-j($cwd.add('.fez').slurp)
               })
               !! {};

  log(DEBUG, "scanning files in {$cwd.add('lib').relative}");
  my $ignorer = $cwd.add('.gitignore').e
             ?? parse(|$cwd.IO.add('.gitignore').IO.slurp.lines, '.git', :git-ignore)
             !! parse('**/.precomp', '**.swp', '.git');

  my @files = ls($cwd.add('lib'), -> $f { 
    !$ignorer.match($f.relative($cwd)) && (
      $f.basename.ends-with('.rakumod') || $f.d || $f.basename.ends-with('.pm6')
    );
  });
  log(DEBUG, "manifest:\n  %s", @files.join("\n  "));
  %findings<modfiles> = @files;

  log(DEBUG, 'looking for modules/classes in those files');
  my %rsult = :use({}), :provides({}), :depends({}), :lib-files({});
  scan-files(@files.sort, sub (Str:D $fn, Str:D $fc) {
    %rsult<lib-files>{$fn}++;
    for $fc.lines -> $ln {
      if my $m = $ln ~~ m:g/^ \s* 'use' \s+ $<use-stmt>=(<-[\s;:]>+ % '::')+ <-[\n]>*?';' / {
        my $match-str = "{$m[0]<use-stmt>.join.Str}";
        if $match-str !~~ any('Test'|'NativeCall'|'nqp') && !$match-str.starts-with('v6.') {
          %rsult<use>{$match-str}.push: $fn;
          log(DEBUG, '[%s]: uses: %s', $fn, $match-str);
        }
      }
      if $m = $ln ~~ m:g/^ \s* ('unit'\s+)? ('module'|'role'|'package'|'class') \s+ $<mod-stmt>=(<-[\s:;]>+ % '::')+ <-[\n]>*? (';'|'{') / {
        if $m.Str ~~ m:g/(^\s* 'unit')|(\s+'is export'(\s+|';'|'{'))/ {
          my $match-str = $m[0]<mod-stmt>.join.Str.trim;
          %rsult<provides>{$match-str}.push: $fn;
          %findings<provides>.push: $fn;
          log(DEBUG, '[%s]: provides: %s', $fn, $match-str);
        } else {
          log(DEBUG, '[%s]: %s missing unit or is export, skipping', $fn, $m.Str);
        }
      }
      if $m = $ln ~~ m:g/^\s*(class|role|module)\s+$<cls-stmt>=(<-[\s:;]>+ % '::')+ <-[\n]>*? (';'|'{') / {
        my $cls = $m[0]<cls-stmt>.join.Str.trim;
        next if $cls ~~ any(|($repo-cfg<ignore-provides>//[]));
        %rsult<provides>{$cls}.push: $fn;
        %findings<provides>.push: $fn;
        log(DEBUG, '[%s]: provides: %s', $fn, $cls);
      }
    }
  });

  %rsult<use>.keys.map({ %rsult<depends>{$_}.push(|%rsult<use>{$_}) unless %rsult<provides>{$_}:exists; });
  %findings<use> = %rsult<use>;

  for %rsult.keys.sort -> $k {
    log(DEBUG,
      "%s:\n%s",
      $k,
      %rsult{$k}
        .keys
        .sort
        .map({ "  $_ => [{%rsult{$k}{$_}.join(", ")}]" })
        .join("\n"));
  }

  my @rsrcs = $cwd.add('resources').d
    ?? ls($cwd.add('resources'), -> $f { True })
         .grep({ $ignorer.rmatch($_) })
         .map({ S/^ 'resources' [\/|\\] // given $_; })
    !! ();

  my %meta = from-j($cwd.add('META6.json').slurp);
  %findings<meta>  = %(|%meta.clone);
  %meta<depends>   = %rsult<depends>.keys.sort.Array;
  %meta<provides>  = %rsult<provides>.keys.sort.map({$_ => %rsult<provides>{$_}.first}).hash;
  %meta<resources> = @rsrcs.sort.Array;

  %findings<new-meta> = %meta;
  %findings<ignorer>  = $ignorer;
  %findings<meta-dir> = $cwd;

  log(DEBUG, to-j(%meta));

  printf "%s\n", to-j(%meta) if $dry-run && !$quiet;
  $cwd.add('META6.json').spurt(to-j(%meta)) unless $dry-run;

  %findings;
}

multi MAIN('li', Str:D :s(:$set) = '') is export {
  MAIN('license', :$set);
}
multi MAIN('license', Str:D :s(:$set) = '') is export {
  log(FATAL,
      "License %s was not found, licenses available:\n  %s",
      $set,
      $?DISTRIBUTION.meta<resources>
        .grep(*.starts-with('licenses/'))
        .map(*.substr(9, *-4))
        .sort({ $^a.lc cmp $^b.lc })
        .join("\n  ")
  ) if !$?DISTRIBUTION.meta<resources>.grep(*.lc eq "licenses/{$set.lc}.txt").elems
    && $set ne '';

  my $cwd = upcurse-meta();
  my $clicense = '';
  $clicense = $cwd.add('LICENSE').slurp if $cwd.add('LICENSE').f;
  $clicense = $cwd.add('LICENSE.txt').slurp if $cwd.add('LICENSE.txt').f;

  log(WARN, 'No license found in repo') if $clicense eq '' && $set eq '';

  if $set eq '' {
    my $match = '';
    for $?DISTRIBUTION.meta<resources>.grep(*.starts-with: "licenses/") -> $rsrc {
      if $clicense eq %?RESOURCES{$rsrc}.slurp {
        $match = $rsrc;
      }
    }

    if $match eq '' {
      log(MSG, 'No license found');
    } else {
      log(MSG, 'Current license: %s', $match.substr(9, *-4));
    }

  } else {
    my $lkey    = $?DISTRIBUTION.meta<resources>.grep(*.lc eq "licenses/{$set.lc}.txt").first;
    my $LICENSE = %?RESOURCES{$lkey}.slurp;
    $cwd.add('LICENSE.txt').spurt: $LICENSE;
    log(MSG, 'Updated repo license to: %s', $lkey.substr(9, *-4)); 
  }
}

multi MAIN('in', Str $module is copy = '', Str:D :l(:$license) = config-value('default-init-license')//'') is export {
  MAIN('init', $module, :$license);
}
multi MAIN('init', Str $module is copy = '', Str:D :l(:$license) = config-value('default-init-license')//'') is export {
  log(FATAL,
      "License %s was not found, licenses available:\n  %s",
      $license,
      $?DISTRIBUTION.meta<resources>
        .grep(*.starts-with('licenses/'))
        .map(*.substr(9, *-4))
        .sort({ $^a.lc cmp $^b.lc })
        .join("\n  ")
  ) if !$?DISTRIBUTION.meta<resources>.grep(*.lc eq "licenses/{$license.lc}.txt").elems
    && $license ne '';

  $module          = prompt-wrapper('>>= Module name? ') while ($module//'').chars == 0;
  my @module-parts = $module.split('::', :skip-empty);
  my $module-file  = @module-parts.pop ~ ".rakumod";
  my $module-path  = 'lib'.IO.add(|@module-parts, $module-file);
  my $dist-name    = S:g/':'/\-/ given $module;
  my $LICENSE      = $license
                  ?? %?RESOURCES{$?DISTRIBUTION.meta<resources>.grep(*.lc eq "licenses/{$license.lc}.txt").first}.slurp
                  !! '';

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
  my $un = config-value('un') // '';
  if $un ne ''  {
    log(DEBUG, "found auth zef:%s", $un);
    $auth = "zef:{$un}";
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
    "test-depends" => [],

    "resources" => [],

    "provides" => {
      "$module" => "$module-path"
    }
  });

  log(DEBUG, 'creating empty unit module file');
  '.'.IO.add($dist-name, $module-path).IO.spurt: "unit module $module;";

  log(DEBUG, 'making test directory');
  mkdir '.'.IO.add($dist-name, 't');
  
  '.'.IO.add($dist-name, 't', '00-use.rakutest').spurt: qq:to/EOF/;
  use Test;

  plan 1;

  use-ok "$module";
  EOF

  if $license ne '' {
    '.'.IO.add($dist-name, 'LICENSE.txt').spurt: $LICENSE;
  }
}

multi MAIN('mod', Str:D $mod, Bool:D :c(:$class) = False) is export {
  MAIN('module', $mod, :$class);
}

multi MAIN('module', Str:D $mod, Bool:D :c(:$class) = False) is export {
  my $cwd = upcurse-meta();
  log(FATAL, 'could not find META6.json') unless $cwd;
  log(DEBUG, "found META6.json in {$cwd.relative}");
  my %meta = from-j($cwd.add('META6.json').slurp);
  if %meta<provides>{$mod}:exists {
    log(FATAL, '%s already exists in provides', $mod);
  }
  my @module-parts = $mod.split('::', :skip-empty);
  my $module-file  = @module-parts.pop ~ ".rakumod";
  my $module-path  = 'lib'.IO.add(|@module-parts, $module-file);
  
  my $root = $cwd.add('lib');
  while @module-parts.elems {
    $root := $root.add(@module-parts.shift);
    mkdir $root.absolute;
  }

  $module-path.spurt("unit {$class??'class'!!'module'} $mod;\n");
  %meta<provides>{$mod} = $module-path.relative($cwd);
  
  $cwd.add('META6.json').spurt(to-j(%meta));
} 

multi MAIN('dep', Str:D $dist, Bool :b(:$build) = False, Bool :r(:$remove) = False) is export {
  MAIN('depends', $dist, :$build, :$remove);
}
multi MAIN('depends', Str:D $dist, Bool :b(:$build) = False, Bool :r(:$remove) = False) is export {
  my $cwd = upcurse-meta();
  log(FATAL, 'could not find META6.json') unless $cwd;
  log(DEBUG, "found META6.json in {$cwd.relative}");

  log(DEBUG, 'inspecting meta file');
  my $dep-key = "{$build??'build-'!!''}depends";
  my %meta = from-j($cwd.add('META6.json').slurp);


  if $remove {
    my $ex = %meta{$dep-key}.grep(* eq $dist);
    my $rc = 0;
    log(DEBUG, "looking for %s in %s (exists? %s)\nexists in meta? %s", $dist, $dep-key, $ex??'yes'!!'no');
    if $ex {
      %meta{$dep-key} = %meta{$dep-key}.grep(* ne $dist).sort;
      $cwd.add('META6.json').spurt: to-j(%meta);
      log(DEBUG, 'new %s: %s', $dep-key, %meta{$dep-key}.join(', '));
      log(MSG, '%s removed', $dist);
    } else {
      log(WARN, '"%s" not found in: "%s": [%s]', $dist, $dep-key, %meta{$dep-key}.sort.join(', '));
      $rc = 1;
    }

    exit $rc;
  }




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

  my $dist-cfg = $cwd.add('.fez');

  $dist-cfg.spurt(to-j({:commands({
    :test(["zef","test","."]),
  })})) unless $dist-cfg.f;

  my $cfg = from-j($dist-cfg.slurp);

  my $m = max $cfg<commands>.keys.map(*.chars);

  for $cfg<commands>.keys.sort -> $k {
    log(MSG, "%-{$m}s: %s", $k, $cfg<commands>{$k});
  }
}

multi MAIN('r', Str:D $command, :t(:$timeout) is copy = 300) is export {
  MAIN('run', $command, :t($timeout));
}
multi MAIN('run', Str:D $command, :t(:$timeout) is copy = 300) is export {
  my $cwd = upcurse-meta();
  log(FATAL, 'could not find META6.json') unless $cwd;

  my $dist-cfg = $cwd.add('.fez');

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

multi MAIN('res', Str:D $path, Bool:D :r($remove) = False) is export {
  MAIN('resource', $path, :$remove);
}
multi MAIN('resource', Str:D $path is copy, Bool:D :r($remove) = False) is export {
  $path.=trim;
  if !$remove && $path ~~ m{'#'|'<'|'>'|'$'|'+'|'%'|'!'|'`'|'&'|'*'|'\''|'|'|'{'|'}'|'?'|'"'|'='|':'|' '|'@'|"\r"|"\n"} || $path.encode.decode('ascii', :replacement<->) ne $path {
    log(FATAL, '%s contains a poor choice of characters, please remove any #<>$+%%>!`&*\'|{}?"=: @', $path);
  }


  my $cwd = upcurse-meta();
  log(FATAL, 'could not find META6.json') unless $cwd;

  my $resource-dir =  $cwd.add('resources');

  if $remove {
    my $me = from-j($cwd.add('META6.json').slurp);
    my $fd = $resource-dir.add($path);
    my $ex = $me<resources>.grep({"resources/$_".IO.relative($cwd) eq $fd.relative($cwd)});
    my $rc = 0;
    log(DEBUG, "looking for %s (exists? %s)\nexists in meta? %s", $fd.relative($cwd), $fd.f??'yes'!!'no', $ex??'yes'!!'no');
    if $ex && $fd.f {
      log(DEBUG, 'exists in dir and META, removing');
      $fd.unlink;
      $me<resources> = $me<resources>.grep({"resources/$_".IO.relative($cwd) ne $fd.relative($cwd)}).sort;
      $cwd.add('META6.json').spurt: to-j($me);
      log(DEBUG, 'new resources: %s', $me<resources>.join(', '));
    } elsif $fd.f {
      log(WARN, 'File %s exists in resources/ but not in META6.json, file will remain in resources/ in case this was a mistake', $fd.relative($cwd));
      $rc = 1;
    } elsif $ex {
      log(WARN, 'File %s exists in META6.json but not in META6.json, will remove from META6.json', $fd.relative($cwd));
      $me<resources> = $me<resources>.grep({"resources/$_".IO.relative($cwd) ne $fd.relative($cwd)}).sort;
      $cwd.add('META6.json').spurt: to-j($me);
      log(DEBUG, 'new resources: %s', $me<resources>.join(', '));
    }

    exit $rc;
  }

  my &ensure-resource-in-meta = sub {
    log(DEBUG, 'ensuring resource is in meta: %s', $path);
    my %meta = from-j($cwd.add('META6.json').slurp);
    if (%meta<resources>||[]).grep($path).elems == 0 {
      log(MSG, 'Resource is not in META, adding it');
      %meta<resources> = [|%meta<resources>, $path];
      $cwd.add('META6.json').spurt: to-j(%meta);
    }
  };

  mkdir($resource-dir) unless $resource-dir.d;
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
