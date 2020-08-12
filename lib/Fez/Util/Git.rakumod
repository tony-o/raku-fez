unit class Fez::Util::Git;

method bundle($location) {
  my $branch = run('git', 'branch', '--show-current', :err, :out);
  die 'Failed to determine git branch' unless $branch.exitcode == 0;
  my $proc   = run('git', 'archive', '--format=tar', '-o', $location, $branch.out.slurp, :err, :out);
  die 'Failed to run git archive' unless $proc.exitcode == 0;
  return False unless $location.IO.f;
  True;
}

method able {
  '.git'.IO.d.so;
}
