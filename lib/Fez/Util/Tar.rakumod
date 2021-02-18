unit class Fez::Util::Tar;

sub ls($x, $ignore) { $x.IO.dir.grep($ignore).map({ $_.d ?? |ls($_, $ignore) !! $_.absolute }); }

method bundle($location) {
  my $tloc = $location.substr(0, *-3);
  if !('sdist'.IO.d.so) {
    mkdir 'sdist';
  }
  my @manifest = ls('.', { $_.basename.substr(0,1) ne '.' && $_.absolute ne $location.IO.parent.absolute });
  my $tarczf = run 'tar', '--exclude=".*"', '--exclude=sdist', '-cvzf', $location, |@manifest, :err, :out;
  die 'Failed to tar and gzip: ' ~ $tarczf.err.slurp.trim unless $tarczf.exitcode == 0;
  return False unless $location.IO.f;
  True;
}

method ls($file) {
  my $p = run 'tar', '--list', '-f', $file, :out, :err;
  return Failure if $p.exitcode != 0;
  return $p.out.slurp.lines;
}

method able {
  my $p = run 'tar', '--help', :out, :err;
  $p.exitcode == 0 && $p.out.slurp.contains: '-z';
}
