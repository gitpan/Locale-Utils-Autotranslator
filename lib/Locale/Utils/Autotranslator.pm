package Locale::Utils::Autotranslator; ## no critic (TidyCode)

use strict;
use warnings;
use Carp qw(confess);
use Encode qw(decode find_encoding);
use List::MoreUtils qw(uniq);
use Locale::PO;
use Locale::TextDomain::OO::Util::ExtractHeader;
use Moo;
use MooX::StrictConstructor;
use MooX::Types::MooseLike::Base qw(CodeRef Str);
use MooX::Types::MooseLike::Numeric qw(PositiveInt PositiveOrZeroInt);
use Try::Tiny;
use namespace::autoclean;

our $VERSION = '0.002';

# a .. w, z     => A-WZ
# A .. W, Z     => Ym
# space         => YX
# open, e.g. {  => XX
# :             => XY
# close, e.g. } => XZ
# other         => XAA .. XPP
#                  like hex but
#                  0123456789ABCDEF is
#                  ABCDEFGHIJKLMNOP

has _plural_ref => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { {} },
);

sub _clear_plural_ref {
    my $self = shift;

    %{ $self->_plural_ref } = ();

    return;
}

has _num_ref => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { {} },
);

sub _clear_num_ref {
    my $self = shift;

    %{ $self->_num_ref } = ();

    return;
}

has limit => (
    is      => 'rw',
    isa     => PositiveInt,
    clearer => 'clear_limit',
);

has sleep_seconds => (
    is  => 'ro',
    isa => PositiveOrZeroInt,
);

has developer_language => (
    is      => 'ro',
    isa     => Str,
    default => 'en',
);

has language => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has automatic_comment => (
    is  => 'rw',
    isa => Str,
);

has debug_code => (
    is  => 'ro',
    isa => CodeRef,
);

has error => (
    is      => 'rw',
    clearer => '_clear_error',
);

my $encode_az = sub {
    my $inner = shift;

    my $encode_inner = sub {
        my ( $lc, $uc, $space, $colon, $other ) = @_;

        if ( defined $lc ) {
            return uc $lc;
        }
        if ( defined $uc ) {
            return q{Y} . $uc;
        }
        if ( defined $space ) {
            return 'YX';
        }
        if ( defined $colon ) {
            return 'XY';
        }

        $other = ord $other;
        $other > 255 ## no critic (MagicNumbers)
            and confess 'encode error Xnn overflow';
        my $digit2 = int $other / 16; ## no critic (MagicNumbers)
        my $digit1 = $other % 16; ## no critic (MagicNumbers)
        for my $digit ( $digit2, $digit1 ) {
            $digit = [ q{A} .. q{P} ]->[$digit];
        }

        return q{X} . $digit2 . $digit1;
    };

    $inner =~ s{
        ( [a-wz] )
        | ( [A-WZ] )
        | ( [ ] )
        | ( [:] )
        | ( . )
    }
    {
        $encode_inner->($1, $2, $3, $4, $5, $6)
    }xmsge;

    return 'XX'. $inner . 'XZ';
};

sub _encode_named_placeholder {
    my ( $self, $placeholder ) = @_;

    ## no critic (EscapedMetacharacters)
    $placeholder =~ s{
        ( \\ \{ )
        | \{ ( [^\}]* ) \}
    }
    {
        $1
        || $encode_az->($2)
    }xmsge;
    ## use critic (EscapedMetacharacters)

    return $placeholder;
}

my $decode_inner = sub {
    my $inner = shift;

    my @chars = $inner =~ m{ (.) }xmsg;
    my $decoded = q{};
    CHAR:
    while ( @chars ) {
        my $char = shift @chars;
        if ( $char =~ m{ \A [A-WZ] \z }xms ) {
            $decoded .= lc $char;
            next CHAR;
        }
        if ( $char eq q{Y} ) {
            @chars
                or confess 'decode error Y';
            my $char2 = shift @chars;
            $decoded .= $char2 eq q{X}
                ? q{ }
                : uc $char2;
            next CHAR;
        }
        if ( $char eq q{X} ) {
            @chars
                or confess 'decode error Xn';
            my $char2 = shift @chars;
            if ( $char2 eq q{Y} ) {
                $decoded .= q{:};
                next CHAR;
            }
            @chars
                or confess 'decode error Xnn';
            my $char3 = shift @chars;
            my $decode_string = 'ABCDEFGHIJKLMNOP';
            my $index2 = index $decode_string, $char2;
            $index2 == -1 ## no critic (MagicNumbers)
                and confess 'decode error X?';
            my $index1 = index $decode_string, $char3;
            $index1 == -1 ## no critic (MagicNumbers)
                and confess 'decode error Xn?';
            $decoded .= chr $index2 * 16 + $index1; ## no critic (MagicNumbers)
            next CHAR;
        }
        confess 'decode error';
    }

    return $decoded;
};

sub _decode_named_placeholder {
    my ( $self, $placeholder ) = @_;

    $placeholder =~ s{
        XX
        ( [[:upper:]]+ )
        XZ
    }
    {
        q[{] . $decode_inner->($1) . q[}]
    }xmsge;

    return $placeholder;
}

sub translate { ## no critic (ExcessComplexity)
    my ( $self, $name_read, $name_write ) = @_;

    defined $name_read
        or confess 'Undef is not a name of a po/pot file';
    defined $name_write
        or confess 'Undef is not a name of a po file';
    my $pos_ref = Locale::PO->load_file_asarray($name_read)
        or confess "$name_read is not a valid po/pot file";

    my $header = Locale::TextDomain::OO::Util::ExtractHeader
        ->instance
        ->extract_header_msgstr(
            Locale::PO->dequote(
                $pos_ref->[0]->msgstr
                    || confess "No header found in file $name_read",
            ),
        );
    my $charset     = $header->{charset};
    my $encode_obj  = find_encoding($charset);
    my $nplurals    = $header->{nplurals};
    my $plural_code = $header->{plural_code};
    $self->_clear_error;
    $self->_clear_plural_ref;
    my $entry_ref = { encode_obj => $encode_obj };

    MESSAGE:
    for my $po ( @{$pos_ref}[ 1 .. $#{$pos_ref} ] ) {
        $entry_ref->{msgid}
            = $po->msgid
            && $encode_obj->decode( $po->dequote( $po->msgid ) );
        $entry_ref->{msgid_plural}
            = defined $po->msgid_plural
            && $encode_obj->decode( $po->dequote( $po->msgid_plural ) );
        $entry_ref->{msgstr}
            = defined $po->msgstr
            && $po->dequote( $po->msgstr );
        length $entry_ref->{msgstr}
            and next MESSAGE;
        $entry_ref->{msgstr_n} = {};
        my $msgstr_n = $po->msgstr_n || {};
        my $is_all_translated = 1;
        for my $index ( 0 .. ( $nplurals - 1 ) ) {
            $entry_ref->{msgstr_n}->{$index}
                = defined $msgstr_n->{$index}
                && $po->dequote( $msgstr_n->{$index} );
            my $is_translated
                = defined $entry_ref->{msgstr_n}->{$index}
                && length $entry_ref->{msgstr_n}->{$index};
            $is_all_translated &&= $is_translated;
        }
        $is_all_translated
            and next MESSAGE;
        if ( length $entry_ref->{msgid_plural} ) {
            if ( $nplurals ) {
                ## no critic (MagicNumbers)
                NUMBER:
                for ( 0 .. 1000 ) {
                    my $plural = $plural_code->($_);
                    if ( ! exists $self->_plural_ref->{$plural} ) {
                        $self->_plural_ref->{$plural} = $_;
                    }
                    $nplurals == ( keys %{ $self->_plural_ref } )
                        and last NUMBER;
                }
                ## use critic (MagicNumbers)
            }
            $self->_translate_named_plural($entry_ref, $po);
            $self->_update_automatic_comment($po);
            Locale::PO->save_file_fromarray($name_write, $pos_ref);
            next MESSAGE;
        }
        if ( $entry_ref->{msgid} =~ m{ \{ [^\{\}]+ \} }xms ) { ## no critic (EscapedMetacharacters)
            $self->_translate_named($entry_ref, $po);
            $self->_update_automatic_comment($po);
            Locale::PO->save_file_fromarray($name_write, $pos_ref);
            next MESSAGE;
        }
        if ( $entry_ref->{msgid} =~ m{ [%] (?: \d | [*] | quant ) }xms ) {
            $self->_translate_gettext($entry_ref, $po);
            $self->_update_automatic_comment($po);
            Locale::PO->save_file_fromarray($name_write, $pos_ref);
            next MESSAGE;
        }
        $self->_translate_simple($entry_ref, $po);
        $self->_update_automatic_comment($po);
        Locale::PO->save_file_fromarray($name_write, $pos_ref);
    }

    return;
}

sub _encode_named {
    my ( $self, $msgid, $num ) = @_;

    $num = defined $num ? $num : 1;
    $self->_clear_num_ref;
    my $encode_placeholder = sub {
        my ( $placeholder, $is_num ) = @_;
        if ( $is_num ) {
            $self->_num_ref->{$num} = $placeholder;
            return $num++;
        }
        return $self->_encode_named_placeholder($placeholder);
    };
    ## no critic (EscapedMetacharacters)
    $msgid =~ s{
        ( \\ \{ )
        | (
            \{
            [^\{\}:]+
            ( [:] ( num )? [^\{\}]* )?
            \}
        )
    }
    {
        $1
        || $encode_placeholder->($2, $3)
    }xmsge;
    ## use critic (EscapedMetacharacters)

    return $msgid;
}

sub _decode_named {
    my ( $self, $msgstr ) = @_;

    $msgstr =~ s{ ( \d+ ) }{
        exists $self->_num_ref->{$1} ? $self->_num_ref->{$1} : $1
    }xmsge;
    $msgstr = $self->_decode_named_placeholder($msgstr);

    return $msgstr;
}

sub _translate_named {
    my ( $self, $entry_ref, $po ) = @_;

    my $msgid = $self->_encode_named( $entry_ref->{msgid} );
    my $msgstr = $self->_translate_with_api($msgid);
    $msgstr = $self->_decode_named($msgstr);
    $po->msgstr( $entry_ref->{encode_obj}->encode($msgstr) );

    return;
}

sub _translate_named_plural {
    my ( $self, $entry_ref, $po ) = @_;

    my $msgid        = $entry_ref->{msgid};
    my $msgid_plural = $entry_ref->{msgid_plural};
    MSGSTR_N:
    for my $number_of_plural_form ( sort keys %{ $self->_plural_ref } ) {
        my $index = $number_of_plural_form - 1;
        defined $entry_ref->{msgstr_n}->{$index}
            and length $entry_ref->{msgstr_n}->{$index}
            and next MSGSTR_N;
        my $any_msgid = $self->_encode_named(
            $number_of_plural_form == 1 ? $msgid : $msgid_plural,
            $number_of_plural_form,
        );
        my $any_msgstr = $self->_translate_with_api($any_msgid);
        $any_msgstr = $self->_decode_named($any_msgstr);
        $po->msgstr_n->{$index}
           = $po->quote( $entry_ref->{encode_obj}->encode($any_msgstr) );
    }

    return;
}

sub _encode_gettext_inner { ## no critic (ManyArgs)
    my ( $self, $quant, $number, $singular, $plural, $zero ) = @_;

    $self->_plural_ref->{$number} = [
        $quant,
        map {
            ( defined $_ && length $_ )
            ? $self->_translate_with_api($_)
            : undef;
        } $singular, $plural, $zero
    ];

    return $encode_az->("*$number");
}

sub _encode_gettext {
    my ( $self, $msgid ) = @_;

    ## no critic (ComplexRegexes)
    $msgid =~ s{
        ( %% )                    # escaped
        |
        [%] ( [*] | quant )       # quant
        [(]
            [%] ( \d+ )           # number
            [,] ( [^,)]* )        # singular
            [,] ( [^,)]* )        # plural
            (?: [,] ( [^,)]* ) )? # zero
        [)]
        |
        [%] ( \d+ )               # simple
    }
    {
        $1
        ? $1
        : $2
        ? $self->_encode_gettext_inner($2, $3, $4, $5, $6)
        : $encode_az->($7)
    }xmsge;
    ## use critic (ComplexRegexes)

    return $msgid;
}

sub _decode_gettext_inner {
    my ( $self, $inner ) = @_;

    $inner = $decode_inner->($inner);
    if ( $inner =~ m{ \A ( \d+ ) \z }xms ) {
        return q{%} . $1;
    }
    if ( $inner =~ m{ \A [*] ( \d+ ) \z }xms ) {
        my $plural = $self->_plural_ref->{$1};
        return join q{},
            q{%},
            $plural->[0],
            q{(},
            ( join q{,}, "%$1", grep { defined } @{$plural}[ 1 .. 3 ] ), ## no critic (MagicNumbers)
            q{)};
    }

    confess "decode error gettext inner $inner";
}

sub _decode_gettext {
    my ( $self, $msgstr ) = @_;

    $msgstr =~ s{
        XX
        ( [[:upper:]]+? )
        XZ
    }
    {
        $self->_decode_gettext_inner($1)
    }xmsge;

    return $msgstr;
}

sub _translate_gettext {
    my ( $self, $entry_ref, $po ) = @_;

    $self->_clear_plural_ref;
    my $msgid = $self->_encode_gettext( $entry_ref->{msgid} );
    my $msgstr = $self->_translate_with_api($msgid);
    $msgstr = $self->_decode_gettext($msgstr);
    $po->msgstr( $entry_ref->{encode_obj}->encode($msgstr) );

    return;
}

sub _translate_simple {
    my ( $self, $entry_ref, $po ) = @_;

    $po->msgstr(
        $entry_ref->{encode_obj}->encode(
            $self->_translate_with_api( $entry_ref->{msgid} ),
        ),
    );

    return;
}

sub _update_automatic_comment {
    my ( $self, $po ) = @_;

    defined $self->automatic_comment
        or return;
    length $self->automatic_comment
        or return;
    my $automatic = $po->automatic;
    if ( ! defined $automatic ) {
        $po->automatic( $self->automatic_comment );
        return;
    }
    my @lines = $automatic =~ m{ [\n]* ( [^\n]+ ) }xmsg;
    push @lines, $self->automatic_comment;
    $po->automatic( join "\n", sort +uniq( @lines ) );

    return;
}

sub _translate_with_api {
    my ( $self, $msgid ) = @_;

    if ( $self->error || defined $self->limit && ! $self->limit ) {
        return q{};
    }
    $self->limit
        and $self->limit( $self->limit - 1 );
    $self->debug_code
        and $self->debug_code->( $self->developer_language, $msgid );
    my $msgstr = try {
        $self->translate_text($msgid);
    }
    catch {
        $self->error( ( defined $_ && length $_ ) ? $_ : 'unknown error' );
        q{};
    };
    $self->error
        and return;
    $self->debug_code
        and $self->debug_code->( $self->language, $msgstr);
    if ( $self->sleep_seconds && defined $msgstr && length $msgstr ) {
        sleep $self->sleep_seconds;
    }

    return $msgstr;
}

sub translate_text {
    my ( $self, $msgid ) = @_;

    return q{};
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Locale::Utils::Autotranslator - Base class to translate automaticly

$Id: Autotranslator.pm 534 2014-10-27 06:46:01Z steffenw $

$HeadURL: $

=head1 VERSION

0.002

=head1 SYNOPSIS

    package MyAutotranslator;

    use Moo;

    extends qw(
        Locale::Utils::Autotranslator
    );

    sub translate_text {
        my ( $self, $text ) = @_;

        my $developer_language = $self->developer_language;
        my $language           = $self->language;
        my $translation = MyTranslatorApi
            ->new(
                from => $developer_language,
                to   => $language,
            )
            ->translate($text);

        return $translation;
    }

How to use see L<Locale::Utils::Autotranslator::ApiMymemoryTranslatedNet|Locale::Utils::Autotranslator::ApiMymemoryTranslatedNet>.

    my $obj = MyAutotranslator->new(
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

Base class to translate automaticly.

=head1 SUBROUTINES/METHODS

=head2 method developer_language

Set/get the language of all msgid's. The default is 'en';

=head2 method language

Set/get the language you want to translate.

=head2 limit

E.g. you have a limit of 100 free translations in 1 day
you can run that each day with that limit.
After that method translate returns,
maybe with left untranslated messages.

You can read back the left limit and use them on other files.
It is also allowed to run method translate with limit 0 first.
Then it will translate all missing stuff to q{}.

=head2 method sleep_seconds

To prevent an attack to the translation service
you can sleep after each translation request.
Set/get the seconds here.

=head2 method debug_code

Set/get a code reference to see what text is sent to the translation service
and what you get back.

See Synopsis for parameters.

=head2 method error

Get back the error message if method translate_text dies.

=head2 method translate

    $object->translate('dir/de.pot', 'dir/de.po');

That means:
Read the de.pot file (also possible *.po).
Translate the 1st missing stuff.
Write back the de.po file.
Look for more missing translations.
Translate the next missing stuff.

Why write back so often?
If something is broken (die) during translation the error is set.

=head2 method translate_text

In base class there is only a dummy method that returns C<q{}>.

The subclass has to implement that method.
Check the code of
L<Locale::Utils::Autotranslator::ApiMymemoryTranslatedNet|Locale::Utils::Autotranslator::ApiMymemoryTranslatedNet>
to see how to implement.

=head1 EXAMPLE

Inside of this distribution is a directory named example.
Run the *.pl files.

=head1 DIAGNOSTICS

none

=head1 CONFIGURATION AND ENVIRONMENT

none

=head1 DEPENDENCIES

L<Carp|Carp>

L<Encode|Encode>

L<List::MoreUtils|List::MoreUtils>

L<Locale::PO|Locale::PO>

L<Locale::TextDomain::OO::Util::ExtractHeader|Locale::TextDomain::OO::Util::ExtractHeader>

L<Moo|Moo>

L<MooX::StrictConstructor|MooX::StrictConstructor>

L<MooX::Types::MooseLike::Base|MooX::Types::MooseLike::Base>

L<MooX::Types::MooseLike::Numeric|MooX::Types::MooseLike::Numeric>

L<Try::Tiny|Try::Tiny>

L<namespace::autoclean|namespace::autoclean>

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
