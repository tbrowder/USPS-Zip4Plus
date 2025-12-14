use Test;

use USPS::ZipPlus4;

plan 3;

my $client = USPS::ZipPlus4::Client.new(userid => 'TESTID');

# success fixture
{
    my $xml = slurp 't/data/success.xml';
    my $res = $client.parse-response($xml);

    isa-ok $res, USPS::ZipPlus4::Result;
    is "{$res.zip5}-{$res.zip4}", '20500-0003',
        'ZIP+4 parsed correctly';
}

# error fixture
{
    my $xml = slurp 't/data/error.xml';
    throws-like
        { $client.parse-response($xml) },
        X::USPS::ZipPlus4,
        'USPS error raised';
}
