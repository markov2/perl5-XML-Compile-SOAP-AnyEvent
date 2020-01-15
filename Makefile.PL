use ExtUtils::MakeMaker;

use 5.010;

WriteMakefile
 ( NAME	 	=> 'XML::Compile::SOAP::AnyEvent'
 , VERSION	=> '0.91'
 , PREREQ_PM    =>
   { XML::Compile::SOAP   => '3.05'
   , Log::Report          => '1.05'
   , Time::HiRes          => 0
   , AnyEvent::HTTP       => '1.46'
   , HTTP::Message        => '6.07'
   }
 , AUTHOR       => 'Mark Overmeer <markov@cpan.org>'
 , ABSTRACT     => 'SOAP transport with AnyEvent'
 , LICENSE      => 'perl_5'

 , META_MERGE   =>
      { 'meta-spec' => { version => 2 }
      , resources  =>
          { repository =>
              { type => 'git'
              , url  => 'https://github.com/markov2/perl5-XML-Compile-SOAP-AnyEvent.git'
              , web  => 'https://github.com/markov2/perl5-XML-Compile-SOAP-AnyEvent'
              }
          , homepage => 'http://perl.overmeer.net/xml-compile/'
          , license  => [ 'http://dev.perl.org/licenses/' ]
          }
      }
 );

### used by oodist during production of distribution
sub MY::postamble { <<'__POSTAMBLE' }

EXTENDS		= ../XML-Compile:../XML-Compile-SOAP-Daemon:../XML-Compile-Tester:../XML-Compile-Cache:../XML-Compile-SOAP12:../XML-Compile-SOAP

# for DIST
RAWDIR          = ../public_html/xml-compile-soap-anyevent/raw
DISTDIR         = ../public_html/xml-compile-soap-anyevent/source
SKIP_LINKS      = XML::LibXML

# for POD
FIRST_YEAR      = 2010
EMAIL           = perl@overmeer.net
WEBSITE         = http://perl.overmeer.net/xml-compile/
__POSTAMBLE
