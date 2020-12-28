unit module Fez::Util::Pass;
use NativeCall;

my $getpass;
if $*DISTRO.is-win {
  sub _getch() returns uint8 is native('msvcrt') {}
  $getpass = sub {
    my ($s, $c);
    while True {
      $c = _getch();
      last if $c ~~ any(10, 13);
      $s ~= $c;
    }
    $s;
  };
} else {
  $getpass = sub {
    my $p = run 'stty', '-g', :out, :err;
    if $p.exitcode != 0 {
      printf('=<< stty not found.  please submit a bug report at https://github.com/tony-o/raku-fez');
      exit(255);
    }
    my $opt = $p.out.get;
    run 'stty', '-echo';
    my $c = get;
    run 'stty', $opt;
    print "\n";
    $c;
  };
}

multi sub getpass(--> Str) is export {
  $getpass();
}

multi sub getpass(Str:D $p --> Str) is export {
  print $p;
  getpass();
}
