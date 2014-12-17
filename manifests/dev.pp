class { 'testdb':
  perl_version => '5.20.1',
  source       => 'file:///vagrant',
  revision     => '4d7b92b98e79dfabb3b47a17cd2dea60f8d2a176',
  fq_hostname  => '192.168.33.10',
  redirect     => 'false',
  ssl          => 'false',
}
