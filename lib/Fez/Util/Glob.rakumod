unit module Fez::Util::Glob;

class globbalizer {
  has Regex @.patterns;
  method match(Str:D $test --> Bool) { ($test ~~ any @.patterns).so; }
  method rmatch(Str:D $test--> Bool) { !(self.match($test)).so; }
  method filter(*@lines    --> List) { @lines.grep({self.match($_)}).grep(*.defined).list; }
  method rfilter(*@lines   --> List) { @lines.grep({self.rmatch($_)}).grep(*.defined).list; }
}

constant %spesh = {'.'=>1, '+'=>1, '*'=>1,
                   '?'=>1, '^'=>1, '$'=>1,
                   '('=>1, ')'=>1, '['=>1,
                   ']'=>1, '{'=>1, '}'=>1,
                   '|'=>1, '/'=>1, '-'=>1,
                   '!'=>1, '\\'=>1, '~'=>1};

multi sub parse(*@lines, Bool :$git-ignore = False) is export {
  my @patterns = @lines
    .map({
      my $re = parse($_, :want-re, :$git-ignore);
      try rx/ <$re> /;
    })
    .grep(*.defined)
    .list;
  die 'No suitable patterns found for filtering' unless +@patterns;
  globbalizer.new(
    :@patterns,
  );
}

multi sub parse(Str:D $line, Bool :$git-ignore = False, Bool :$want-re = False) is export {
  return Empty if $line.trim.starts-with('#');
  my Str $re = '';
  my @parts = $line.split('', :skip-empty);
  my $i = 0;
  my $l = @parts.elems;
  while $i < $l {
    if @parts[$i] eq '[' {
      $i++;
      $re ~= "<{@parts[$i] eq '!' ?? '-' !! '+'}[";
      $i++ if @parts[$i] eq '!';
      $re ~= "\\{@parts[$i++]}" if @parts[$i] eq '[';
      while @parts[$i] ne ']' && $i < $l {
        $re ~= "{%spesh{@parts[$i]}:exists??'\\'!!''}{@parts[$i] eq '-' ?? '..' !! @parts[$i]}";
        $i++;
      }
      $re ~= ']>';
    } elsif @parts[$i] eq '!' && (@parts[$i+1]||'') eq '(' {
      $re ~= '<!before ';
      $i+=2;
      my $pos = $i;
      my $parens = 0;
      while $i < $l {
        $parens++ if @parts[$i] eq '(';
        $parens-- if @parts[$i] eq ')';
        last if $parens < 0;
        $i++;
      }
      my $sub-re = parse($line.substr($pos, $i-$pos), :want-re,);
      $sub-re.=substr(1,*-1) if $sub-re.substr(0,1) eq '^';
      $sub-re.=substr(1,*-1) if $sub-re.substr(0,1) eq '(';
      $sub-re ~~ s:g/\\\|/|/;
      $re ~= $sub-re ~ '><-[\/]>*';
    } elsif @parts[$i] ~~ ('?'|'*'|'+'|'@') && (@parts[$i+1]||'') eq '(' {
      $re ~= '("';
      my $op = @parts[$i];
      $i+=2;
      while @parts[$i] ne ')' && $i < $l {
        if @parts[$i] eq '|' {
          $re ~= '"';
          $re ~= '|"' if (@parts[$i+1]) ne ')';
        } else {
          $re ~= @parts[$i];
        }
        $i++;
      }
      $re ~= "\"){$op eq '@' ?? '' !! $op}";
    } elsif @parts[$i] eq '{' {
      $i++;
      $re ~= '(';
      while @parts[$i] ne '}' && $i < $l {
        if @parts[$i] eq ',' {
          $re ~= "|";
        } else {
          $re ~= "{%spesh{@parts[$i]}:exists??'\\'!!''}{@parts[$i]}";
        }
        $i++;
      }
      $re ~= ")";
    } elsif @parts[$i] eq '*' {
      my $star-count = $i;
      $i++ while $i < $l && (@parts[$i]||'') eq '*';
      $star-count = $i - $star-count;
      if $star-count == 2 {
        $re ~= '.*';
        if (@parts[$i]||'') eq '/' {
          $re ~= '\/?';
          $i++;
        }
      } else {
        $re ~= '<-[/]>*';
      }
      next;
    } elsif @parts[$i] eq '?' {
      $re ~= '.';
    } else {
      $re ~= "{%spesh{@parts[$i]}:exists??'\\'!!''}{@parts[$i]}";
    }
    $i++;
  }
  if $git-ignore {
    if $line.starts-with('/') {
      $re = "^{$re}";
    } else {
      $re = "{$re}";
    }
  } else {
    $re = "^{$re}\$";
  }
  if $re.ends-with('/') {
    $re = "{$re.substr(0, *-2)}(\\/|\$)";
  }
  # "DEBUG: $line -> $re\n".say;
  return $re if $want-re;
  globbalizer.new(:patterns( rx/ <$re> / ));
}
