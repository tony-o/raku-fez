unit module Fez::Util::Proc;

use Fez::Logr;

sub run-p(Str:D $name, *@p, *%n) is export {
  log(DEBUG,
      '[%s:starting] %s ...',
      $name,
      @p.elems ?? @p[0] !! '',
     );
  my $proc = Proc::Async.new: |@p;
  my ($rc, $out, $err, $oi, $ei, $ol, $el) = -1, '', '', 0, 0, Lock.new, Lock.new;
  react {
    whenever $proc.stdout.lines -> $l {
      $ol.protect({
        $out = $out ~ $l;
        my @ls = ($out[$oi .. ($out.rindex("\n")//0)]//[]).join('').lines;
        $oi = $out.rindex("\n")//0;
        for @ls {
          log(DEBUG, '[%s:out] %s', $name, $_);
        }
      });
    }
    whenever $proc.stderr.lines -> $l {
      $el.protect({
        $err = $err ~ $l;
        my @ls = ($err[$ei .. ($err.rindex("\n")//0)]//[]).join('').lines;
        $ei = $err.rindex("\n")//0;
        for @ls {
          log(DEBUG, '[%s:err] %s', $name, $_);
        }
      });
    }
    whenever $proc.start {
      $rc = $_.exitcode;
      done;
    }
  }

  [$rc, $out, $err];
}
