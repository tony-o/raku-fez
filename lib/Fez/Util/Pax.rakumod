unit class Fez::Util::Pax;

use Fez::Util::Glob;

sub ls($x, $ignore) { $x.IO.dir.grep($ignore).map({ $_.d ?? |ls($_, $ignore) !! $_.resolve.relative }); }

method bundle($location) {
  if !('sdist'.IO.d.so) {
    mkdir 'sdist';
  }
  my $ignorer = '.'.IO.add('.gitignore').IO.f
             ?? parse(|'.'.IO.add('.gitignore').IO.slurp.lines, '.git/*', 'sdist/*')
             !! parse('.git/*', '.precomp', 'sdist/*');
  my @manifest = ls('.'.IO, -> $fn {
    $ignorer.rmatch($fn.Str)
  });
  my $tarczf = run 'pax', '-w', '-z', '-s', '#^#dist/#', '-f', $location, |@manifest, :err, :out;
  die 'Failed to pax: ' ~ $tarczf.err.slurp.trim unless $tarczf.exitcode == 0;
  return False unless $location.IO.f;
  True;
}

method ls($file) {
  my $p = run 'pax', '-c', '-z', '-f', $file, :out, :err;
  return Failure if $p.exitcode != 0;
  $p.out.lines
}

method cat($dist, $file) {
  my $outfn = (|('0'..'9'), |('a'..'z'), |('A'..'Z')).pick(32).join;
  my $proc = run 'pax', '-z', '-r', '-s', "#.*#$outfn/$outfn#", '-f', $dist.IO.absolute, $file, :out, :err;
  return Failure if $proc.exitcode != 0;

  my $fl = "$outfn".IO.add($outfn);
  my $f = $fl.slurp;
  $fl.unlink;
  rmdir $outfn;
  $f;
}

method able {
  my @cmd = 'man', 'pax';
  my $p = run @cmd, :out, :err;
  $p.exitcode == 0 && $p.out.slurp ~~ m{<+[\ba..z\s]>+ '-z'};
}
