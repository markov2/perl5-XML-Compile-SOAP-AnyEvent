use warnings;
use strict;

package XML::Compile::Transport::SOAPHTTP_AnyEvent;
use base 'XML::Compile::Transport';

use XML::Compile::Transport::SOAPHTTP;

BEGIN {
   # code mixin from  XML::Compile::Transport::SOAPHTTP
   no strict 'refs';
   foreach (qw/_prepare_xop_call _prepare_simple_call _prepare_for_no_answer/)
   {  *{__PACKAGE__."::$_"} = \&{"XML::Compile::Transport::SOAPHTTP::$_"};
   }
}

use Log::Report 'xml-compile-soap-anyevent', syntax => 'SHORT';
use XML::Compile::SOAP::Util qw/SOAP11ENV SOAP11HTTP/;
use XML::Compile   ();

use AnyEvent::HTTP;
use HTTP::Request  ();
use HTTP::Response ();
use HTTP::Headers  ();

# (Microsofts HTTP Extension Framework)
my $http_ext_id = SOAP11ENV;

__PACKAGE__->register(SOAP11HTTP);

=chapter NAME
XML::Compile::Transport::SOAPHTTP_AnyEvent - exchange XML via AnyEvent::HTTP

=chapter SYNOPSIS
 use XML::Compile::Transport::SOAPHTTP_AnyEvent;

 my $http = XML::Compile::Transport::SOAPHTTP_AnyEvent->new(@options);
 my $send = $http->compileClient(@options2);

 my $call = $wsdl->compileClient
   ( operation => 'some-port-name'
   , transport => $send
   , async     => 1      # required!
   );

 sub handler
   { my ($xmlout, $trace) = @_;
     # so something
   };

 $call->($xmlin, _callback => \&handler);

=chapter DESCRIPTION
This module handles the exchange of (XML) messages, according to the
rules of SOAP (any version).  The module does not known how to parse
or compose XML, but only worries about the HTTP aspects.

In contrairy to M<XML::Compile::Transport::SOAPHTTP>, this implementation
can be used in various event-driven environments, via M<AnyEvent::HTTP>.

=chapter METHODS

=c_method new OPTIONS

=option  any_event_params ARRAY
=default any_event_params []

Options passed to M<AnyEvent::HTTP>, for instance C<timeout> and C<proxy>.
The ARRAY is a list of PAIRS.

=cut

sub init($)
{   my ($self, $args) = @_;
    $self->{ae_params} = delete $args->{any_event_params};
    $self->SUPER::init($args);
    $self;
}

sub initWSDL11($)
{   my ($class, $wsdl) = @_;
    trace "initialize SOAPHTTP-AnyEvent transporter for WSDL11";
}

#-------------------------------------------

=section Accessors

=method anyEventParams
=cut

sub anyEventParams() { @{shift->{ae_params} || []} }

#-------------------------------------------

=section Handlers

=method compileClient OPTIONS

Compile an HTTP client handler.  Returned is a subroutine which is called
with a text represenation of the XML request, or an XML::LibXML tree.
In SCALAR context, an XML::LibXML parsed tree of the answer message
is returned.  In LIST context, that answer is followed by a HASH which
contains trace information.

=option  method 'POST'|'M-POST'
=default method 'POST'
With C<POST>, you get the standard HTTP exchange.  The C<M-POST> is
implements the (Microsoft) HTTP Extension Framework.  Some servers
accept both, other require a specific request.

=option  mpost_id INTEGER
=default mpost_id 42
With method C<M-POST>, the header extension fields require (any) number
to be grouped.

=option  mime_type STRING
=default mime_type <depends on soap version>

=option  action URI
=default action ''

=option  soap 'SOAP11'|'SOAP12'|OBJECT
=default soap 'SOAP11'

=option  header  HTTP::Headers object
=default header  <created>
Versions of M<XML::Compile>, M<XML::Compile::SOAP>, and M<LWP> will be
added to simplify bug reports.

=option  kind    DIRECTION
=default kind    'request-response'
What kind of interactie, based on the four types defined by WSDL(1):
C<notification-operation> (server initiated, no answer required),
C<one-way> (client initiated, no answer required), C<request-response>
(client initiated, the usual in both directions), C<solicit-response> (server
initiated "challenge").

=cut

sub compileClient(@)
{   my ($self, %args) = @_;
    my $call   = $self->_prepare_call(\%args);
    my $kind   = $args{kind} || 'request-response';
    my $parser = XML::LibXML->new;

    sub
    {   my ($xmlout, $trace, $mtom, $callback) = @_;
        my $start     = time;
        my $textout   = ref $xmlout ? $xmlout->toString : $xmlout;
#warn $xmlout->toString(1);   # show message sent

        my $stringify = time;
        $trace->{transport_start}  = $start;

        my $handler = sub
         { my ($textin, $xops) = @_;
           my $connected = time;

           my $xmlin;
           if($textin)
           {   $xmlin = eval {$parser->parse_string($$textin)};
               $trace->{error} = $@ if $@;
           }

           my $answer;
           if($kind eq 'one-way')
           {   my $response = $trace->{http_response};
               my $code = defined $response ? $response->code : -1;
               if($code==202) { $answer = $xmlin || {} }
               else { $trace->{error} = "call failed with code $code" }
           }
           elsif($xmlin) { $answer = $xmlin }
           else { $trace->{error} ||= 'no xml as answer' }

           my $end = $trace->{transport_end} = time;

           $trace->{stringify_elapse} = $stringify - $start;
           $trace->{connect_elapse}   = $connected - $stringify;
           $trace->{parse_elapse}     = $end - $connected;
           $trace->{transport_elapse} = $end - $start;

           return ($answer, $trace, $xops);
        };

        $call->(\$textout, $trace, $mtom, sub {$callback->($handler->(@_))} );
    };
}

sub _prepare_call($)
{   my ($self, $args) = @_;
    my $method   = $args->{method}   || 'POST';
    my $soap     = $args->{soap}     || 'SOAP11';
    my $version  = ref $soap ? $soap->version : $soap;
    my $mpost_id = $args->{mpost_id} || 42;
    my $action   = $args->{action};
    my $mime     = $args->{mime};
    my $kind     = $args->{kind}     || 'request-response';
    my $expect   = $kind ne 'one-way' && $kind ne 'notification-operation';

    my $charset  = $self->charset;

    # Prepare header
    my $header   = $args->{header}   || HTTP::Headers->new;
    $self->headerAddVersions($header);

    my $content_type;
    if($version eq 'SOAP11')
    {   $mime  ||= 'text/xml';
        $content_type = qq{$mime; charset="$charset"};
    }
    elsif($version eq 'SOAP12')
    {   $mime  ||= 'application/soap+xml';
        my $sa   = defined $action ? qq{; action="$action"} : '';
        $content_type = qq{$mime; charset="$charset"$sa};
        $header->header(Accept => $mime);  # not the HTML answer
    }
    else
    {   error "SOAP version {version} not implemented", version => $version;
    }

    if($method eq 'POST')
    {   $header->header(SOAPAction => qq{"$action"})
            if defined $action;
    }
    elsif($method eq 'M-POST')
    {   $header->header(Man => qq{"$http_ext_id"; ns=$mpost_id});
        $header->header("$mpost_id-SOAPAction", qq{"$action"})
            if $version eq 'SOAP11';
    }
    else
    {   error "SOAP method must be POST or M-POST, not {method}"
          , method => $method;
    }

    # Prepare request

    # Ideally, we should change server when one fails, and stick to that
    # one as long as possible.
    my $server  = $self->address;
    my $request = HTTP::Request->new($method => $server, $header);
    $request->protocol('HTTP/1.1');

    # Create handler

    my ($create_message, $parse_message)
      = exists $INC{'XML/Compile/XOP.pm'}
      ? $self->_prepare_xop_call($content_type)
      : $self->_prepare_simple_call($content_type);

    $parse_message = $self->_prepare_for_no_answer($parse_message)
        unless $expect;

    sub  # async call
     { my ($content, $trace, $mtom, $callback) = @_;
       $create_message->($request, $content, $mtom);

       $trace->{http_request}  = $request;

       my $guard;   # keeps event running
       my $handler = sub
         { my($data, $headers) = @_;
           undef $guard;

           unless(defined $data)
           {   $trace->{error} = "$headers->{Status} $headers->{Reason} with data";
               return $callback->(undef, undef, $trace);
           }

           delete @$headers{ qw(URL HTTPVersion) };
           my $response = $trace->{http_response} = HTTP::Response->new
             ( delete $headers->{Status}
             , delete $headers->{Reason}
             , [%$headers]
             , $data
             );

           if($response->header('Client-Warning'))
           {   $trace->{error} = $response->message; 
               return $callback->(undef, undef, $trace);
           }

           if($response->is_error)
           {   $trace->{error} = $response->message;
               # still try to parse the response for Fault blocks
           }

           my ($parsed, $mtom) = try {$parse_message->($response)};
           if($@)
           {   $trace->{error} = $@->wasFatal->message;
               return $callback->(undef, undef, $trace);
           }

           try {$callback->($parsed, $mtom, $trace)};
         };

       $guard = http_request $request->method => $request->uri
         , body    => $request->content
         , headers => $request->headers
         , $self->anyEventParams
         , $handler;
     };
}

=ci_method headerAddVersions HEADER
Adds some lines about module versions, which may help debugging
or error reports.  This is called when a new client or server
is being created.
=cut

sub headerAddVersions($)
{   my ($thing, $h) = @_;
    foreach my $pkg (qw/XML::Compile XML::Compile::Cache
       XML::Compile::SOAP XML::LibXML AnyEvent::HTTP/)
    {   no strict 'refs';
        my $version = ${"${pkg}::VERSION"} || 'undef';
        (my $field = "X-$pkg-Version") =~ s/\:\:/-/g;
        $h->header($field => $version);
    }
}

1;
