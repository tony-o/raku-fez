use Fez::Util::Glob;
use Test;

plan 5;

sub cleanup(IO::Path:D $dir) {
  for $dir.dir -> $f {
    $f.f ?? $f.unlink !! cleanup($f);
  }

  $dir.rmdir;
}

sub with-tmp(&block) {
  my $tmp = $*TMPDIR.add("fez-test-$*PID");
  $tmp.mkdir;
  LEAVE cleanup($tmp);
  block($tmp);
}

with-tmp -> $tmp {
  is-deeply ignored-files($tmp), ('.gitignore', '.fezignore'),
    'returns only source filenames when neither ignore file exists';
};

with-tmp -> $tmp {
  $tmp.add('.gitignore').spurt: "*.log\nbuild/\n";

  is-deeply ignored-files($tmp), ('*.log', 'build/', '.gitignore', '.fezignore'),
    'returns .gitignore lines followed by source filenames';
};

with-tmp -> $tmp {
  $tmp.add('.fezignore').spurt: "t/\ndocs/\n";

  is-deeply ignored-files($tmp), ('t/', 'docs/', '.gitignore', '.fezignore'),
    'returns .fezignore lines followed by source filenames';
};

with-tmp -> $tmp {
  $tmp.add('.gitignore').spurt: "*.log\n";
  $tmp.add('.fezignore').spurt: "t/\n";

  is-deeply ignored-files($tmp), ('*.log', 't/', '.gitignore', '.fezignore'),
    'includes lines from both .gitignore and .fezignore';
};

with-tmp -> $tmp {
  $tmp.add('.gitignore').spurt: "*.log\n*.log\n";
  $tmp.add('.fezignore').spurt: "*.log\n";

  is-deeply ignored-files($tmp), ('*.log', '.gitignore', '.fezignore'),
    'duplicate lines across files are deduplicated';
};
