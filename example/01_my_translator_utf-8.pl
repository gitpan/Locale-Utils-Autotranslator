#!perl -T ## no critic (TidyCode)

use strict;
use warnings;
use utf8;
use Path::Tiny qw(path);

# inlined translator package
{
    package MyTranslator;

    use strict;
    use warnings;
    use Moo;
    use Path::Tiny qw(path);

    our $VERSION = 0;

    extends qw(
        Locale::Utils::Autotranslator
    );

    my %translation_memory_of = (
        'en|de' => {
            'Number of XXXDBXZ: XXXDCXZ'                 => 'Anzahl von XXXDBXZ: XXXDCXZ',
            'Number of XXPOSTYXITEMSXZ: 1'               => 'Anzahl von XXPOSTYXITEMSXZ: 1',
            'postcard'                                   => 'Postkarte',
            'postcards'                                  => 'Postkarten',
            'Please write XXXDBXZ XXXCKXDCXZ today.'     => 'Bitte schreiben Sie XXXDBXZ heute XXXCKXDCXZ.',
            'He is overtaking the seagull named „bear“.' => 'Er überholt eine Möwe mit dem Name „Bär“.',
            'Please write XXNAMEXZ 1 postcard today.'    => 'Bitte schreiben Sie XXNAMEXZ heute 1 Postkarte.',
            'Please write XXNAMEXZ 2 postcards today.'   => 'Bitte schreiben Sie XXNAMEXZ heute 2 Postkarten.',
        },
    );

    sub translate_text {
        my ( $self, $text ) = @_;

        $self->automatic_comment('translated by: MyTranslator');
        my $language_pair = join q{|}, $self->developer_language, $self->language;
        my $translation = $translation_memory_of{$language_pair}->{$text};

        return defined $translation ? $translation : q{};
    }

    1;
}

binmode *STDOUT, ':encoding(UTF-8)';
my $obj = MyTranslator
    ->new(
        language   => 'de',
        debug_code => sub {
            my ($language, $text) = @_;
            () = print "$language: $text\n";
        },
    )
    ->translate(
        'LocaleData/untranslated de_utf-8.po',
        'LocaleData/translated de_utf-8.po',
    );

my $content = path('LocaleData/translated de_utf-8.po')->slurp_utf8;
$content =~ s{\r}{}xmsg;
() = print "\n", $content;

# $Id: $

__END__

Output:

en: Number of XXXDBXZ: XXXDCXZ
de: Anzahl von XXXDBXZ: XXXDCXZ
en: Number of XXPOSTYXITEMSXZ: 1
de: Anzahl von XXPOSTYXITEMSXZ: 1
en: postcard
de: Postkarte
en: postcards
de: Postkarten
en: Please write XXXDBXZ XXXCKXDCXZ today.
de: Bitte schreiben Sie XXXDBXZ heute XXXCKXDCXZ.
en: He is overtaking the seagull named „bear“.
de: Er überholt eine Möwe mit dem Name „Bär“.
en: Please write XXNAMEXZ 1 postcard today.
de: Bitte schreiben Sie XXNAMEXZ heute 1 Postkarte.
en: Please write XXNAMEXZ 2 postcards today.
de: Bitte schreiben Sie XXNAMEXZ heute 2 Postkarten.

msgid ""
msgstr ""
"Project-Id-Version: \n"
"POT-Creation-Date: \n"
"PO-Revision-Date: \n"
"Last-Translator: \n"
"Language-Team: \n"
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=UTF-8\n"
"Content-Transfer-Encoding: 8bit\n"
"Plural-Forms: nplurals=2; plural=n != 1;\n"

#. translated by: MyTranslator
msgid "Number of %1: %2"
msgstr "Anzahl von %1: %2"

#. translated by: MyTranslator
msgid "Number of {post items}: {count :num}"
msgstr "Anzahl von {post items}: {count :num}"

#. translated by: MyTranslator
msgid "Please write %1 %*(%2,postcard,postcards) today."
msgstr "Bitte schreiben Sie %1 heute %*(%2,Postkarte,Postkarten)."

# comment2
# comment1
#. automatic1
#. automatic2
#. translated by: MyTranslator
#: reference:3 reference:2
#: reference:1
msgid "He is overtaking the seagull named „bear“."
msgstr "Er überholt eine Möwe mit dem Name „Bär“."

#. translated by: MyTranslator
msgid "Please write {name} {count :num} postcard today."
msgid_plural "Please write {name} {count :num} postcards today."
msgstr[0] "Bitte schreiben Sie {name} heute {count :num} Postkarte."
msgstr[1] "Bitte schreiben Sie {name} heute {count :num} Postkarten."
