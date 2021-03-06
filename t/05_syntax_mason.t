#!/usr/bin/perl

use strict;
use warnings;
use File::Spec::Functions qw<catfile catdir>;
use Test::More tests => 3; # can we upgrade to 0.88 and use done_testing?
use Test::Differences;
use Text::VimColor;

# hack to work around a silly limitation in Text::VimColor,
# will remove it when Text::VimColor has been patched
{
    package TrueHash;
    use base 'Tie::StdHash';
    sub EXISTS { return 1 };
}
tie %Text::VimColor::SYNTAX_TYPE, 'TrueHash';

my $lang = 'mason';
my $syntax_file   = catfile('syntax', "$lang.vim");
my $color_file    = catfile('t', 'define_all.vim');

sub parse_string {
    my ($string, $scripts) = @_;
    my $syntax = Text::VimColor->new(
        string => $string,
        vim_options => [
            qw(-RXZ -i NONE -u NONE -U NONE -N -n), # for performance
            '+set nomodeline',          # for performance
            '+set runtimepath=.',       # don't consider system runtime files
            @{ $scripts || [] },
            "+source $syntax_file",
            "+source $color_file",      # all syntax classes should be defined
        ],
    );
    return $syntax->marked;
}

eq_or_diff
    parse_string(<<MASON),
<%method title>Home</%method>
<h1><%perl>print "foobar";</%perl></h1>
MASON
    [
        [ Delimiter   => '<%method title>'  ],
        [ masonMethod => 'Home'   ],
        [ Delimiter   => '</%method>'    ],
        [ ''          => "\n<h1>"    ],
        [ Delimiter   => '<%perl>'  ],
        [ Statement   => "print" ],
        [ masonPerl   => ' '  ],
        [ String      => '"foobar"' ],
        [ masonPerl   => ';'  ],
        [ Delimiter   => "</%perl>" ],
        [ ''          => "</h1>\n"  ],
    ],
    'basic Template syntax';

eq_or_diff
    parse_string(<<MASON),
<%init>
=for foobar
some docs
=cut
print "foo";
</%init>
MASON
    [
        [ Delimiter   => '<%init>'  ],
        [ ''          => "\n"       ],
        [ Statement   => '=for'     ],
        [ Comment     => ' '        ],
        [ Identifier  => 'foobar'   ],
        [ ''          => "\n"       ],
        [ Comment     => 'some docs'],
        [ ''          => "\n"       ],
        [ Statement   => '=cut'     ],
        [ ''          => "\n"       ],
        [ Statement   => 'print'    ],
        [ masonInit   => ' '        ],
        [ String      => '"foo"'    ],
        [ masonInit   => ';'        ],
        [ ''          => "\n"       ],
        [ Delimiter   => '</%init>' ],
        [ ''          => "\n"       ],
    ],
    'basic Template syntax';

eq_or_diff
    parse_string(<<'MASON'),
% if ($boolean) {
<li>hello</li>
% }
<& SELF:header &>
MASON
    [
        [ Delimiter       => '%'],
        [ masonLine       => ' '],
        [ Conditional     => 'if'],
        [ masonLine       => ' ('],
        [ Identifier      => '$boolean'],
        [ masonLine       => ') '],
        [ masonPerlBraces => '{'],
        [ ''              => "\n<li>hello</li>\n"],
        [ Delimiter       => "%"],
        [ masonLine       => ' }'],
        [ ''              => "\n"],
        [ Delimiter       => "<& SELF:header"],
        [ masonComp       => ' '],
        [ Delimiter       => "&>"],
        [ ''              => "\n"],
    ],
    'basic Template syntax';

# TODO: done_testing;
