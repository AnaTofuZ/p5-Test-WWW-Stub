requires 'perl', '5.008001';

requires 'LWP::Protocol::PSGI';
requires 'LWP::UserAgent';
requires 'Plack::Request';
requires 'Plack::Response';
requires 'HTTP::Request';
requires 'List::MoreUtils';
requires 'Test::More', '0.98';
requires 'Guard';
requires 'URI';

on 'test' => sub {
    requires 'Test::Class';
    requires 'Test::Deep';
    requires 'Test::Tester';
    requires 'Test::Warnings';
    requires 'HTTP::Server::PSGI';
};
