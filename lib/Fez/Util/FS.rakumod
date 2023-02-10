unit module Fez::Util::FS;

sub get-files-in-dir(IO() $dir, Callable $chk --> List) is export {
  $dir.dir.map(-> $fd { $fd.f
    ?? ($chk.($fd) ?? $fd.relative !! Failure)
    !! ($fd.d ?? |get-files-in-dir($fd, $chk) !! Failure)
  }).grep(*.defined).List;
}

sub scan-files(@fs, $sub) is export {
  @fs.map({$sub($_.IO.relative, $_.IO.slurp)});
}
