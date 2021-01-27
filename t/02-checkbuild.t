#!/usr/bin/env raku

use Test;
plan 1;

require ::('Fez::CLI');
ok so ::('Fez::CLI')::<&MAIN>('checkbuild'), 'fez passes its own checkbuild';
