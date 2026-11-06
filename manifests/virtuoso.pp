# @summary Virtuoso Open Source triple store, the AgroPortal replacement for AllegroGraph.
#
# Code and data live apart so the binaries can be upgraded without touching the store:
#
#   /opt/virtuoso                   upstream generic build + database/virtuoso.ini
#   /srv/ontoportal/data/virtuoso   virtuoso.db, .trx, .log
#
# Not automated: granting SPARQL_UPDATE to the SPARQL user (see the migration wiki page).
#
# @param version Virtuoso release to download.
# @param source_url Tarball of the generic linux build.
# @param install_dir Where the binaries and virtuoso.ini go.
# @param data_dir Where the database files go.
# @param user Service account.
# @param sql_port isql / ODBC port.
# @param http_port HTTP / SPARQL port.
# @param number_of_buffers Page buffers, 680000 fits ~8G of RAM.
# @param max_dirty_buffers Dirty page threshold before flushing.
# @param result_set_max_rows SPARQL row cap.
# @param log_retention_days Days of virtuoso.log kept by logrotate.
# @param public_mirror present: nightly read-only copy for the public SPARQL endpoint.
class ontoportal::virtuoso (
  String $version                          = '7.2.14',
  Stdlib::HTTPSUrl $source_url             = "https://github.com/openlink/virtuoso-opensource/releases/download/v${version}/virtuoso-opensource.x86_64-generic_glibc25-linux-gnu.tar.gz",
  Stdlib::Absolutepath $install_dir        = '/opt/virtuoso',
  Stdlib::Absolutepath $data_dir           = '/srv/ontoportal/data/virtuoso',
  String $user                             = 'virtuoso',
  Stdlib::Port $sql_port                   = 1111,
  Stdlib::Port $http_port                  = 8890,
  Integer $number_of_buffers               = 680000,
  Integer $max_dirty_buffers               = 500000,
  Integer $result_set_max_rows             = 10000000000,
  Integer $log_retention_days              = 30,
  Enum['present', 'absent'] $public_mirror = 'absent',
) {
  # isql of the generic build links against ncurses 5
  stdlib::ensure_packages(['libncurses5'])

  group { $user:
    ensure => present,
    system => true,
  }

  user { $user:
    ensure  => present,
    system  => true,
    gid     => $user,
    home    => $install_dir,
    shell   => '/usr/sbin/nologin',
    require => Group[$user],
  }

  file { [$install_dir, $data_dir]:
    ensure  => directory,
    owner   => $user,
    group   => $user,
    mode    => '0755',
    require => User[$user],
  }

  # tarball top dir is virtuoso-opensource/, strip it to land in $install_dir
  archive { "/var/tmp/virtuoso-opensource-${version}.tar.gz":
    source          => $source_url,
    extract         => true,
    extract_path    => $install_dir,
    extract_command => 'tar xzf %s --strip-components=1',
    creates         => "${install_dir}/bin/virtuoso-t",
    cleanup         => true,
    user            => $user,
    group           => $user,
    require         => File[$install_dir],
  }

  ontoportal::virtuoso::config { 'virtuoso':
    install_dir => $install_dir,
    data_dir    => $data_dir,
    owner       => $user,
    sql_port    => $sql_port,
    http_port   => $http_port,
    settings    => {
      'Parameters' => {
        'NumberOfBuffers' => $number_of_buffers,
        'MaxDirtyBuffers' => $max_dirty_buffers,
      },
      'HTTPServer' => { 'EnableRequestTrap' => 1 },
      'SPARQL'     => { 'ResultSetMaxRows' => $result_set_max_rows },
    },
    require     => Archive["/var/tmp/virtuoso-opensource-${version}.tar.gz"],
  }

  systemd::unit_file { 'virtuoso.service':
    content => epp('ontoportal/virtuoso.service.epp', {
        'description' => 'Virtuoso Database Server',
        'user'        => $user,
        'install_dir' => $install_dir,
        'exec_stop'   => undef,
        'restart'     => 'on-failure',
    }),
  }
  ~> service { 'virtuoso':
    ensure    => running,
    enable    => true,
    subscribe => Ontoportal::Virtuoso::Config['virtuoso'],
  }

  # virtuoso keeps the log open, hence copytruncate
  logrotate::rule { 'virtuoso':
    path         => "${data_dir}/virtuoso.log",
    rotate       => $log_retention_days,
    rotate_every => 'day',
    compress     => true,
    copytruncate => true,
    dateext      => true,
    missingok    => true,
    ifempty      => false,
    su           => true,
    su_user      => $user,
    su_group     => $user,
  }

  if $public_mirror == 'present' {
    contain ontoportal::virtuoso::public
  }
}
