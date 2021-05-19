use Fez::Util::RTar::Util; 

class Fez::Util::RTar::Tar {
  has @!buffer;
  has IO::Path $!file-name;
  has $!state;

  submethod TWEAK(IO() :$!file-name!, :@!buffer) {
    $!state = @!buffer.elems ?? 'tar' !! 'extracted';
  }

  method push(*@files){
    @files.map(*.IO).map({
      warn "Could not find file to tar: {.relative}", next
        unless $_.e;
      @!buffer.push((
        name    => $_.relative,
        written => 0,
        io      => $_,
        type    => $_ ~~ :d ?? 'd' !! 'f',
      ).Hash);
    });
  }

  method ls {
    @!buffer.map({ $_<name> });
  }

  method peek(Str $fn) {
    my $f = @!buffer.grep(*<name> eq $fn);
    return Nil
      unless $f || $f.elems == 0;
    $f=$f[0];
    my Buf $b.=new;
    try { $b = $f<data>.subbuf(0, $f<fsize>).clone; CATCH { default { .say } }};
    ($f<type>//'') => $b;
  }

  method write(IO() $file-name = $!file-name, Bool :$force = False) {
    die "File exists {$file-name.relative}, please use :force to overwrite"
      if (!$force && $file-name ~~ :e && $file-name ne $!file-name.relative);
    my Buf $buffer .=new;
    my $cursor = 0;
    for @!buffer -> $entry is rw {
      my $header = form-header($entry<io>);
      my $data   = -> IO() $file {
        my $empty = $record-size - ($file.s % $record-size);
        $file ~~ :d ?? Buf.new() !! Buf.new(|$file.IO.slurp.encode('utf8'), Buf.allocate($empty).values);
      }($entry<io>);
      $buffer.push: $header;
      $buffer.push: $data;
      $entry<fsize>  = :8(($header.elems > $record-size
        ?? $header.subbuf($header.elems - 512 + 124, 12)
        !! $header.subbuf(124, 12)
      ).decode('utf8').subst(/"\0"/, '', :g).trim)//0;

      $entry<header> = $header;
      $entry<data>   = $data;
    }
    for 0 ..^2 {
      $buffer.push(Buf.allocate($record-size));
    }
    $!file-name.spurt($buffer, :b);
    $!state = 'tar';
  }

  method state { $!state; }

}
