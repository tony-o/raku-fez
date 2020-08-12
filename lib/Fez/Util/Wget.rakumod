unit class Fez::Util::Wget;

method get($url, :%headers = ()) {
  my @args = ('wget', '-qO-');
  @args.push('--header', "$_: {%headers{$_}}") for %headers.keys;
  @args.push($url);

  run(|@args, :out, :err).out.slurp;
}

method post($url, :$method = 'POST', :$data = '', :$file = '', :%headers = ()) {
  my @args = ('wget', '--method', $method, '-qO-');
  @args.push('--body-data', $data) if $data;
  @args.push('--body-file', $file) if $file;

  @args.push('--header', "$_: {%headers{$_}}") for %headers.keys;
  @args.push($url);

  my $proc = run(|@args, :out, :err);
  run(|@args, :out, :err).out.slurp;
}

method able {
  (run 'which', 'wget', :out, :err).out.slurp ne '';
}
