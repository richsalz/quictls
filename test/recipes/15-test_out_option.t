#! /usr/bin/env perl
# Copyright 2018 The OpenSSL Project Authors. All Rights Reserved.
#
# Licensed under the Apache License 2.0 (the "License").  You may not use
# this file except in compliance with the License.  You can obtain a copy
# in the file LICENSE in the source distribution or at
# https://www.openssl.org/source/license.html


use strict;
use warnings;

use File::Spec;
use OpenSSL::Test qw/:DEFAULT srctop_file/;
use OpenSSL::Test::Utils;

setup("test_out_option");

plan tests => 4;

# Test 1
{
    # Note that directories must end with a slash here, because of how
    # File::Spec massages them into directory specs on some platforms.
    my $path = File::Spec->canonpath('./');
    ok(!run(app([ 'openssl', 'rand', '-out', $path, '1'])),
       "invalid output path: $path");
}

# Test 2
{
    my $path = File::Spec->canonpath('randomname.bin');
    ok(run(app([ 'openssl', 'rand', '-out', $path, '1'])),
       "valid output path: $path");
}

# Test 3
{
    # Test for trying to create a file in a non-exist directory
    my $rand_path = "";
    do {
        my @chars = ("A".."Z", "a".."z", "0".."9");
        $rand_path .= $chars[rand @chars] for 1..32;
    } while (-d File::Spec->catdir('.', $rand_path));
    $rand_path .= "/randomname.bin";

    my $path = File::Spec->canonpath($rand_path);
    ok(!run(app([ 'openssl', 'rand', '-out', $path, '1'])),
       "invalid output path: $path");
}

# Test 4
SKIP: {
    skip "Can't use perl's idea of the NULL device in an explicitly cross compiled build", 1
        unless disabled('cross_compile');

    my $path = File::Spec->canonpath(File::Spec->devnull());
    ok(run(app([ 'openssl', 'rand', '-out', $path, '1'])),
       "valid output path: $path");
}

# Cleanup
END {
    unlink 'randomname.bin' if -f 'randomname.bin';
}
