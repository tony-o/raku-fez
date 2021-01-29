#!/usr/bin/env raku

use Test;
use Fez::CLI;
plan 1;

ok Fez::CLI::<&MAIN>('checkbuild'), 'fez passes its own checkbuild';
