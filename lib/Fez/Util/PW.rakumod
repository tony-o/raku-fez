unit package Fez::Util::PW;

use NativeCall;
use LibraryMake;

sub libgetpw is export(:libgetpw) {
  state $ = do {
		my $so = get-vars('')<SO>;
		~(%?RESOURCES{"lib/libgetpw$so"}).absolute;
	}
}

class pw is repr('CStruct') {
  has Str    $!password;
  has size_t $!len;
  method password { $!password; }
  method len      { $!len;      }
};

sub getpasswd() is native(&libgetpw) returns pw { * }
sub freepwd(pw) is native(&libgetpw) { * }

sub getpw($p) is export {
  print $p;
  my $in = $*IN;
  my pw $pw = getpasswd();
  $*IN = $in;
  my $x = "{$pw.password.substr(0, $pw.len)}";
  freepw($pw);
  print "\n";
  $x;
}

sub freepw($pwd) is export { freepwd($pwd); }
