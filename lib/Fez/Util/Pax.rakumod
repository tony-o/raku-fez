unit class Fez::Util::Pax;

sub ls($x, $ignore) { $x.IO.dir.grep($ignore).map({ $_.d ?? |ls($_, $ignore) !! $_.resolve.relative }); }

method bundle($location) {
  if !('sdist'.IO.d.so) {
    mkdir 'sdist';
  }
  my $pwd = '.'.IO;
  my @ignores = $pwd.add('.gitignore').IO.f
             ?? $pwd.add('.gitignore').IO.slurp.lines.map({
                  my $regex = $_.split('*').map({$_ eq '' ?? '.*' !! "'$_'"}).join('');
                  rx/ <$regex> /
                })
             !! ();
  my @manifest = ls('.'.IO, -> $fn {
       $fn.basename.substr(0,1) ne '.'
    && !any(@ignores.map({ $fn ~~ $_ })).so
  });
  %*ENV<COPYFILE_DISABLE>='bad_apple_no_cookie_for_you'; #exclude macOS's AppleDouble data files - issue 72
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
  my @cmd = 'man', '-c', 'pax';
  my $p = run @cmd, :out, :err;
  $p.exitcode == 0 && $p.out.slurp ~~ m{<+[\ba..z\s]>+ '-z'};
}
