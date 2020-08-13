unit module Fez::Util::Config;

use Fez::Util::Json;

state $CONFIG-PATH = (%*ENV<FEZ_CONFIG>.IO//%?RESOURCES<config.json>).IO;
state $CONFIG      = from-j($CONFIG-PATH.slurp);

sub config is export {
  $CONFIG;
}

sub write-config($out) is export {
  $CONFIG-PATH.IO.spurt(to-j($out));
  $CONFIG = $out;
}
