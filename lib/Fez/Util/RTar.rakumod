unit class Fez::Util::RTar;

use Fez::Util::RTar::Tar;
use Fez::Util::RTar::Util;

method cat($dist, $file) {
  my @cmd = 'gzip';
  @cmd.push('-k') if (run 'gzip', '-V', :out).out.slurp.chars;
  my $p = run @cmd, '-c', '-d', $dist, :out, :err;
  return Failure if $p.exitcode != 0;
  my $t = Fez::Util::RTar::Tar.new(file-name => $*TMPDIR.add(time.Str ~ ".tar").absolute,
                                   buffer    => parse-tar($p.out.slurp(:bin)),
                                  );
  return Failure unless $t.ls.grep: * eq $file;
  $t.peek($file).value.decode;
}

method able {
  my @cmd = 'gzip';
  my $p = run @cmd, :out, :err;
  $p.exitcode == 0;
}
