#!/usr/bin/env raku

use Test;
sub from-j($t) { ::("Rakudo::Internals::JSON").from-json($t); }

plan 1;

ok from-j('resources/config.json'.IO.slurp), 'config parses OK';
