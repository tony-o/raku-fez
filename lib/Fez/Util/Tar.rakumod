unit class Fez::Util::Tar;

method bundle($location) {
  my $tloc = $location.substr(0, *-3);
  if !('sdist'.IO.d.so) {
    mkdir 'sdist';
  }
  my $tarczf = run 'tar', '-czf', $location, '.', :err, :out;
  die 'Failed to tar and gzip: ' ~ $tarczf.err.slurp.trim unless $tarczf.exitcode == 0;
  return False unless $location.IO.f;
  True;
}

method able {
  my $p = run 'tar', '--help', :out, :err;
  $p.exitcode == 0 && $p.out.slurp.contains: '-z';
}
