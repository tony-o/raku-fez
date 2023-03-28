unit module Fez::Util::META6;

use Fez::Logr;

sub upcurse-meta(--> IO) is export {
  my $cwd = '.'.IO.resolve;
  if !$cwd.add('META6.json').IO.f {
    my $before = $cwd;
    while !$cwd.add('META6.json').IO.f {
      $before = $cwd;
      $cwd := $cwd.parent;
      log(DEBUG, 'recursed to %s, no meta found', $cwd.absolute);
      return Failure if $before.absolute eq $cwd.absolute;
    }
  }
  log(DEBUG, "found META6.json in {$cwd.relative}");
  $cwd;
}
