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
  @handlers.push: ::("$h").new;
}
die 'Unable to find a suitable handler for web (tried git and tar), please ensure one is in your path'
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
    $caught = False;
    CATCH { default { .message.say; $caught = True; .resume; } }
    $out = $handler.bundle($location.absolute);
    next if $caught = True;
    return $out;
  }
  die 'All bundlers exhausted, unable to make .tar.gz';
}
