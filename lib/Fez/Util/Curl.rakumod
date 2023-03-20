unit class Fez::Util::Curl;

use Fez::Util::Proc;

method head($url, :%headers = ()) {
  my @args = ('curl', '-I');
  @args.push("-H", "$_: {%headers{$_}}") for %headers.keys;
  @args.push($url);

  my ($rc, $out, $err) = run-p('CURL', |@args);
  die 'curl error: ' ~ $err.trim if $rc != 0;
  %($_.index(':') ?? |$_.split(':', 2).map(*.trim) !! |($_.trim, True)
    for |$out.lines[1..*].grep(* ne ''));
}

method get($url, :%headers = ()) {
  my @args = ('curl');
  @args.push("-H", "$_: {%headers{$_}}") for %headers.keys;
  @args.push($url);

  my ($rc, $out, $err) = run-p('CURL', |@args);
  dd [0, |run-p('CURL', |@args)];
  die 'curl error: ' ~ $err.trim if $rc != 0;
  $out;
}

method post($url, :$method = 'POST', :$data = '', :$file = '', :%headers = ()) {
  my @args = ('curl', '-X', $method);
  @args.push('-d', $data) if $data;
  @args.push('-T', $file) if $file;
  @args.push("-H", "$_: {%headers{$_}}") for %headers.keys;
  @args.push($url);

  my ($rc, $out, $err) = run-p('CURL', |@args);
  die 'curl error: ' ~ $err.trim if $rc != 0;
  $out;
}

method able {
  run-p('CURL', 'curl', '--version')[0] == 0;
}
