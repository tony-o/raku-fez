use Test;

use Fez::Util::FS;
use Fez::Util::AST;

plan 1;

if %*ENV<RAKUDO_RAKUAST> {
  # ok 1 , 'for the time being';
  my @us = find-uses('t/d/ast1.raku').sort;
  ok @us eqv ['Fez', 'Fez::API', 'Fez::CLI', 'Fez::Logr', 'Fez::Util::AST'],
     "Expected: ['Fez', 'Fez::API', 'Fez::CLI', 'Fez::Logr', 'Fez::Util::AST'], Got: [{@us.map({"'$_'"}).join(', ')}]";
} else {
  ok True, 'AST not available';
}
