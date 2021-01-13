directory "teddy-bear";

git-scm "https://github.com/melezhik/rakudist-teddy-bear.git", %(
  to => "teddy-bear",
  branch => "master"
);


bash "{%*ENV<HOME>}/.raku/bin/fez --file=META6.json upload", %(
  cwd => "{%*ENV<PWD>}/teddy-bear",
  debug => True,
);
