unit module Fez::Util::Zlib;

use NativeCall;

constant zlib = $*DISTRO.is-win ?? %?RESOURCES<lib/z.dll>.absolute !! ['z', v1];

constant z-ok          = 0;
constant z-stream-end  = 1;
constant z-need-dict   = 2;
constant z-errno       = -1;
constant z-stream-err  = -2;
constant z-data-err    = -3;
constant z-mem-err     = -4;
constant z-buf-err     = -5;
constant z-version-err = -6;

sub compress-bound(ulong --> ulong)
  is native(|zlib) is symbol('compressBound') { * };
sub uncompress2(Buf[uint8], CArray[ulong], Buf[uint8], CArray[ulong] --> int32)
  is native(|zlib) { * };
sub compress2(Buf[uint8], CArray[ulong], Buf[uint8], ulong, int32 --> int32)
  is native(|zlib) { * };

sub cmprs(Str:D $fn, $data) is export {
  my Buf[uint8] $out  .= new;
  my ulong $dlen       = compress-bound($data.bytes);
  $out[$dlen] = 0;

  my $rc = compress2($out, CArray[ulong].new($dlen), $data, $data.bytes, 9);

  die "Failed to compress {$rc}" unless $rc == z-ok;

  $fn.IO.spurt($out, :bin);
}

sub dcmprs(Str:D $fn) is export {
  my Buf[uint8]    $in    = $fn.IO.slurp(:bin);
  my Buf[uint8]    $out  .= new;
  my CArray[ulong] $inl  .= new;
  my ulong         $dlen  = 1024; # double until !buf-err && !ok
  my $rc = z-buf-err;
  
  $inl[0] = $in.bytes;

  while $rc ~~ z-buf-err {
    $out[$dlen] = 0;
    $rc = uncompress2($out, CArray[ulong].new($dlen), $in, CArray[ulong].new($inl)); 
    $dlen += $dlen if $rc != z-ok;
  }

  die "Failed to decompress {$rc}" unless $rc == z-ok;

  my $blen = $out.bytes-1;
  while $blen > 0 && $out[$blen-1] == 0x0 {
    $blen--;
  }

  $out.subbuf(0, $blen);
}
