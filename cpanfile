requires "Moo", ">= 2.00";              # sane minimum baseline
requires "Types::Standard", ">= 1.00";  # sane minimum baseline
requires "Scalar::Util";

on develop => sub {
    requires 'Dist::Zilla::PluginBundle::Author::GSG';
};
