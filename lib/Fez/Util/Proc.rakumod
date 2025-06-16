unit module Fez::Util::Proc;

use Fez::Logr;

sub run-p(Str:D $name, *@p, *%n) is export {
  log(DEBUG,
      '[%s:starting] %s ...',
      $name,
      @p.elems ?? @p[0] !! '',
     );
  my $proc = Proc::Async.new: |@p;
  my ($rc, $oi, $ei, $ol, $el) = -1, 0, 0, Lock.new, Lock.new;
  my (@err, @out);
  react {
    whenever $proc.stdout.lines -> $l {
      $ol.protect({
        @out.push($l);
        for @out[$oi ..^ +@out] {
          log(DEBUG, '[%s:out] %s', $name, $_);
        }
        $oi = +@out;
      });
    }
    whenever $proc.stderr.lines -> $l {
      $el.protect({
        @err.push($l);
        for @err[$ei ..^ +@err] {
          log(DEBUG, '[%s:err] %s', $name, $_);
        }
        $ei = +@err;
      });
    }
    whenever $proc.start {
      $rc = $_.exitcode;
      done;
    }
  }

  [$rc, @out.join("\n"), @err.join("\n")];
}
