unit class Fez::Util::Pax;

use Fez::Util::Proc;

method bundle($location, @manifest, Bool :$dry-run = False) {
  my ($rc, $out, $err) = run-p('PAX', 'pax', '-w', '-z', '-s', '#^#dist/#', '-f', $location, |@manifest,
                               :ENV(|%*ENV, COPYFILE_DISABLE => 'bad_apple_no_cookie_for_you'),
                              );
  die 'Failed to pax: ' ~ $err unless $rc == 0;
  return False unless $location.IO.f;
  True;
}

method ls($file) {
  my ($rc, $out) = run-p('PAX', 'pax', '-c', '-z', '-f', $file);
  return Failure if $rc != 0;
  $out.lines
}

method cat($dist, $file) {
  my $outfn = (|('0'..'9'), |('a'..'z'), |('A'..'Z')).pick(32).join;
  my ($rc) = run-p('PAX', 'pax', '-z', '-r', '-s', "#.*#$outfn/$outfn#", '-f', $dist.IO.absolute, $file);
  return Failure if $rc != 0;

  my $fl = "$outfn".IO.add($outfn);
  my $f = $fl.slurp;
  $fl.unlink;
  rmdir $outfn;
  $f;
}

method able {
  my @cmd = 'man', 'pax';

  my ($rc, $out) = run-p('PAX', @cmd);
  $rc == 0 && $out ~~ m{<+[\ba..z\s]>+ '-z'};
}
