use strict;
use warnings;
use Test::Tester; # Call before any other Test::Builder-based modules
use Test::More;
use Test::Deep qw( cmp_deeply re );
use Test::Warnings qw(:no_end_test warnings);
use parent qw( Test::Class );

use Test::WWW::Stub ignore_stub_urls => ['http://localhost:9091',qr<\A\Qhttp://127.0.0.1:9092/MATCH/\E>];
use LWP::UserAgent;
use HTTP::Server::PSGI;

sub ua { LWP::UserAgent->new; }

sub create_mock_server {
    my ($self, %options) = @_;
    my $port    = $options{port};
    my $content = $options{content};

    my $server = HTTP::Server::PSGI->new(
        host => "127.0.0.1",
        port => $port,
        timeout => 10,
    );
    
    $server->run(
            sub {
                my $env = shift;
                $env->{'psgix.harakiri.commit'} = 1;
                return [
                    200,
                    [ 'Content-Type' => 'text/plain' ],
                    [ $content ],
                ];
            },
    );
}

sub static_ignore_url : Tests {
    my $self = shift;

    my $stub = Test::WWW::Stub->register('http://example.com/OVERRIDE' => [ 500, [], [] ]);
    {
        my $response;
        my $pid = fork;
        my %plack_app_arg = (port => 9091, content => 'plack app');
        unless ($pid) {
            $self->create_mock_server(%plack_app_arg);
            exit;
        }
        my $warnings = [ warnings { $response= $self->ua->get('http://127.0.0.1:9091/OVERRIDE'); } ];
        wait;
        cmp_deeply $warnings, [], 'no warnings';
        is $response->code, 200, 'return by plack app';
        is $response->content, $plack_app_arg{content}, 'return by plack app';
    }
}

sub regex_url : Tests {
    my $self = shift;

    my $stub = Test::WWW::Stub->register('http://example.com/OVERRIDE' => [ 500, [], [] ]);
    {
        my $response;
        my $pid = fork;
        my %plack_app_arg = (port => 9092, content => 'plack app');
        unless ($pid) {
            $self->create_mock_server(%plack_app_arg);
            exit;
        }
        my $warnings = [ warnings { $response= $self->ua->get('http://127.0.0.1:9092/MATCH/'); } ];
        wait;
        cmp_deeply $warnings, [], 'no warnings';
        is $response->code, 200, 'return by plack app';
        is $response->content, $plack_app_arg{content}, 'return by plack app';
    }
}

sub non_ignore_url : Tests {
    my $self = shift;

    my $g1 = Test::WWW::Stub->register('http://example.com/OVERRIDE' => [ 500, [], [] ]);
    {
        my $code;
        my $warnings = [ warnings { $code = $self->ua->get('http://example.com/OVERRIDE')->code; } ];
        cmp_deeply $warnings, [], 'no warnings';
        is $code, 500, 'stub by g1';
    }

    my $g2 = Test::WWW::Stub->register('http://example.com/OVERRIDE' => [ 400, [], [] ]);
    {
        my $code;
        my $warnings = [ warnings { $code = $self->ua->get('http://example.com/OVERRIDE')->code; } ];
        cmp_deeply $warnings, [], 'no warnings';
        is $code, 400, 'stub by g2';
    }

    $g1 = undef;
    {
        my $code;
        my $warnings = [ warnings { $code = $self->ua->get('http://example.com/OVERRIDE')->code; } ];
        cmp_deeply $warnings, [], 'no warnings';
        is $code, 400, 'still stub by g2';
    }

    $g2 = undef;
    {
        my $code;
        my $warnings = [ warnings { $code = $self->ua->get('http://example.com/OVERRIDE')->code; } ];
        cmp_deeply $warnings, [ re('Unexpected external access:') ], 'warnings appeared';
    }
}

__PACKAGE__->runtests;