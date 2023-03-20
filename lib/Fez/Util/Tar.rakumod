unit class Fez::Util::Tar;

use Fez::Util::Glob;
use Fez::Util::FS;
use Fez::Util::Proc;

method bundle($location, :$dry-run) {
  if !('sdist'.IO.d.so) {
    mkdir 'sdist';
  }
  my $pwd = '.'.IO.resolve.basename;
  my $ignorer = '.'.IO.add('.gitignore').IO.f
             ?? parse(|'.'.IO.add('.gitignore').IO.slurp.lines, '.git', '.github', 'sdist/*', :git-ignore)
             !! parse('.git', '.precomp', 'sdist/*');
  my @manifest = ls('.'.IO.absolute, -> $fn { $ignorer.rmatch($fn.relative.Str); })
               .map({$pwd.IO.add($_)});
  return @manifest if $dry-run;
  my ($rc, $out, $err) = run-p('TAR', 'tar', '-czf', $location, |@manifest, :cwd($*CWD.parent));
  die 'Failed to tar and gzip: ' ~ $err unless $rc == 0;
  return False unless $location.IO.f;
  True;
}

method ls($file) {
  my ($rc, $out) = run-p('TAR', 'tar', '--list', '-f', $file);
  return Failure if $rc != 0;
  $out.lines;
}

method cat($dist, $file) {
  my ($rc, $out) = run-p('TAR', 'tar', 'xzOf', $dist.IO.absolute, $file);
  return Failure if $rc != 0;
  $out.lines;
}

method able {
  my @cmd = 'tar', '--help';
  @cmd = ('man', '-c', 'tar') if $*KERNEL.name ~~ m:i/bsd/;
  my ($rc, $out) = run-p('TAR', |@cmd);
  $rc == 0 && $out.contains: '-z';
}
