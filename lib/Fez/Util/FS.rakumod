unit module Fez::Util::FS;

sub scan-files(@fs, $sub) is export {
  @fs.map({$sub($_.IO.relative, $_.IO.slurp)});
}

sub ls($x, $ignore) is export {
  $x.IO.dir.grep($ignore).map({
    $_.d
    ?? $_.dir.elems ?? |ls($_, $ignore) !! $_.resolve.relative
    !! $_.resolve.relative }); }
