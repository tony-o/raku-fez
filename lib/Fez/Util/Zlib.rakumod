unit module Fez::Util::Zlib;

use NativeCall;
use Fez::Logr;

constant zlib = $*DISTRO.is-win ?? %?RESOURCES<lib/z.dll>.absolute !! 'z', v1;

constant z-ok          = 0;
constant z-stream-end  = 1;
constant z-need-dict   = 2;
constant z-errno       = -1;
constant z-stream-err  = -2;
constant z-data-err    = -3;
constant z-mem-err     = -4;
constant z-buf-err     = -5;
constant z-version-err = -6;

sub gzopen(Str, Str --> Pointer) is native(zlib) { * };
sub gzwrite(Pointer, Buf[uint8], int32 --> int32) is native(zlib) { * };
sub gzclose(Pointer --> int32) is native(zlib) { * };
sub gzerror(Pointer, CArray[int32] --> Str) is native(zlib) { * };
sub gzread(Pointer, Buf[uint8], int32 --> int32) is native(zlib) { * };

sub uncompress(Buf[uint8], CArray[ulong], Buf[uint8], ulong --> int32)
  is native(zlib) { * };

sub cmprs(Str:D $fn, $data) is export {
  my Buf[uint8] $out  .= new;
  my ulong $dlen       = $data.bytes;
  $out[$dlen] = 0;

  log(DEBUG, 'zlib: opening %s for writing', $fn);
  my $file = gzopen($fn, 'wb');
  
  my $rc = gzwrite($file, $data, $data.bytes);
  my CArray[int32] $u .= new;
  $u[0] = 0;
  my $err = gzerror($file, $u);
  gzclose($file);

  if $rc == 0 {
    log(FATAL, 'zlib: %s', $err);
  }
}

sub dcmprs(Str:D $fn) is export {
  my Buf[uint8] $in    = $fn.IO.slurp(:bin);
  my Buf[uint8] $out  .= new;
  my Buf[uint8] $read .= new;
  $read[5120] = 0;

  log(DEBUG, 'zlib: opening %s for reading', $fn);
  my $file = gzopen($fn, 'rb');
  
  my $rc = gzread($file, $read, 5120);
  while $rc == 5120 {
    $out.push($read.subbuf(0, $rc));
    $rc = gzread($file, $read, 5120);
  }
  my CArray[int32] $u .= new;
  $u[0] = 0;
  my $err = gzerror($file, $u);
  gzclose($file);
  
  if $rc == -1 {
    log(ERROR, 'zlib: %s', $err);
    die;
  }
  $out.push($read.subbuf(0, $rc));
  $out;
}
