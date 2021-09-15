unit class Fez::Util::Tar;

sub ls($x, $ignore) { $x.IO.dir.grep($ignore).map({ $_.d ?? |ls($_, $ignore) !! $_.resolve.relative }); }

method bundle($location) {
  if !('sdist'.IO.d.so) {
    mkdir 'sdist';
  }
  my $pwd = '.'.IO.resolve.basename;
  my $cwd = $*CWD.resolve;
  $*CWD = $cwd.add('..').resolve;
  my @manifest = ls('.'.IO.add($pwd).absolute, { $_.basename.substr(0,1) ne '.' && $_.absolute ne $pwd.IO.parent.absolute });
  my $tarczf = run 'tar', '-czf', $location, |@manifest, :err, :out;
  $*CWD = $cwd;
  die 'Failed to tar and gzip: ' ~ $tarczf.err.slurp.trim unless $tarczf.exitcode == 0;
  return False unless $location.IO.f;
  True;
}

method ls($file) {
  my $p = run 'tar', '--list', '-f', $file, :out, :err;
  return Failure if $p.exitcode != 0;
  return $p.out.slurp.lines;
}

method cat($dist, $file) {
  my $proc = run 'tar', 'xzOf', $dist.IO.absolute, $file, :out, :err;
  return Failure if $proc.exitcode != 0;
  $proc.out.slurp;
}

method able {
  my @cmd = 'tar', '--help';
  @cmd = ('man', '-c', 'tar') if $*KERNEL.name ~~ m:i/bsd/;
  my $p = run @cmd, :out, :err;
  $p.exitcode == 0 && $p.out.slurp.contains: '-z';
}
