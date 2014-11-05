#!perl

use strict;
use warnings;
use utf8;

use Test::More;
use Test::Differences;
use Cwd qw(getcwd chdir);
use Encode qw(decode_utf8);

$ENV{AUTHOR_TESTING}
    or plan skip_all => 'Set $ENV{AUTHOR_TESTING} to run this test.';

my @data = (
    {
        test   => '01_my_translator',
        path   => 'example',
        script => '-I../lib -T 01_my_translator_utf-8.pl',
        result => <<'EOT',
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

EOT
    },
);

plan tests => 0 + @data;

for my $data (@data) {
    my $dir = getcwd;
    chdir("$dir/$data->{path}");
    my $result = decode_utf8( qx{perl $data->{script} 2>&3} );
    chdir($dir);
    #$result =~ tr{\\}{/};
    eq_or_diff(
        $result,
        $data->{result},
        $data->{test},
    );
}
