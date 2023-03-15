unit class Fez::Util::Tar;

use Fez::Util::Glob;
use Fez::Util::FS;

method bundle($location, :$dry-run) {
  if !('sdist'.IO.d.so) {
    mkdir 'sdist';
  }
  my $cwd = $*CWD.resolve;
  my $pwd = '.'.IO.resolve.basename;
  my $ignorer = '.'.IO.add('.gitignore').IO.f
             ?? parse(|'.'.IO.add('.gitignore').IO.slurp.lines, '.git', '.github', 'sdist/*', :git-ignore)
             !! parse('.git', '.precomp', 'sdist/*');
  my @manifest = ls('.'.IO.absolute, -> $fn { $ignorer.rmatch($fn.relative.Str); })
               .map({$pwd.IO.add($_)});
  return @manifest if $dry-run;
  $*CWD = $cwd.add('..').resolve;
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
