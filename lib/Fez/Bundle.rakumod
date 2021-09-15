unit module Fez::Bundle;

use Fez::Util::Json;

my $CONFIG = from-j(%?RESOURCES<config.json>.IO.slurp);
my @chandlers = |$CONFIG<bundlers>; 

my @handlers;
for @chandlers -> $h {
  my $caught = False;
  CATCH { $caught = True; .resume; }
  require ::("$h");
  next if $caught;
  next unless ::("$h").able;
  next unless ::("$h").^can('bundle');
  @handlers.push: ::("$h").new;
}
die 'Unable to find a suitable handler for bundling (tried git and tar), please ensure one is in your path'
  unless @handlers.elems;

sub bundle($target) is export {
  my $sdist  = $target.IO.absolute.IO.add('sdist');
  mkdir $sdist.absolute unless $sdist.d;

  my $io = ("a".."z","A".."Z",0..9).flat.roll(8).join ~ '.tar.gz';
  while $sdist.add($io).f {
    $io = ("a".."z","A".."Z",0..9).flat.roll(8).join ~ '.tar.gz';
  }

  my $location = $sdist.add($io);
  
  my ($out, $caught);
  for @handlers -> $handler {
    CATCH { default { $*IN.print('=<< ' ~ .message ~ "\n"); $caught = True; .resume; } }
    $caught = False;
    $out = $handler.bundle($location.absolute);
    next if $caught;
    return $location;
  }
  die 'All bundlers exhausted, unable to make .tar.gz';
}

sub cat($target, $file) is export {
  return Failure unless $target.IO.f;
  @handlers.map({ try $_.cat($target, $file) }).grep(*.defined).first;
}

sub ls($target) is export {
  return Failure unless $target.IO.f;
  @handlers.map({ try $_.ls($target) }).grep(*.defined).first;
}
