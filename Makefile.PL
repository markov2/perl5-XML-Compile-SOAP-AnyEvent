use ExtUtils::MakeMaker;

use 5.008;

WriteMakefile
 ( NAME	 	=> 'XML::Compile::SOAP::AnyEvent'
 , VERSION	=> '0.01'
 , PREREQ_PM    =>
   { XML::Compile::SOAP   => '2.18'
   , Log::Report          => '0.28'
   , Time::HiRes          => 0
   , AnyEvent::HTTP       => '1.46'
   }
 , AUTHOR       => 'Aleksey Mashanov/Mark Overmeer'
 , ABSTRACT     => 'SOAP with AnyEvent'
 , LICENSE      => 'perl'
 );

### used by oodist during production of distribution
sub MY::postamble { <<'__POSTAMBLE' }

EXTENDS		= ../XMLCompile:../XMLDaemon:../XMLTester:../XMLCache:../XMLSOAP12:../XMLSOAP

# for DIST
RAWDIR          = ../public_html/xml-compile-soap-anyevent/raw
DISTDIR         = ../public_html/xml-compile-soap-anyevent/source
LICENSE         = artistic
SKIP_LINKS	= XML::LibXML

# for POD
FIRST_YEAR      = 2010
EMAIL           = perl@overmeer.net
WEBSITE         = http://perl.overmeer.net/xml-compile/
PODTAIL		= ../XML-shared-podtail
__POSTAMBLE
