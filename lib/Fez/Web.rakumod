unit package Fez::Web;

use Fez::Util::Json;
use Fez::Util::Config;

my @handlers = |config-value('requestors');
my $uri      = 'http://localhost:8080'; # config-value('host');

state $handler = do {
  my $handler = @handlers.map({
    my ($h, $handler) = $_;
    try require ::($h.Str);
    if try ::($h.Str) !~~ Failure {
      $handler = ::($h.Str).new;
      $handler = False unless $handler.^can('able')
                           && $handler.able;
    }
    $handler;
  }).grep(*.so).first;
  die 'Unable to find a suitable handler for web (tried '~@handlers.join(', ')~')'
    unless $handler;
  $handler;
};

multi head($endpoint, :%headers = { }) is export {
  $handler.head("{$endpoint.substr(0,4) eq 'http'??''!!$uri}$endpoint", :%headers);
}

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
