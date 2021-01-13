task-run "fez login", "fez-login", %(
  user => %*ENV<fez_user>,
  password => %*ENV<fez_password>,
);

