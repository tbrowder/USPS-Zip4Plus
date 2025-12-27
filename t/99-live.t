use Test;
use USPS::ZipPlus4;

# Run with:
#   USPS_LIVE_TEST=1 zef test .
# or:
#   make test-live

my $live = (%*ENV<USPS_LIVE_TEST> // '').Str.trim;
my $id   = (%*ENV<USPS_WEBTOOLS_USERID> // '').Str.trim;

unless $live eq '1' and $id.chars
{
    plan 1;
    skip 'Live test disabled (set USPS_LIVE_TEST=1 and USPS_WEBTOOLS_USERID)';
    exit;
}

plan 2;

my $client = USPS::ZipPlus4::Client.new(throttle-seconds => 0.2);

my $res = $client.zip4-lookup(
    street => '114 Shoreline Dr',
    city   => 'Gulf Breeze',
    state  => 'FL',
);

ok $res.zip5.chars, 'zip5 present';
ok $res.zip4.chars, 'zip4 present';
