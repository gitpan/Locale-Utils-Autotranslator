#!perl
#!perl -T

use strict;
use warnings;
use utf8;

use Moo;
use Path::Tiny qw(path);
use Test::More;
BEGIN {
    $ENV{AUTHOR_TESTING}
        or plan skip_all => 'Author test. Set $ENV{AUTHOR_TESTING} to a true value to run.';
    plan tests => 3;
}
use Test::NoWarnings;
use Test::Differences;

extends qw(
    Locale::Utils::Autotranslator::ApiMymemoryTranslatedNet
);

my @debug;
my $obj = __PACKAGE__
    ->new(
        language   => 'de',
        debug_code => sub {
            my ($language, $text) = @_;
            push @debug, "$language: $text";
        },
    )
    ->translate(
        't/LocaleData/untranslated de_utf-8.po',
        './translated de_utf-8.po',
    );

my $filename = './translated de_utf-8.po';
my $content = path($filename)->slurp_utf8;
unlink $filename;
$content =~ s{\r}{}xmsg;

eq_or_diff
    $content,
    <<"EOT",
msgid ""
msgstr ""
"Project-Id-Version: \\n"
"POT-Creation-Date: \\n"
"PO-Revision-Date: \\n"
"Last-Translator: \\n"
"Language-Team: \\n"
"MIME-Version: 1.0\\n"
"Content-Type: text/plain; charset=UTF-8\\n"
"Content-Transfer-Encoding: 8bit\\n"
"Plural-Forms: nplurals=2; plural=n != 1;\\n"

#. translated by: api.mymemory.translated.net
msgid "Number of %1: %2"
msgstr "Anzahl der %1: %2"

#. translated by: api.mymemory.translated.net
msgid "Number of {post items}: {count :num}"
msgstr "Anzahl {post items}: {count :num}"

#. translated by: api.mymemory.translated.net
msgid "Please write %1 %*(%2,postcard,postcards) today."
msgstr "Bitte schreiben Sie %1 %*(%2,Postkarte,Postkarten) heute."

# comment2
# comment1
#. automatic1
#. automatic2
#. translated by: api.mymemory.translated.net
#: reference:3 reference:2
#: reference:1
msgid "He is overtaking the seagull named „bear“."
msgstr "Er ist Überholen der Möwe mit dem Namen \\"Bär\\"."

#. translated by: api.mymemory.translated.net
msgid "Please write {name} {count :num} postcard today."
msgid_plural "Please write {name} {count :num} postcards today."
msgstr[0] "Bitte schreiben Sie {name} {count :num} Postkarte heute."
msgstr[1] "Bitte schreiben Sie {name} {count :num} postkarten heute."

EOT
    'translated file content';

eq_or_diff
    \@debug,
    [
        'en: Number of XXXDBXZ: XXXDCXZ',
        'de: Anzahl der XXXDBXZ: XXXDCXZ',
        'en: Number of XXPOSTYXITEMSXZ: 1',
        'de: Anzahl XXPOSTYXITEMSXZ: 1',
        'en: postcard',
        'de: Postkarte',
        'en: postcards',
        'de: Postkarten',
        'en: Please write XXXDBXZ XXXCKXDCXZ today.',
        'de: Bitte schreiben Sie XXXDBXZ XXXCKXDCXZ heute.',
        'en: He is overtaking the seagull named „bear“.',
        'de: Er ist Überholen der Möwe mit dem Namen "Bär".',
        'en: Please write XXNAMEXZ 1 postcard today.',
        'de: Bitte schreiben Sie XXNAMEXZ 1 Postkarte heute.',
        'en: Please write XXNAMEXZ 2 postcards today.',
        'de: Bitte schreiben Sie XXNAMEXZ 2 postkarten heute.',
    ],
    'debug';
