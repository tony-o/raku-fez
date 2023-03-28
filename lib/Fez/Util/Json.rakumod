unit package Fez::Util::Json;

sub to-j($t)   is export { ::("Rakudo::Internals::JSON").to-json($t, :pretty, :sorted-keys);   }
sub from-j($t) is export { ::("Rakudo::Internals::JSON").from-json($t); }
