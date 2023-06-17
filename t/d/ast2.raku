unit package fEZ::wEB;


my @handlers = |();
my $uri      = ('host');

state $handler = do {
  ()
};

multi head($endpoint, :%headers = { }) is export {
  ()
}

multi get($endpoint, :%headers = { }) is export {
  ()
}
multi post($endpoint, :$method = 'POST', :$data = '', :$file = '', :%headers) is export {
  ()
}

class AA::BB {
  role CC { }
}

class BB::CC { };
