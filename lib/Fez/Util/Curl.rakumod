unit class Fez::Util::Curl;

method get($url, :%headers = ()) {
  my @args = ('curl');
  @args.push("-H", "$_: {%headers{$_}}") for %headers.keys;
  @args.push($url);

  run(|@args, :out, :err).out.slurp;
}

method post($url, :$method = 'POST', :$data = '', :$file = '', :%headers = ()) {
  my @args = ('curl', '-X', $method);
  @args.push('-d', $data) if $data;
  @args.push('-T', $file) if $file;
  @args.push("-H", "$_: {%headers{$_}}") for %headers.keys;
  @args.push($url);

  run(|@args, :out, :err).out.slurp;
}

method able {
  (run 'which', 'curl', :out, :err).out.slurp ne '';
}
