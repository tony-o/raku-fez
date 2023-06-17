unit module Fez::Util::AST;
use Fez::Logr;

use experimental :rakuast;

class CC {
  role ZZ {
  }
}

set-loglevel(WARN);
sub grep-nodes(@ns, $type, $depth=-1 --> List) {
  log(DEBUG, 'returning, depth==0');
  return if $depth == 0;
  my @as;
  log(DEBUG, 'looking in %d nodes', +@ns);
  for @ns -> $n {
    log(DEBUG, 'inspecting %s', $n.WHAT.^name);
    if $type($n) {
      log(DEBUG, '  adding %s', $n.WHAT.^name);
      @as.push: $n;
    } elsif $n.?statements {
      log(DEBUG, '  found something that can .statements, recursing');
      @as.push: |grep-nodes($n.statements, $type, $depth-1);
    } elsif $n.?expression {
      log(DEBUG, '  found something that can .expression');
      
      @as.push: $n.expression if $type($n.expression);

      if $n.expression.?body.?statement-list.?statements {
        log(DEBUG, '  recursing');
        @as.push: |grep-nodes($n.expression.body.statement-list.statements, $type, $depth-1);
      } elsif $n.expression.?body.?body.?statement-list.?statements {
        log(DEBUG, '  recursing');
        @as.push: |grep-nodes($n.expression.body.body.statement-list.statements, $type, $depth-1);
      }
    }
  }
  @as;
}

sub resolve-names(@ns --> List) {
  my @as;
  log(DEBUG, 'resolving names in %d nodes', +@ns);
  my $unit = '';
  for @ns -> $n {
    if $n.?module-names {
      @as.push: $n.module-names.map(*.canonicalize).join('::');
      log(DEBUG, '  %s -> %s', $n, @as[*-1]);
    } elsif $n.?module-name {
      @as.push: $n.module-name.canonicalize.Str;
      log(DEBUG, '  %s -> %s', $n, @as[*-1]);
    } elsif $n.?name.?parts && $n.name.parts.grep({$_.?name}).elems == $n.name.parts.elems {
      @as.push: $unit ~ $n.name.parts.map(*.name.Str).join('::');
      $unit = @as[*-1] ~ '::' if ($n.?scope//'') eq 'unit' && $n ~~ RakuAST::Package;
      log(DEBUG, ' %s -> %s', $n, @as[*-1]);
    } else {
      log(ERROR, '%s', [$n.^methods].gist);
      log(ERROR, '%s ', $n);
      log(FATAL, 'Cannot resolve name for type: %s', $n.WHAT.^name);
    }
  }
  @as;
}

sub find-uses(IO() $file --> List) is export {
  die "file {$file.absolute} not found or inaccessible"
    unless $file.f;
  my $src = $file.slurp;
  die 'RakuAST not enabled'
    unless Str.^can('AST');
  resolve-names(grep-nodes(
    $src.AST.statements,
    * ~~ (RakuAST::Statement::Require|RakuAST::Statement::Use|RakuAST::Statement::Need),
  ));
}

sub find-mods-n-classes(IO() $file --> List) is export {
  die "file {$file.absolute} not found or inaccessible"
    unless $file.f;
  my $src = $file.slurp;
  die 'RakuAST not enabled'
    unless Str.^can('AST');
  my @us = grep-nodes(
    $src.AST.statements,
    * ~~ (RakuAST::Package),
    1,
  );
  my ($unit, @as, $mod, @parts);
  $unit = '';
  while +@us > 0 {
    $mod = @us.pop;
    next unless $mod.so;
    if $mod ~~ Str && $mod eq 'pop' {
      log(DEBUG, 'popping from parts: %s', @parts.join(', '));
      @parts.pop if +@parts;
      next;
    }
    log(DEBUG, 'looking @ (unit=%s, mod-names=%s, parts=%s, mod-scope=%s)', $unit, resolve-names([$mod]).join('::'), @parts.join(', '), $mod.scope);
    @as.push: |resolve-names([$mod]).map({ +@parts ?? [@parts[*-1], ''].join('::') ~ $_ !! $_ });
    if $mod.scope ne 'unit' {
      @parts.push: @as[*-1];
      @us.push: 'pop';
    } else {
      $unit = @as[*-1];
    }
    @us.push: |grep-nodes(
      $mod.body.body.statement-list.statements,
      * ~~ (RakuAST::Package),
      1,
    );
  }
  |@as.map({ $_ eq $unit ?? $unit !! [$unit, $_].join('::') });
}
