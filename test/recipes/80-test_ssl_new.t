#! /usr/bin/env perl
# Copyright 2015-2023 The OpenSSL Project Authors. All Rights Reserved.
#
# Licensed under the Apache License 2.0 (the "License").  You may not use
# this file except in compliance with the License.  You can obtain a copy
# in the file LICENSE in the source distribution or at
# https://www.openssl.org/source/license.html

# For manually running these tests, set specific environment variables like this:
# CTLOG_FILE=test/ct/log_list.cnf
# TEST_CERTS_DIR=test/certs
# For details on the environment variables needed, see test/README.ssltest.md

use strict;
use warnings;

use File::Basename;
use File::Compare qw/compare_text/;
use OpenSSL::Test qw/:DEFAULT srctop_dir srctop_file bldtop_file bldtop_dir/;
use OpenSSL::Test::Utils;

BEGIN {
setup("test_ssl_new");
}

use lib srctop_dir('Configurations');
use lib bldtop_dir('.');

my $no_fips = disabled('fips') || ($ENV{NO_FIPS} // 0);

$ENV{TEST_CERTS_DIR} = srctop_dir("test", "certs");

my @conf_srcs = ();
if (defined $ENV{SSL_TESTS}) {
    my @conf_list = split(' ', $ENV{SSL_TESTS});
    foreach my $conf_file (@conf_list) {
        push (@conf_srcs, glob(srctop_file("test", "ssl-tests", $conf_file)));
    }
    plan tests => scalar @conf_srcs;
} else {
    @conf_srcs = glob(srctop_file("test", "ssl-tests", "*.cnf.dat"));
    # We hard-code the number of tests to double-check that the globbing above
    # finds all files as expected.
    plan tests => 28;
}
my @conf_files = map { basename($_, ".dat") } @conf_srcs;


# Some test results depend on the configuration of enabled protocols. We only
# verify generated sources in the default configuration.
my $is_default_tls = (disabled("ssl3") && !disabled("tls1") &&
                      !disabled("tls1_1") && !disabled("tls1_2") &&
                      (!disabled("ec") || !disabled("dh")));

my $is_default_dtls = (!disabled("dtls1") && !disabled("dtls1_2"));

my @all_pre_tls1_3 = ("ssl3", "tls1", "tls1_1", "tls1_2");
my $no_tls = alldisabled(available_protocols("tls"));
my $no_tls_below1_3 = $no_tls || disabled("tls1_2");
if (!$no_tls && $no_tls_below1_3 && disabled("ec") && disabled("dh")) {
  $no_tls = 1;
}
my $no_pre_tls1_3 = alldisabled(@all_pre_tls1_3);
my $no_dtls = alldisabled(available_protocols("dtls"));
my $no_ct = disabled("ct");
my $no_ec = disabled("ec");
my $no_dh = disabled("dh");
my $no_dsa = disabled("dsa");
my $no_ocsp = disabled("ocsp");

# Add your test here if the test conf.in generates test cases and/or
# expectations dynamically based on the OpenSSL compile-time config.
my %conf_dependent_tests = (
  "02-protocol-version.cnf" => !$is_default_tls,
  "04-client_auth.cnf" => !$is_default_tls || !$is_default_dtls,
  "05-sni.cnf" => disabled("tls1_1"),
  "07-dtls-protocol-version.cnf" => !$is_default_dtls,
  "10-resumption.cnf" => !$is_default_tls || $no_ec,
  "11-dtls_resumption.cnf" => !$is_default_dtls,
  "16-dtls-certstatus.cnf" => !$is_default_dtls,
  "17-renegotiate.cnf" => disabled("tls1_2"),
  "18-dtls-renegotiate.cnf" => disabled("dtls1_2"),
  "19-mac-then-encrypt.cnf" => !$is_default_tls,
  "20-cert-select.cnf" => !$is_default_tls || $no_dh || $no_dsa,
  "22-compression.cnf" => !$is_default_tls,
  "25-cipher.cnf" => disabled("poly1305") || disabled("chacha"),
  "27-ticket-appdata.cnf" => !$is_default_tls,
  "28-seclevel.cnf" => disabled("tls1_2") || $no_ec,
  "30-extended-master-secret.cnf" => disabled("tls1_2"),
  "32-compressed-certificate.cnf" => disabled("comp")
);

# Add your test here if it should be skipped for some compile-time
# configurations. Default is $no_tls but some tests have different skip
# conditions.
my %skip = (
  "06-sni-ticket.cnf" => $no_tls_below1_3,
  "07-dtls-protocol-version.cnf" => $no_dtls,
  "10-resumption.cnf" => disabled("tls1_1") || disabled("tls1_2"),
  "11-dtls_resumption.cnf" => disabled("dtls1") || disabled("dtls1_2"),
  "12-ct.cnf" => $no_tls || $no_ct || $no_ec,
  # We could run some of these tests without TLS 1.2 if we had a per-test
  # disable instruction but that's a bizarre configuration not worth
  # special-casing for.
  # TODO(TLS 1.3): We should review this once we have TLS 1.3.
  "13-fragmentation.cnf" => disabled("tls1_2"),
  "14-curves.cnf" => disabled("tls1_2")
                     || $no_ec || $no_dh,
  "15-certstatus.cnf" => $no_tls || $no_ocsp,
  "16-dtls-certstatus.cnf" => $no_dtls || $no_ocsp,
  "17-renegotiate.cnf" => $no_tls_below1_3,
  "18-dtls-renegotiate.cnf" => $no_dtls,
  "19-mac-then-encrypt.cnf" => $no_pre_tls1_3,
  "20-cert-select.cnf" => disabled("tls1_2") || $no_ec,
  "21-key-update.cnf" => ($no_ec && $no_dh),
  "22-compression.cnf" => disabled("zlib") || $no_tls,
  "24-padding.cnf" => ($no_ec && $no_dh),
  "25-cipher.cnf" => disabled("ec") || disabled("tls1_2"),
  "26-tls13_client_auth.cnf" => ($no_ec && $no_dh),
  "32-compressed-certificate.cnf" => disabled("comp"),
);

foreach my $conf (@conf_files) {
    subtest "Test configuration $conf" => sub {
        plan tests => 2 + ($no_fips ? 0 : 3);
        test_conf($conf,
                  0, # WAS: $conf_dependent_tests{$conf}
                  defined($skip{$conf}) ? $skip{$conf} : $no_tls,
                  "none");
        test_conf($conf,
                  0,
                  defined($skip{$conf}) ? $skip{$conf} : $no_tls,
                  "default");
        test_conf($conf,
                  0,
                  defined($skip{$conf}) ? $skip{$conf} : $no_tls,
                  "fips") unless $no_fips;
    }
}

sub test_conf {
    my ($conf, $check_source, $skip, $provider) = @_;

    my $conf_file = srctop_file("test", "ssl-tests", $conf);
    my $input_file = $conf_file . ".dat";
    my $output_file = $conf . "." . $provider;
    my $run_test = 1;

  SKIP: {
      # Test 3. Run the test.
      skip "No tests available; skipping tests", 1 if $skip;
      skip "Stale sources; skipping tests", 1 if !$run_test;

      my $msg = "running CTLOG_FILE=". $ENV{CTLOG_FILE}.
          " TEST_CERTS_DIR=". $ENV{TEST_CERTS_DIR}.
          " test/ssl_test $conf_file $provider";
      if ($provider eq "fips") {
          ok(run(test(["ssl_test", $output_file, $provider,
                       srctop_file("test", "fips-and-base.cnf")])), $msg);
      } else {
          ok(run(test(["ssl_test", $conf_file, $provider])), $msg);
      }
    }
}

sub cmp_text {
    return compare_text(@_, sub {
        $_[0] =~ s/\R//g;
        $_[1] =~ s/\R//g;
        return $_[0] ne $_[1];
    });
}
