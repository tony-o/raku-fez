unit module Fez::Util::FS;

sub get-modules-in-dir(IO() $dir --> List) is export {
  $dir.dir.map(-> $fd { $fd.f
    ?? ($fd.basename ~~ m/['.rakumod'|'.pm6']$/ ?? $fd.relative !! Failure)
    !! ($fd.d ?? |get-modules-in-dir($fd) !! Failure)
  }).grep(*.defined).List;
}

sub scan-files(@fs, $sub) is export {
  @fs.map({$sub($_.IO.relative, $_.IO.slurp)});
}
