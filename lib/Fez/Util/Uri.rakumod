unit module Fez::Util::Uri;

multi sub pct-encode(Str:D $s) is export { $s.encode.decode("utf8").comb.map({ $_ ~~ m/^<[a..zA..Z0..9\-_.~]>$/ ?? $_ !! sprintf('%%%X', .ord) }).join; }
multi sub pct-encode(%xs) is export {
  my $s = '';
  for %xs.keys -> $k {
    $s ~= '&' ~ pct-encode($k) ~ '=' ~ pct-encode(%xs{$k});
  }
  $s.substr(1);
}
