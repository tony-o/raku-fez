use Fez::Util::Glob;

use Test;

sub e(@a, @b --> Bool) {
  return False if @a.elems != @b.elems;
  my $i = 0;
  for @a -> $a {
    return False if $a ne @b[$i];
    $i++;
  }
  True;
}

my $tests = 1;
my @test  = qw<Cat.png Bat.png Rat.png car.png a/list.png mom.jpg cat.jpg landscape.tiff>,
            qw<one.js two.js three.js four.md 3.js>,
            qw</file.js /one/file.js /one/two/file.js /one/two/three/file.js>,
            qw</static/file.js /build/public/file.js /src/file.js>,
            qw</a-xyz/file.js /b-xyz/file.js /c-xyz/file.js /d-xyz/file.js /e-xyz/file.js>,
            qw</public/file.js /dist/file.js /src/file.js /build/file.js>,
            qw<file.js file.min.js file.umd.js file.min.umd.js file.es6.js>,
            ;

sub t($globs, @input, @expects, :$name = "t{$tests++}") {
  my $res= parse($globs).filter(@input);
  my $tf = e(@expects, $res);
  ok $tf, "$name: $globs {
            $tf 
            ?? ''
            !! "\nEXPECT: [{@expects.join(', ')}]\nGOT:    [{$res.join(', ')}]"}";
}

my %tests = (
  '?at.{png,jpg}'  => (qw<Cat.png Bat.png Rat.png cat.jpg>, @test[0]),
  '*.{!png,!jpg}'  => (qw<>, @test[0]),
  '*.!{png,jpg}'   => (qw<>, @test[0]),
  '*.!({png,jpg})' => (@('landscape.tiff'), @test[0]),
  '[CBR]at.png'    => (qw<Cat.png Bat.png Rat.png>, @test[0]),
  '*'              => (qw<Cat.png Bat.png Rat.png car.png mom.jpg cat.jpg landscape.tiff>, @test[0]),
  '*/*'            => (@('a/list.png'), @test[0]),
  '*/*/*'          => (qw<>, @test[0]),
  '**'             => (@test[0], @test[0]),
  '***'            => (qw<Cat.png Bat.png Rat.png car.png mom.jpg cat.jpg landscape.tiff>, @test[0]),
  '[aA]/*'         => (@('a/list.png'), @test[0]),
  '[a-z]/*'        => (@('a/list.png'), @test[0]),
  '[cC]/*'         => (qw<>, @test[0]),
  '[aA]/'          => (qw<>, @test[0]),
  '*.js'           => (qw<one.js two.js three.js 3.js>, @test[1]),
  '?.js'           => (@('3.js'), @test[1]),
  '/**/*.js'       => (@test[2], @test[2]),


  'file@(.min|.umd).js'         => (qw<file.min.js file.umd.js>, @test[6]),
  'file+(.min|.umd).js'         => (qw<file.min.js file.umd.js file.min.umd.js>, @test[6]),
  'file*(.min|.umd).js'         => (qw<file.js file.min.js file.umd.js file.min.umd.js>, @test[6]),
  'file?(.min|.umd).js'         => (qw<file.js file.min.js file.umd.js>, @test[6]),
  '/!(src|build)/*.js'          => (qw</public/file.js /dist/file.js>, @test[5]),
  '/[!abc]-xyz/*.js'            => (qw</d-xyz/file.js /e-xyz/file.js>, @test[4]),
  '/[abc]-xyz/*.js'             => (qw</a-xyz/file.js /b-xyz/file.js /c-xyz/file.js>, @test[4]),
  '/{static,build/public}/*.js' => (qw</static/file.js /build/public/file.js>, @test[3]),
);

plan 1+%tests.keys.elems;

%tests.keys.sort.map({t("$_", %tests{$_}[1], %tests{$_}[0])});

# test list
my @tl = qw<A.png B.png C.png a/A.png b/A.png b/b.png>;
ok e(qw<A.png B.png C.png b/A.png>, parse(qw<*.png b/[A-Z]*>).filter(@tl)), 'multi parse handles array of glob patterns';

# vi:syntax=raku
