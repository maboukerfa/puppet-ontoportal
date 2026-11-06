# @summary Public, read-only SPARQL endpoint fed by a nightly copy of the main store.
#
# Every night the clone script copies the main store into this instance, restarts
# it and deletes private ontologies and user metadata from the copy:
#
#   virtuoso (1111/8890) --clone_and_clean_virtuoso.sh--> virtuoso-public (2222/8891) <-- nginx sparql.<domain>
#
# @param install_dir Instance root, a copy of the main instance binaries.
# @param data_dir Where the cloned database files go.
# @param log_dir Clone script logs.
# @param user Service account; also runs the clone script.
# @param sql_port isql / ODBC port.
# @param http_port HTTP / SPARQL port, proxied by nginx.
# @param dba_password Password of the dba account, used by the clone script.
# @param clone_hour Hour of the nightly clone.
# @param clone_minute Minute of the nightly clone.
# @param log_retention_days Days of clone logs kept.
class ontoportal::virtuoso::public (
  Stdlib::Absolutepath $install_dir = '/opt/virtuoso-public',
  Stdlib::Absolutepath $data_dir    = '/srv/ontoportal/data/virtuoso-public',
  Stdlib::Absolutepath $log_dir     = '/var/log/virtuoso-public',
  String $user                      = 'ontoportal',
  Stdlib::Port $sql_port            = 2222,
  Stdlib::Port $http_port           = 8891,
  Sensitive[String] $dba_password   = Sensitive('dba'),
  Integer[0, 23] $clone_hour        = 1,
  Integer[0, 59] $clone_minute      = 3,
  Integer $log_retention_days       = 3,
) {
  $clone_script = '/usr/local/bin/clone_and_clean_virtuoso.sh'

  file { [$install_dir, $data_dir, $log_dir]:
    ensure => directory,
    owner  => $user,
    group  => $user,
    mode   => '0755',
  }

  # binaries are a plain copy of the main instance, kept in sync on version change
  exec { 'copy virtuoso binaries to virtuoso-public':
    command => "/bin/cp -a ${ontoportal::virtuoso::install_dir}/. ${install_dir}/ && /bin/chown -R ${user}:${user} ${install_dir}",
    creates => "${install_dir}/bin/virtuoso-t",
    require => [File[$install_dir], Ontoportal::Virtuoso::Config['virtuoso']],
  }

  ontoportal::virtuoso::config { 'virtuoso-public':
    install_dir => $install_dir,
    data_dir    => $data_dir,
    owner       => $user,
    sql_port    => $sql_port,
    http_port   => $http_port,
    require     => Exec['copy virtuoso binaries to virtuoso-public'],
  }

  systemd::unit_file { 'virtuoso-public.service':
    content => epp('ontoportal/virtuoso.service.epp', {
        'description' => 'Public Virtuoso Database Server',
        'user'        => $user,
        'install_dir' => $install_dir,
        'exec_stop'   => "${install_dir}/bin/isql ${sql_port} \"EXEC=shutdown;\"",
        'restart'     => 'no',
    }),
  }
  ~> service { 'virtuoso-public':
    ensure    => running,
    enable    => true,
    subscribe => Ontoportal::Virtuoso::Config['virtuoso-public'],
  }

  file { $clone_script:
    ensure  => file,
    owner   => $user,
    group   => $user,
    mode    => '0750',
    content => epp('ontoportal/clone_and_clean_virtuoso.sh.epp', {
        'src_install_dir'  => $ontoportal::virtuoso::install_dir,
        'src_data_dir'     => $ontoportal::virtuoso::data_dir,
        'dest_install_dir' => $install_dir,
        'dest_data_dir'    => $data_dir,
        'log_dir'          => $log_dir,
        'sql_port'         => $sql_port,
        'http_port'        => $http_port,
        'dba_password'     => $dba_password,
    }),
  }

  cron::job { 'virtuoso-public-clone':
    command => $clone_script,
    user    => $user,
    hour    => $clone_hour,
    minute  => $clone_minute,
    require => File[$clone_script],
  }

  cron::job { 'virtuoso-public-logs':
    command => "/usr/bin/find ${log_dir} -mindepth 1 -mtime +${log_retention_days} -delete",
    hour    => 23,
    minute  => 0,
  }
}
