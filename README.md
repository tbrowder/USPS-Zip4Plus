[![Actions Status](https://github.com/tbrowder/USPS-Zip4Plus/actions/workflows/linux.yml/badge.svg)](https://github.com/tbrowder/USPS-Zip4Plus/actions) [![Actions Status](https://github.com/tbrowder/USPS-Zip4Plus/actions/workflows/macos.yml/badge.svg)](https://github.com/tbrowder/USPS-Zip4Plus/actions) [![Actions Status](https://github.com/tbrowder/USPS-Zip4Plus/actions/workflows/windows.yml/badge.svg)](https://github.com/tbrowder/USPS-Zip4Plus/actions)

NAME
====

**USPS::ZipPlus4** - Provides USPS validation of Zip+4 number given a valid US address with only a Zip number

SYNOPSIS
========

```raku
use USPS::ZipPlus4;
```

DESCRIPTION
===========

**USPS::ZipPlus4** is ...

Authentication
--------------

Set your USPS Web Tools USERID as an environment variable:

    export USPS_WEBTOOLS_USERID="your-userid"

The ZIP+4 lookup API uses only the USERID.

AUTHOR
======

Tom Browder <tbrowder@acm.org>

COPYRIGHT AND LICENSE
=====================

© 2025 Tom Browder

This library is free software; you may redistribute it or modify it under the Artistic License 2.0.

