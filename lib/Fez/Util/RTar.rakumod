unit module Fez::Util::RTar;

sub tar(*@fs, Str :$prefix = '' --> Buf[uint8]) is export {
  my Buf[uint8] $tar .=new;
  my $pax-header-cnt = 0;
  for @fs -> IO() $f {
    die "{$f.relative} does not exist" unless $f.e || $f.l;

    #setup
    my $force-pax = try { ($prefix ~ $f.relative ~ ($f.d ??'/'!!'')).encode('ascii') } ?? False !! True;
    my $filename = ($prefix ~ $f.relative ~ ($f.d ??'/'!!'')).encode('ascii', :replacement<->);
    my $bytes = $f.slurp(:bin) if !$f.d && !$f.l;
    my Buf[uint8] $tarf .=new;
    my Buf[uint8] $paxf .=new;

    #filename
    $tarf.push($filename.elems > 100 ?? ($f.d ?? "{$f.basename}/" !! $f.basename).encode('ascii', :replacement<->).subbuf(0,99) !! $filename.subbuf(0,100));
    $tarf.push(0) while $tarf.elems % 100 != 0;

    #filemode
    $tarf.push(sprintf("%07o\0", $f.mode//0o600).encode('ascii'));

    #ownerid
    $tarf.push(sprintf("%07o\0", $f.user//1000).encode('ascii'));

    #groupid
    $tarf.push(sprintf("%07o\0", $f.group//1000).encode('ascii'));

    #filesize
    die if $bytes.elems > 0o77777777777;
    $tarf.push(sprintf("%011o\0", $f.d ?? 0 !! $bytes.elems).encode('ascii'));

    #mtime
    $tarf.push(sprintf("%09o\0", $f.modified//DateTime.now.posix).encode('ascii'));

    #checksum
    $tarf.push('        '.encode('ascii'));

    #type flag
    $tarf.push(($force-pax ?? 'x' !! $f.l ?? '2' !! $f.f ?? '0' !! '5').encode('ascii'));

    if $f.l {
      $force-pax ||= ( try { $f.resolve.encode('ascii') } ?? False !! $f.resolve.relative.Str.chars > 100 );
      warn "$f is a missing link" if $f.resolve.absolute eq $f.absolute;
      $tarf.push($f.resolve.relative.encode('ascii', :replacement<->).subbuf(0,100))
    }

    $tarf.push(0) while $tarf.elems % 256 != 0;

    #ustar hdr
    $tarf.push("\0ustar  \0".encode('ascii'));

    #owner name
    $tarf.push("raku\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0".encode('ascii'));

    #group name
    $tarf.push("raku\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0".encode('ascii'));

    #device major
    $tarf.push("\0\0\0\0\0\0\0\0".encode('ascii'));

    #device minor
    $tarf.push("\0\0\0\0\0\0\0\0".encode('ascii'));

    $tarf.push(0) while $tarf.elems % 512 != 0;

    $tarf.splice: 148, 8, (sprintf("%06o\0 ", ([+] |$tarf.subbuf(*-512))).encode('ascii'));

    if $filename.elems > 100 || $force-pax {
      # write meta header
      my $paxnm = "PaxHeader/{$f.basename}".encode('ascii', :replacement<->).subbuf(0,98);
      my $paxpath = $f.relative.encode('utf8');
      my $fpath = sprintf("%s path=%s\n", $paxpath.elems + $paxpath.elems.Str.chars + 8, $f.relative).encode('utf8');

      my $linkpath = $f.resolve.absolute.encode('utf8');
      $fpath ~= sprintf("%s linkpath=%s\n", $linkpath.elems + $linkpath.elems.Str.chars + 12, $f.resolve.absolute).encode('utf8')
        if $f.l;

      $paxf.push($tarf);
      # fix filename
      $paxf.splice: 0, $paxnm.elems, $paxnm;
      $paxf[$_] = 0 for $paxnm.elems..^100;
      # fix file type
      $paxf.splice: 156, 1, 'x'.encode('ascii');

      # fix record size
      $paxf.splice: 124, 12, sprintf("%011o ", $fpath.elems).encode('ascii');

      # prepare checksum
      #$paxf.splice: 148, 8, '        '.encode('ascii');
      #$paxf.splice: 148, 8, (sprintf("%06o\0 ", ([+] $paxf.subbuf(0,512))).encode('ascii'));
      #$paxf.splice: 148, 8, (sprintf("011431\0 "));

      $paxf.push($fpath);
      $paxf.push(0) while $paxf.elems % 512 != 0;
    }


    $tarf.push($bytes.elems ?? $bytes !! 0) if $bytes;
    $tarf.push(0) while $tarf.elems % 512 != 0;

    $tar.push($paxf);
    $tar.push($tarf);
  }

  $tar.push(0) for 0..^1024;

  $tar;
}

class IO::Tar does IO {
  has $!size;
  has $!file-type;
  has $!offset;
  has $!filename;
  has $!input-file;
  has %!pax-header;
  has $!to;
  has $!data;

  submethod BUILD(
    :$!offset,
    :$!input-file,
    :$!filename where * ne '',
    :$!file-type,
    :$!size = 0,
    :$!to = '',
    :$!data = Buf[uint8].new,
    :%!pax-header = {}) {
  }

  method name(--> Str)     { (%!pax-header<path>//$!filename); }
  method basename(--> Str) { (%!pax-header<path>//$!filename).IO.basename; };

  method d(--> Bool) { $!file-type eq '5'; }
  method l(--> Bool) { $!file-type eq '2'; }
  method f(--> Bool) { $!file-type eq '0'; }

  method to(--> Str)     { $!to;     }
  method size(--> Int)   { $!size;   }
  method offset(--> Int) { $!offset; }

  method slurp(Bool:D :$binary = False) { $binary ?? $!data !! $!data.decode }
}

multi sub tar-ls(IO() $input-file --> List) is export {
  die "{$input-file} does not exist" unless $input-file.f;
  tar-ls($input-file.relative, $input-file.slurp(:bin));
}

multi sub tar-ls(IO() $input-file, Buf[uint8] $bs --> List) is export {
  my $offset        = 0;
  my $len           = $bs.elems - 1024;
  my $trailer       = 0;
  my %pax-header;

  my @fs;

  while $offset < $len {
    my $filename  = S/\0+$// given $bs.subbuf($offset, 100).decode('ascii');
    my $size      = "0o{$bs.subbuf($offset + 124, 11).decode('ascii')}".Int;
    my $file-type = $bs.subbuf($offset + 156, 1).decode('ascii');

    if $filename eq '' && $size ~~ -1 {
      $trailer++;
      last if $trailer >= 2;
      $offset += 512;
      next;
    }

    if $file-type eq 'x' { #pax header
      %pax-header = ();
      $offset += 512;
      my $to-decode = $bs.subbuf($offset, $size);
      my $decode-i = 0;
      my $decode-j = 0;
      my $decode-l = $to-decode.elems;
      while $decode-i < $decode-l {
        while $to-decode[$decode-j] ne ' ' {
          $decode-j++;
        }
        $decode-j++;
        my $blob-size = $to-decode.slice($decode-i, $decode-j).Int;
        my $blob = $to-decode.subbuf($decode-j, $blob-size);
        $decode-i = $decode-j + $blob-size;
      }
      $offset += $size;
      $offset  = ceiling($offset / 512) * 512;
    } elsif $file-type ~~ '0'|"\0" { #regular file
      $offset += 512;
      @fs.push(IO::Tar.new(
        :$input-file,
        :$offset,
        :$filename,
        :$size,
        :$file-type,
        :%pax-header,
        :data($bs.subbuf($offset, $size)),
      ));
      $offset = ceiling(($size+$offset) / 512) * 512;
      %pax-header = ();
    } elsif $file-type eq '5' { #dir
      @fs.push(IO::Tar.new(
        :$input-file,
        :$offset,
        :$filename,
        :size(0),
        :$file-type,
        :%pax-header,
        :data($bs.subbuf($offset, $size)),
      ));
      $offset += 512;
      %pax-header = ();
    } elsif $file-type eq '2' { #link
      $offset += 512;
      my $to = $bs.subbuf($offset, $size);
      @fs.push(IO::Tar.new(
        :$input-file,
        :$offset,
        :$filename,
        :$size,
        :$file-type,
        :$to,
        :%pax-header,
        :data($bs.subbuf($offset, $size)),
      ));
      $offset = ceiling(($size+$offset) / 512) * 512;
      %pax-header = ();
    } else {
      die $file-type;
    }
    $offset = ceiling($offset/512) * 512;
  }
  @fs;
}

sub tar-cat(Str:D $input-file, Str:D $path, Bool:D :$binary = False) is export {
  tar-ls($input-file).grep(*.name eq $path).first.slurp(:$binary);
}

sub extract(Str:D $input-file, Str:D $output-path) is export {
  tar-ls($input-file).map({ $output-path.IO.add($_).spurt(tar-cat($input-file, $_, :binary), :binary) });
}
