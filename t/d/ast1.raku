need Fez::CLI;

use Fez::API;

require ::('Fez::Util::AST');

require Fez::Logr;

sub XXX($ignore) {
  say 'hi';
  use ::('Fez');
  dd 'x';
  # this does not yet work.
  # use Fez::("$ignore");
}
