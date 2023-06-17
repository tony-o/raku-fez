use Test;

use Fez::Util::FS;
use Fez::Util::AST;

plan 1;

if %*ENV<RAKUDO_RAKUAST> {
  my @tfiles = ls('lib', *.so).grep(*.ends-with('rakumod'));
  @tfiles = 't/d/ast2.raku';
  my @us = @tfiles.map(-> $t {
      |find-mods-n-classes($t);
    }).sort;
  ok @us eqv ['fEZ::wEB', 'fEZ::wEB::AA::BB', 'fEZ::wEB::AA::BB::CC', 'fEZ::wEB::BB::CC'],
     "Expected: ['fEZ::wEB', 'fEZ::wEB::AA::BB', 'fEZ::wEB::AA::BB::CC', 'fEZ::wEB::BB::CC'], Got: [{@us.map({"'$_'"}).join(', ')}]";
} else {
  ok True, 'AST not available';
}
