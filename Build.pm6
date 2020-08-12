class Build {
  need LibraryMake;

  sub make(Str $folder, Str $destfolder, :$libname) {
    my %vars = LibraryMake::get-vars($destfolder);

    mkdir($destfolder);
    LibraryMake::process-makefile($folder, %vars);
    shell(%vars<MAKE>);

    my @fake-lib-exts = <.so .dylib>.grep(* ne %vars<SO>);
    "$destfolder/$libname$_".IO.open(:w) for @fake-lib-exts;
  }

  method build($workdir) {
    my $destdir = 'resources/lib';
    mkdir $destdir;
    make($workdir, "$destdir", :libname<libgetpw>);
  }
}

# Build.pm can also be run standalone
sub MAIN(Str $working-directory = '.' ) {
  Build.new.build($working-directory);
  exit 0;
}
