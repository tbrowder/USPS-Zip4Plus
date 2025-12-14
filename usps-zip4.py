#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import sys
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass


DEFAULT_USPS_URL = "https://production.shippingapis.com/ShippingAPI.dll"


@dataclass(frozen=True)
class Zip4Result:
    street1: str
    street2: str
    city: str
    state: str
    zip5: str
    zip4: str

    @property
    def zip9(self) -> str:
        return f"{self.zip5}-{self.zip4}"


class UspsError(RuntimeError):
    pass


def _xml_text(parent: ET.Element, tag: str) -> str:
    node = parent.find(tag)
    return (node.text or "").strip() if node is not None else ""


def zip4_lookup(*, street: str, city: str, state: str, street2: str = "", debug: bool = False) -> Zip4Result:
    userid = os.environ.get("USPS_WEBTOOLS_USERID", "").strip()
    if not userid:
        raise UspsError("Missing USPS_WEBTOOLS_USERID environment variable")

    password = os.environ.get("USPS_WEBTOOLS_PASSWORD", "").strip()

    attrs = {"USERID": userid}
    if password:
        attrs["PASSWORD"] = password

    # USPS Web Tools ZipCodeLookup:
    # Address1 = secondary (APT/STE), Address2 = street line
    root = ET.Element("ZipCodeLookupRequest", attrs)
    addr = ET.SubElement(root, "Address", {"ID": "0"})
    ET.SubElement(addr, "Address1").text = street2
    ET.SubElement(addr, "Address2").text = street
    ET.SubElement(addr, "City").text = city
    ET.SubElement(addr, "State").text = state
    xml_str = ET.tostring(root, encoding="unicode")

    endpoint = os.environ.get("USPS_WEBTOOLS_ENDPOINT", "").strip() or DEFAULT_USPS_URL

    query = {"API": "ZipCodeLookup", "XML": xml_str}
    url = endpoint + "?" + urllib.parse.urlencode(query)

    with urllib.request.urlopen(url, timeout=20) as resp:
        body = resp.read().decode("utf-8", errors="replace")

    if debug:
        print("=== USPS RAW RESPONSE BEGIN ===", file=sys.stderr)
        print(body, file=sys.stderr)
        print("=== USPS RAW RESPONSE END ===", file=sys.stderr)

    try:
        doc = ET.fromstring(body)
    except ET.ParseError:
        raise UspsError("USPS returned non-XML response (use --debug to inspect raw body)")

    def raise_usps_error(err_elem: ET.Element) -> None:
        number = _xml_text(err_elem, "Number")
        desc = _xml_text(err_elem, "Description")

        if number == "80040B1A":
            raise UspsError(
                "USPS authorization failure (80040B1A). This often means your Web Tools USERID "
                "has not been activated for production yet, or your environment variables are "
                "not set as expected."
            )

        raise UspsError(f"USPS error {number}: {desc}")

    # Error can be root <Error> or nested <Error>
    if doc.tag == "Error":
        raise_usps_error(doc)

    err = doc.find(".//Error")
    if err is not None:
        raise_usps_error(err)

    out_addr = doc.find(".//Address")
    if out_addr is None:
        raise UspsError("Unexpected USPS response: missing Address element (use --debug)")

    zip5 = _xml_text(out_addr, "Zip5")
    zip4 = _xml_text(out_addr, "Zip4")
    if not zip5 or not zip4:
        raise UspsError("No ZIP+4 returned (address may be incomplete/invalid)")

    return Zip4Result(
        street1=_xml_text(out_addr, "Address2"),
        street2=_xml_text(out_addr, "Address1"),
        city=_xml_text(out_addr, "City"),
        state=_xml_text(out_addr, "State"),
        zip5=zip5,
        zip4=zip4,
    )


def _prompt(label: str) -> str:
    return input(label).strip()


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        prog="usps-zip4",
        description="Look up USPS ZIP+4 for a street address (Web Tools ZipCodeLookup).",
    )
    ap.add_argument("--street", help="Street address line (e.g., '123 Main St')")
    ap.add_argument("--street2", default="", help="Secondary/unit (e.g., 'Apt 5B', 'Ste 200')")
    ap.add_argument("--city", help="City")
    ap.add_argument("--state", help="State (2-letter)")
    ap.add_argument("--throttle", type=float, default=0.2, help="Sleep seconds before request (default: 0.2)")
    ap.add_argument("--raw", action="store_true", help="Print normalized fields + ZIP components on separate lines")
    ap.add_argument("--debug", action="store_true", help="Print raw USPS response for troubleshooting")

    ns = ap.parse_args(argv)

    street = ns.street or _prompt("Street (line 1): ")
    street2 = ns.street2 or _prompt("Street (line 2 / Apt/Ste) [optional]: ")
    city = ns.city or _prompt("City: ")
    state = ns.state or _prompt("State (2-letter): ")

    if ns.throttle and ns.throttle > 0:
        time.sleep(ns.throttle)

    try:
        r = zip4_lookup(street=street, street2=street2, city=city, state=state, debug=ns.debug)
    except UspsError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2

    if ns.raw:
        print(f"street1={r.street1}")
        print(f"street2={r.street2}")
        print(f"city={r.city}")
        print(f"state={r.state}")
        print(f"zip5={r.zip5}")
        print(f"zip4={r.zip4}")
    else:
        print(f"{r.zip9}  |  {r.street1}  |  {r.city}, {r.state}")
        if r.street2:
            print(f"           {r.street2}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
