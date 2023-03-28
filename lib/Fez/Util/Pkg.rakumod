unit class Fez::Util::Pkg;

use Fez::Logr;
use Fez::Util::RTar;
use Fez::Util::Zlib;

method bundle($location, @manifest) {
  log(DEBUG, "Tarring manifest:\n%s", @manifest.map({"  $_"}).join("\n"));
  my $tbuf = tar(@manifest, :prefix<dist/>);

  log(DEBUG, 'tarred data %s bytes', $tbuf.bytes);

  cmprs($location, $tbuf);

  True;
}

method ls($file) {
  tar-ls($file, dcmprs($file));
}

method cat($file, $path) {
  tar-cat(dcmprs($file), $path);
}

method able {
  ::('Fez::Util::Zlib') !~~ Failure;
}
