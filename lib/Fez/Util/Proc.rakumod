unit module Fez::Util::Proc;

use Fez::Logr;

sub run-p(Str:D $name, *@p, *%n) is export {
  log(DEBUG, '[%s:starting]', $name);
  my $proc = run(|@p, |%n, :out, :err); 
  my $out  = $proc.out.slurp(:close);
  my $err  = $proc.err.slurp(:close);
  my $rc   = $proc.exitcode;

  log(DEBUG, '[%s:out] %s',  $name, $out) if $out.chars;
  log(DEBUG, '[%s:err] %s',  $name, $err) if $err.chars;
  log(DEBUG, '[%s:exit %d]', $name, $rc);

  [$rc, $out, $err];
}
