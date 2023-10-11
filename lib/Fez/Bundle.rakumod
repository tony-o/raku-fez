unit module Fez::Bundle;

use Fez::Logr;
use Fez::Util::Json;
use Fez::Util::FS;
use Fez::Util::Glob;

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

die 'Unable to find a suitable handler for bundling (tried pax, and tar), please ensure one is in your path'
  unless @handlers.elems;

constant @ignored-dirs = '.git/*', 'sdist/*', '.github/*';

sub bundle($target, :$dry-run = False) is export {
  my $sdist  = $target.IO.absolute.IO.add('sdist');
  mkdir $sdist.absolute unless $sdist.d;

  my $io = ("a".."z","A".."Z",0..9).flat.roll(8).join ~ '.tar.gz';
  while $sdist.add($io).f {
    $io = ("a".."z","A".."Z",0..9).flat.roll(8).join ~ '.tar.gz';
  }

  my $location = $sdist.add($io);
  
  my $ignorer = '.'.IO.add('.gitignore').IO.f
             ?? parse(|'.'.IO.add('.gitignore').IO.slurp.lines, | @ignored-dirs,
                     :git-ignore)
             !! parse( '.precomp', |@ignored-dirs);
             
  my @manifest = ls('.'.IO, -> $fn {
    $ignorer.rmatch($fn.Str)
  });

  return @manifest if $dry-run;

  mkdir('sdist') unless 'sdist'.IO.d.so;
  
  my ($out, $caught);
  for @handlers -> $handler {
    CATCH { default {
      log(ERROR, "%s\n%s", .message, .backtrace.Str.lines.map({"  $_"}).join("\n"));
      $caught = True;
      .resume;
    } }
    $caught = False;
    $out = $handler.bundle($location.absolute, @manifest);
    next if $caught;
    return $location;
  }
  die 'All bundlers exhausted, unable to make .tar.gz';
}

sub cat($target, $file) is export {
  return Failure unless $target.IO.f;
  @handlers.map({ try $_.cat($target, $file) }).grep(*.defined).first;
}

sub ls-bundle($target) is export {
  return Failure unless $target.IO.f;
  @handlers.map({ $_.ls($target) }).grep(*.defined).first;
}
