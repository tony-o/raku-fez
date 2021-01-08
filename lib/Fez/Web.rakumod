unit package Fez::Web;

use Fez::Util::Json;
use Fez::Util::Config;

my @handlers = |config-value('requestors');
my $uri      = config-value('host');

my $handler = False;
for @handlers -> $h {
  my $caught = False;
  CATCH { $caught = True; .resume; }
  require ::("$h");
  next if $caught;
  next unless ::("$h").able;
  $handler = ::("$h").new;
}
die 'Unable to find a suitable handler for web (tried '~@handlers.join(', ')~')'
  unless $handler;

multi get($endpoint, :%headers = { }) is export {
  my $out = $handler.get("{$endpoint.substr(0,4) eq 'http'??''!!$uri}$endpoint", :%headers);
  try {
    CATCH { default { $out; } }
    from-j($out);
  };
}
multi post($endpoint, :$method = 'POST', :$data = '', :$file = '', :%headers) is export {
  my $out = $handler.post("{$endpoint.substr(0,4) eq 'http'??''!!$uri}$endpoint", :$method, :data($data ?? to-j($data) !! ''), :$file, :%headers);
  try {
    CATCH { default { $out; } }
    from-j($out);
  };
}
