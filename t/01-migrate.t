#!perl
use strict;
use warnings;
use FindBin qw($Bin);
use Test::More tests => 10;
use Data::Dumper;
use DBI;
use DBIx::VersionedDDL;

my $db_file = "$Bin/data/dbiv.db";

unlink $db_file if -f $db_file;

my $dbh = DBI->connect("dbi:SQLite:$db_file", "", "");

my $sv =
  DBIx::VersionedDDL->new({dbh => $dbh, ddl_dir => "$Bin/ddl_dir", debug => 0});

$sv->migrate(1);

my $version_rec = {
    'status'  => 'success',
    'version' => '1',
    'message' => undef,
};

my $version = $dbh->selectrow_hashref('select * from schema_version');
is_deeply($version, $version_rec, 'Upgrade');

my $sth = $dbh->table_info(undef, '%', 'dbiv_test', 'TABLE');
my $tab_details = $sth->fetchrow_hashref;
$sth->finish;

is($tab_details->{TABLE_NAME}, 'dbiv_test', 'Table created');

$sv->migrate(0);

$version_rec = {
    'status'  => 'success',
    'version' => '0',
    'message' => undef
};

$version = $dbh->selectrow_hashref('select * from schema_version');
is_deeply($version, $version_rec, 'Downgrade');

$sv->migrate(2);

$version = $dbh->selectrow_hashref(
    'select version, status, message from schema_version');
is($version->{status}, 'error', 'Upgrade error detected');
like(
    $version->{message},
    qr/^upgrade2.sql: DBD::SQLite::db do failed: near "\(": syntax error/,
    'Upgrade error logged'
);
is($version->{version}, 2, 'Upgrade version set');

$dbh->do(
    q{update schema_version set version = 3, status = 'success', message = null}
);

$sv->migrate(2);
$version = $dbh->selectrow_hashref(
    'select version, status, message from schema_version');

is($version->{status}, 'error', 'Downgrade error detected');
like(
    $version->{message},
    qr!^downgrade3.sql: Cannot find.*/t/ddl_dir/downgrade3.sql!,
    'Upgrade error logged'
);
is($version->{version}, 2, 'Downgrade version set');
$dbh->disconnect;

unlink $db_file || die $!;

$sv = DBIx::VersionedDDL->new(
    {dsn => "dbi:SQLite:$db_file", ddl_dir => "$Bin/ddl_dir", debug => 0});

$sv->migrate(1);

$version_rec = {
    'status'  => 'success',
    'version' => '1',
    'message' => undef,
};

$version = $sv->dbh->selectrow_hashref('select * from schema_version');
is_deeply($version, $version_rec, 'Using dsn instead of a db handle');

unlink $db_file;
