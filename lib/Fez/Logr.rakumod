unit module Fez::Logr;

enum LOGLEVEL is export <DEBUG INFO WARN ERROR FATAL MSG>;
constant ll-prefix = %(DEBUG => 'DEBUG',
                       INFO  => 'INFO',
                       WARN  => 'WARN',
                       ERROR => 'ERROR',
                       FATAL => 'FATAL',
                       MSG   => '',);

state $LOGR     = Supplier.new;
state $LOGLEVEL = INFO;

my $supply = $LOGR.Supply;

sub log(LOGLEVEL:D $prefix, Str:D $msg, *@args) is export {
  return if $LOGLEVEL !~~ DEBUG && $prefix ~~ DEBUG;
  $LOGR.emit({:$prefix, :$msg, :@args});
}

sub set-loglevel(LOGLEVEL:D $ll) is export {
  $LOGR.emit({:prefix(INFO), :msg('setting log level: %s'), :args($ll.gist)});
  $LOGLEVEL = $ll;
}

sub s(LOGLEVEL:D $prefix, Str:D $msg, *@args) {
  my $l     = 0;
  my $extra = ll-prefix{$prefix};
  my $out   = sprintf($msg, |@args).lines.map({($l++ > 0??(' ' x $prefix.chars+$extra.chars+2)!!'')~$_}).join("\n").trim-trailing ~ "\n";

  if $prefix ~~ MSG {
    print ">>= $out";
  } elsif $prefix ~~ DEBUG|INFO {
    print ">>= {$extra}: $out";
  } else {
    $*ERR.print: "=<< {$extra}: $out";
    exit 1 if $prefix ~~ FATAL;
  } 
}

my $tap := $supply.tap: -> $m { s($m<prefix>, $m<msg>, |($m<args>||[])) };

END {
  $LOGR.done;
}
