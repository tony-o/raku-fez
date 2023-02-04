unit module Fez::Logr;

enum LOGLEVEL is export <DEBUG INFO WARN ERROR FATAL MSG>;

state $LOGR     = Supplier.new;
state $LOGLEVEL = ERROR;

my $supply = $LOGR.Supply;

sub log(LOGLEVEL:D $prefix, Str:D $msg, *@args) is export {
  $LOGR.emit({:$prefix, :$msg, :@args});
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
