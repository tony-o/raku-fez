unit class Fez::Util::Wget;

use Fez::Util::Proc;

method head($url, :%headers = ()) {
  my @args = ('wget', '-qO-','--spider', '-S', '--tries', '1');
  @args.push('--header', "$_: {%headers{$_}}") for %headers.keys;
  @args.push($url);

  my ($rc, $out, $err) = run-p('WGET', |@args);
  die 'wget error: ' ~ $err.trim if $rc != 0;
  %($_.index(':') ?? |$_.split(':', 2).map(*.trim) !! |($_.trim, True)
    for |$err.lines[1..*].grep(* ne ''));
}

method get($url, :%headers = ()) {
  my @args = ('wget', '-qO-');
  @args.push('--header', "$_: {%headers{$_}}") for %headers.keys;
  @args.push($url);

  my ($rc, $out, $err) = run-p('WGET', |@args);
  die 'wget error: ' ~ $err.trim if $rc != 0;
  $out;
}

method post($url, :$method = 'POST', :$data = '', :$file = '', :%headers = ()) {
  my @args = ('wget', '--method', $method, '-O-');
  @args.push('--body-data', $data) if $data;

  @args.push('--header', "$_: {%headers{$_}}") for %headers.keys;
  if $file {
    @args.push('--header', 'Content-Type: multipart/form-data boundary=FILEUPLOAD');
    @args.push('--body-file', $file);
  }
  @args.push($url);

  my ($rc, $out, $err) = run-p('WGET', |@args);
  die 'wget error: ' ~ $err.trim if $rc != 0;
  $out;
}

method able {
  run-p('WGET', 'wget', '--version')[0] == 0;
}
