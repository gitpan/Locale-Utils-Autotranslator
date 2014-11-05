package Locale::Utils::Autotranslator::ApiMymemoryTranslatedNet; ## no critic (TidyCode)

use strict;
use warnings;
use HTML::Entities qw(decode_entities);
use HTTP::Request::Common qw(GET);
use JSON qw(decode_json);
use LWP::UserAgent;
use Moo;
use MooX::StrictConstructor;
use URI;
use namespace::autoclean;

our $VERSION = '0.001';

extends qw(
    Locale::Utils::Autotranslator
);

sub translate_text {
    my ( $self, $msgid ) = @_;

    $self->automatic_comment('translated by: api.mymemory.translated.net');
    my $uri = URI->new('http://api.mymemory.translated.net/get');
    $uri->query_form(
        q        => $msgid,
        langpair => join q{|}, $self->developer_language, $self->language,
    );
    my $ua = LWP::UserAgent->new;
    my $response = $ua->request(
        GET
            $uri->as_string,
            'User-Agent'      => 'Mozilla/5.0 (Windows NT 5.1; rv:26.0) Gecko/20100101 Firefox/26.0',
            'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language' => 'de-de,en-us;q=0.7,en;q=0.3',
            'Accept-Encoding' => 'gzip, deflate',
            'DNT'             => 1,
            'Connection'      => 'keep-alive',
            'Cache-Control'   => 'max-age=0',
    );
    $response->is_success
        or die $response->status_line, "\n";
    my $json = decode_json( $response->decoded_content );
    $json->{responseStatus} eq '200'
        or die $json->{responseDetails}, "\n";

    # Not clear why decode_entities here.
    # Looks like bad interface.
    return decode_entities( $json->{responseData}->{translatedText} );
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Locale::Utils::Autotranslator::ApiMymemoryTranslatedNet - Interface for translated.net

$Id: ApiMymemoryTranslatedNet.pm 523 2014-10-16 05:42:25Z steffenw $

$HeadURL: $

=head1 VERSION

0.001

=head1 SYNOPSIS

    use Locale::Utils::Autotranslator::ApiMymemoryTranslatedNet;

    my $obj = Locale::Utils::Autotranslator::ApiMymemoryTranslatedNet->new(
        language => 'de',
        # optional
        debug_code => sub {
            my ( $language, $text ) = @_;
            ...
        },
    );
    $obj->translate(
        'mydir/de.pot',
        'mydir/de.po',
    );

=head1 DESCRIPTION

Interface for translated.net

=head1 SUBROUTINES/METHODS

=head2 method translate_text

    $translated = $object->translate_text($untranslated);

=head1 EXAMPLE

Inside of this distribution is a directory named example.
Run the *.pl files.

=head1 DIAGNOSTICS

none

=head1 CONFIGURATION AND ENVIRONMENT

none

=head1 DEPENDENCIES

L<HTTP::Request::Common|HTTP::Request::Common>

L<JSON|JSON>

L<LWP::UserAgent|LWP::UserAgent>

L<Moo|Moo>

L<MooX::StrictConstructor|MooX::StrictConstructor>

L<URI|URI>

L<namespace::autoclean|namespace::autoclean>

L<Locale::Utils::Autotranslator|Locale::Utils::Autotranslator>

=head1 INCOMPATIBILITIES

not known

=head1 BUGS AND LIMITATIONS

not known

=head1 SEE ALSO

L<http://en.wikipedia.org/wiki/Gettext>

L<Locale::TextDomain::OO|Locale::TextDomain::OO>

=head1 AUTHOR

Steffen Winkler

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2014,
Steffen Winkler
C<< <steffenw at cpan.org> >>.
All rights reserved.

This module is free software;
you can redistribute it and/or modify it
under the same terms as Perl itself.
