unit module Fez::Util::Config;

use Fez::Util::Json;

state $FALLBACK-CONFIG-PATH = (%*ENV<FEZ_FALLBACK_CONFIG>//%?RESOURCES<config.json>).IO;
state %FALLBACK-CONFIG  = from-j($FALLBACK-CONFIG-PATH.slurp);
state $USER-CONFIG-PATH = (
  if $*DISTRO.is-win {
    %*ENV<FEZ_CONFIG> //
    %*ENV<APPDATA>.IO.add('fez').add('fez-config.json')
  }
  elsif run('xdg-user-dir', :out, :err).exitcode == 0 {
    my $xdg-user-dir = run('xdg-user-dir', :out, :err).out.get;
    %*ENV<FEZ_CONFIG> //
    (%*ENV<XDG_CONFIG_HOME>.defined ??
      %*ENV<XDG_CONFIG_HOME> !!
      $xdg-user-dir.IO.add('.config')
    ).IO.add('fez-config.json')
  }
  elsif False {
    # TODO MacOS
  }
  else {
    %*ENV<FEZ_CONFIG> //
    %*ENV<HOME>.IO.add('.fez-config.json')
  }
).IO;
$USER-CONFIG-PATH.spurt(to-j({})) unless $USER-CONFIG-PATH.e;
state %USER-CONFIG = from-j($USER-CONFIG-PATH.slurp);

sub fallback-config is export {
  %FALLBACK-CONFIG;
}

sub user-config is export {
  %USER-CONFIG;
}

sub config-value($name) is export {
    %USER-CONFIG{$name} //
    %FALLBACK-CONFIG{$name};
}

sub write-to-user-config(%values) is export {
  %USER-CONFIG = |%USER-CONFIG, %values;
  $USER-CONFIG-PATH.IO.spurt(to-j(%USER-CONFIG));
}

sub user-config-path is export { $USER-CONFIG-PATH; }
