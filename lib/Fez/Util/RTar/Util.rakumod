unit module Fez::Util::RTar::Util;
use nqp;

our $record-size is export = 512;

sub pax-pack($name, $value) {
  sprintf("%d %s=%s\n", "$name=$value\n".chars+4, $name, $value).ords;
}
my @headers =
  { :offset(0),   :len(100), :name<name>,      :rx-pad(0), :pax<path>, },
  { :offset(100), :len(8),   :name<mode>,      :lx-pad(0),  },
  { :offset(108), :len(8),   :name<uid>,       :lx-pad(0),  },
  { :offset(116), :len(8),   :name<gid>,       :lx-pad(0),  },
  { :offset(124), :len(12),  :name<size>,      :lx-pad(0),  },
  { :offset(136), :len(12),  :name<modified>,  :lx-pad(0),  },
  { :offset(148), :len(8),   :name<checksum>,  :default(Buf.allocate(8)), },
  { :offset(156), :len(1),   :name<type-flag>, },
  { :offset(157), :len(100), :name<link-name>, :lx-pad(0), :default(Buf.allocate(100, 0)), },
  { :offset(257), :len(8),   :name<ustar>,     :default(Buf.new("ustar{"\0"}00".ords)), },
  { :offset(265), :len(32),  :name<uname>,     :default(Buf.new('unknown'.ords, BEGIN 0 xx 25)), },
  { :offset(297), :len(32),  :name<gname>,     :default(Buf.new('unknown'.ords, BEGIN 0 xx 25)), },
  { :offset(329), :len(8),   :name<major>,     :default(Buf.new("000000 \0".ords)), },
  { :offset(337), :len(8),   :name<minor>,     :default(Buf.new("000000 \0".ords)),},
  { :offset(345), :len(155), :name<prefix>,    :default(Buf.allocate(155)),  },
;

sub form-header(IO() $file) is export {
  my (@x, $r);
  my @values =
    ($file.relative ~ ($file ~~ :d ?? '/' !! '')).Str.encode('utf8'), #name
    ($file.mode.Str ~ " \0").encode('utf8'), #mode
    (nqp::stat($file.absolute, 10).base(8) ~ " \0").encode('utf8'), #uid
    (nqp::stat($file.absolute, 11).base(8) ~ " \0").encode('utf8'), #gid
    ($file.s.base(8).Str ~ ' ').encode('utf8'), #size
    ($file.modified.DateTime.posix.base(8).Str ~ ' ').encode('utf8'), #modified
    Nil, #checksum
    ((nqp::stat($file.absolute, 12) ?? 1 !! $file~~:d ?? 5 !! 0).Str).encode('utf8'), #type-flag
    Nil, #link-name
    Nil, #ustar
    Nil, #uname
    Nil, #gname
    Nil, #major
    Nil, #minor
    Nil, #$file.dirname, #prefix
  ;
  #todo needs to handle paths > 512 bytes
  my ($pax, $val);
  for 0..^@values.elems {
#pack headers
    $val = @values[$_];
    if $_ == 0 {
      $pax = Nil;
      if $val.elems > 100 {
        #pax
        $pax = ('PaxHeader/' ~ ($file.basename.substr(0, $file.basename.chars > 88 ?? 88 !! $val.elems))).encode('utf8');
# TODO pax-pack should take the buf and use .elems rather than .chars
        $pax .=new($pax.values.Slip, Buf.allocate(@headers[$_]<len> - $pax.elems, @headers[$_]<rx-pad>).Slip) if Any !~~ $val && @headers[$_]<rx-pad>.defined;
        @x.push($_) for [Buf.new($pax.values), Buf.new(pax-pack(@headers[$_]<pax>, @values[$_].decode('utf8'))), Buf.new($pax.values)];
        next;
      } else {
        @x.push: Buf.new;
      }
    }
    $val .=new(Buf.allocate(@headers[$_]<len> - $val.elems, @headers[$_]<lx-pad>).Slip, $val.values.Slip) if Any !~~ $val && @headers[$_]<lx-pad>.defined;
    $val .=new($val.values.Slip, Buf.allocate(@headers[$_]<len> - $val.elems, @headers[$_]<rx-pad>).Slip) if Any !~~ $val && @headers[$_]<rx-pad>.defined;

    @x[0].push(Buf.new('x'.ord))
      if @headers[$_]<name> eq 'type-flag' && @x.elems == 3;
    @x[0].push: Buf.new(Buf.allocate(11 - @x[1].elems.base(8).Str.chars, '0'.ord).values, (@x[1].elems.base(8) ~ ' ').ords)
      if @x.elems == 3 && @headers[$_]<name> eq 'size';

    @x[0].push: Any ~~ $val ?? @headers[$_]<default> !! $val
      unless @x.elems == 3 && @headers[$_]<name> eq ('size'|'type-flag');
    @x[2].push: Any ~~ $val ?? @headers[$_]<default> !! $val
      if @x.elems == 3;;
  }
  #checksums - there is a more efficient way above.
  my $cs;
  for 0..@x.elems -> $xidx {
    next unless $xidx % 2 == 0;
    $cs = 0;
    for 0..^@x[$xidx].elems -> $idx {
      $cs = ($cs + @x[$xidx][$idx]) % 262144;
    }
    $cs = $cs.base(8).Str ~ "\0 ";
    @x[$xidx].subbuf-rw(148, 8) = Buf.new(Buf.allocate(8 - $cs.chars, '0'.ord).values, $cs.ords.Slip);
  }
  #fill out to 512 size blocks
  $r = Buf.new;
  for 0..^@x.elems {
    @x[$_].push: Buf.allocate($record-size - (@x[$_].elems % $record-size))
      if @x[$_].elems % 512 != 0;

    $r.push(@x[$_]);
  }
  $r;
}

sub dump-buf(Buf $b) is export {
  my $i = 0;
  my $append;
  while ($i < $b.elems) {
    printf '%010d  |%08x  ', $i, $i;
    for ($i..^$i+16) {
      FIRST { $append = ''; };
      printf '%02x ', $b[$_];
      print ' ' if so ($_+1) %% 8 && !so ($_+1) %% 16;
      $append ~= try { die unless $b[$_] ne any(0, 10, 13); $b[$_].chr } // '.';
      LAST { $i += 16; print "|$append|\n"};
    };
  }
  print "\n";
}

sub read-existing-tar(IO() $file) is export { #expects a tar file
  my $buffer = $file.slurp :bin;
  parse-tar($buffer);
}

sub parse-tar(Buf $buffer) is export {
  my $cursor = 0;
  my Buf $f;
  my ($multi, $x-p);
  my ($fname, $fsize, $ftype) = (Nil, 0, '');
  my $files = 0;
  my @fs;
  my %idx =
    t => @headers.grep(*<name> eq 'type-flag')[0],
    n => @headers.grep(*<name> eq 'name')[0],
    s => @headers.grep(*<name> eq 'size')[0],
  ;
  while $cursor < ($buffer.elems - ($record-size * 2)) {
    #get header -
    $f.=new unless $ftype eq 'x';
    $f.push($buffer.subbuf($cursor, $record-size));
    $fname   = $f.subbuf(%idx<n><offset>, %idx<n><len>).decode('utf8').subst(/"\0"/,'',:g)
      unless $ftype eq 'x';
    $fsize   = :8($f.subbuf(($ftype eq 'x' ?? *-$record-size+%idx<s><offset> !! %idx<s><offset>), %idx<s><len>).decode('utf8').subst(/"\0"|' '/,'',:g))//0;
    $ftype   = $f.subbuf(($ftype eq 'x' ?? *-$record-size+%idx<t><offset> !! %idx<t><offset>), %idx<t><len>).decode('utf8').subst(/"\0"/,'',:g);
    $cursor += $record-size;
    if $ftype eq ('x') {
      $f.push($buffer.subbuf($cursor, $fsize));
      $x-p     = $buffer.subbuf($cursor, $fsize).decode('utf8');
      $cursor += $fsize + ($fsize % $record-size == 0 ?? 0 !! $record-size - ($fsize % $record-size));
      next unless $x-p.match(/(\d+)' path'/);
      $x-p    .=substr($/.from);
      $fname   = $x-p.substr($/[0].Str.chars + 6, $/[0].Int - $/[0].Str.chars - 7).subst(/"\0"/, '', :g);
      next;
    }
    #read fdata
    $f.push($buffer.subbuf($cursor, $fsize))
      if $ftype eq ('0'|'1'|'g');
    $cursor += $fsize + ($fsize % $record-size == 0 ?? 0 !! $record-size - ($fsize % $record-size))
      if $ftype eq ('0'|'1'|'g');
    $multi = $f.subbuf(%idx<t><offset>, %idx<t><len>).decode('utf8').subst(/"\0"/, '', :g) eq 'x' ?? 2 !! 1;
    @fs.push((
      name    => $fname,
      written => 1,
      io      => Nil,
      header  => $f.subbuf(0, $record-size * $multi).clone,
      data    => $f.subbuf($record-size * $multi),
      type    => $ftype == 5 ?? 'd' !! 'f',
      fsize   => $fsize,
    ).Hash) if $fname ne '' && $ftype ne 'g';
    $fname = Nil;
  }
  @fs;
}
