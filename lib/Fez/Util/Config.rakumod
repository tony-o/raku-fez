unit module Fez::Util::Config;

use Fez::Util::Json;

state $ENV-CONFIG-PATH = (%*ENV<FEZ_CONFIG>//%?RESOURCES<config.json>).IO;
state $USER-CONFIG-PATH = (
  if $*DISTRO.is-win {
    %*ENV<FEZ_CONFIG> //
    %*ENV<APPDATA>.IO.add('fez').add('fez-config.json')
  } else {
    %*ENV<FEZ_CONFIG> //
    %*ENV<HOME>.IO.add('.fez-config.json')
  }
).IO;
$USER-CONFIG-PATH.parent.mkdir unless $USER-CONFIG-PATH.parent.d;
$USER-CONFIG-PATH.spurt(to-j({})) unless $USER-CONFIG-PATH.e;
state %USER-CONFIG;
state %ENV-CONFIG;

sub user-config is export {
  %USER-CONFIG;
}

sub env-config is export {
  %ENV-CONFIG;
}

sub config-value($name) is export {
    %USER-CONFIG{$name} //
    %ENV-CONFIG{$name};
}

sub write-to-user-config(%values) is export {
  %USER-CONFIG = |%USER-CONFIG, %values;
  $USER-CONFIG-PATH.IO.spurt(to-j(%USER-CONFIG));
}

sub user-config-path is export { $USER-CONFIG-PATH; }
sub env-config-path is export { $ENV-CONFIG-PATH; }

sub reload-config is export {
  %ENV-CONFIG  = from-j($ENV-CONFIG-PATH.slurp);
  %USER-CONFIG = from-j($USER-CONFIG-PATH.slurp);
}

sub current-prefix is export {
  config-value('ecosystems').first({ $_.value eq config-value('host') }).key ~ ':';
}

reload-config;
