unit class Fez::Util::Curl;

method get($url, :%headers = ()) {
  my @args = ('curl');
  @args.push("-H", "$_: {%headers{$_}}") for %headers.keys;
  @args.push($url);

  my $proc = run(|@args, :out, :err);
  die 'curl error: ' ~ $proc.err.slurp.trim if $proc.exitcode != 0;
  $proc.out.slurp;
}

method post($url, :$method = 'POST', :$data = '', :$file = '', :%headers = ()) {
  my @args = ('curl', '-X', $method);
  @args.push('-d', $data) if $data;
  @args.push('-T', $file) if $file;
  @args.push("-H", "$_: {%headers{$_}}") for %headers.keys;
  @args.push($url);

  my $proc = run(|@args, :out, :err);
  die 'curl error: ' ~ $proc.err.slurp.trim if $proc.exitcode != 0;
  $proc.out.slurp;
}

method able {
  (run 'curl', '--version', :out, :err).exitcode == 0;
}
