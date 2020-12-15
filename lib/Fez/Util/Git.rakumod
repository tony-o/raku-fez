unit class Fez::Util::Git;

method bundle($location) {
  my $tloc = $location.substr(0, *-3);
  my $branch = run('git', 'branch', '--show-current', :err, :out);
  die 'Failed to determine git branch' unless $branch.exitcode == 0;
  my $proc   = run('git', 'archive', '--format', 'tar', '-o', $tloc, $branch.out.slurp.trim, :err, :out);
  die 'Failed to run git archive: ' ~ $proc.err.slurp.trim unless $proc.exitcode == 0;
  $proc = run('gzip', '-9', $tloc);
  die 'Failed to gzip tarball: ' ~ $proc.err.slurp.trim unless $proc.exitcode == 0;
  return False unless $location.IO.f;
  True;
}

method able {
  my $p2 = run 'gzip', '--version', :out, :err;
  '.git'.IO.d.so && $p2.exitcode == 0;
}
