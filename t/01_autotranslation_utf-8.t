#!perl
#!perl -T

use strict;
use warnings;
use utf8;

use Moo;
use Path::Tiny qw(path);
use Test::More tests => 3;
use Test::NoWarnings;
use Test::Differences;

extends qw(
    Locale::Utils::Autotranslator
);

my $char = 1;
sub translate_text {
    my ($self, $msgid) = @_;

    return 'text ' . $char++;
}

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

msgid "Number of %1: %2"
msgstr "text 1"

msgid "Number of {post items}: {count :num}"
msgstr "text 2"

msgid "Please write %1 %*(%2,postcard,postcards) today."
msgstr "text 5"

# comment2
# comment1
#. automatic2
#. automatic1
#: reference:3 reference:2
#: reference:1
msgid "He is overtaking the seagull named „bear“."
msgstr "text 6"

msgid "Please write {name} {count :num} postcard today."
msgid_plural "Please write {name} {count :num} postcards today."
msgstr[0] "text 7"
msgstr[1] "text 8"

EOT
    'translated file content';

eq_or_diff
    \@debug,
    [
        'en: Number of XXXDBXZ: XXXDCXZ',
        'de: text 1',
        'en: Number of XXPOSTYXITEMSXZ: 1',
        'de: text 2',
        'en: postcard',
        'de: text 3',
        'en: postcards',
        'de: text 4',
        'en: Please write XXXDBXZ XXXCKXDCXZ today.',
        'de: text 5',
        'en: He is overtaking the seagull named „bear“.',
        'de: text 6',
        'en: Please write XXNAMEXZ 1 postcard today.',
        'de: text 7',
        'en: Please write XXNAMEXZ 2 postcards today.',
        'de: text 8',
    ],
    'debug';
