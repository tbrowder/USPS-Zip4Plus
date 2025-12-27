# Convenience targets for USPS::ZipPlus4
# Uses zef test under the hood

.PHONY: test test-live test-live-debug clean live-test live-test-debug

test:
	zef test .

test-live:
	USPS_LIVE_TEST=1 zef test .

test-live-debug:
	USPS_LIVE_TEST=1 USPS_WEBTOOLS_ENDPOINT=https://production.shippingapis.com/ShippingAPI.dll zef test .

clean:
	rm -rf .precomp

live-test:
	USPS_LIVE_TEST=1 zef test .

live-test-debug:
	USPS_LIVE_TEST=1 USPS_WEBTOOLS_ENDPOINT=https://production.shippingapis.com/ShippingAPI.dll zef test .
