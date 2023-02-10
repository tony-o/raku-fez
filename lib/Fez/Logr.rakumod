unit module Fez::Logr;

enum LOGLEVEL is export <DEBUG INFO WARN ERROR FATAL MSG>;

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
  my $out = sprintf($msg, |@args).lines.map({(' ' x 11)~$_}).join("\n").trim ~ "\n";

  if $prefix ~~ MSG {
    print ">>= $out";
  } elsif $prefix ~~ DEBUG|INFO {
    print ">>= {$prefix ~~ DEBUG??'DEBUG'!!' INFO'}: $out";
  } else {
    $*ERR.print: "=<< {$prefix ~~ WARN??' WARN'!!$prefix~~ERROR??'ERROR'!!'FATAL'}: $out";
    exit 1 if $prefix ~~ FATAL;
  } 
}

my $tap := $supply.tap: -> $m { s($m<prefix>, $m<msg>, |($m<args>||[])) };

END {
  $LOGR.done;
}
