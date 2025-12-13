use Test;

my @modules = <
    USPS::ZipPlus4
>;

plan @modules.elems;

for @modules -> $m {
    use-ok $m, "Module '$m' used okay";
}
