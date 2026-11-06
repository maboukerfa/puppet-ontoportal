# @summary virtuoso.ini of one Virtuoso instance.
#
# Seeds virtuoso.ini from the shipped sample once, then pins the settings that
# differ from it: data file paths, ports and any extra $settings.
#
# @param install_dir Instance root holding database/virtuoso.ini.
# @param data_dir Where database files go.
# @param owner Owner of virtuoso.ini.
# @param sql_port isql / ODBC port ([Parameters] ServerPort).
# @param http_port HTTP / SPARQL port ([HTTPServer] ServerPort).
# @param settings Extra settings, { section => { key => value } }.
define ontoportal::virtuoso::config (
  Stdlib::Absolutepath $install_dir,
  Stdlib::Absolutepath $data_dir,
  String $owner,
  Stdlib::Port $sql_port,
  Stdlib::Port $http_port,
  Hash[String, Hash] $settings = {},
) {
  $ini = "${install_dir}/database/virtuoso.ini"

  file { $ini:
    ensure  => file,
    replace => false,
    source  => "${ini}.sample",
    owner   => $owner,
    group   => $owner,
    mode    => '0644',
  }

  # sample paths are relative to database/, point them at $data_dir instead
  $base_settings = {
    'Database'     => {
      'DatabaseFile'       => "${data_dir}/virtuoso.db",
      'ErrorLogFile'       => "${data_dir}/virtuoso.log",
      'LockFile'           => "${data_dir}/virtuoso.lck",
      'TransactionFile'    => "${data_dir}/virtuoso.trx",
      'xa_persistent_file' => "${data_dir}/virtuoso.pxa",
    },
    'TempDatabase' => {
      'DatabaseFile'    => "${data_dir}/virtuoso-temp.db",
      'TransactionFile' => "${data_dir}/virtuoso-temp.trx",
    },
    'Parameters'   => { 'ServerPort' => $sql_port },
    'HTTPServer'   => { 'ServerPort' => $http_port },
  }

  deep_merge($base_settings, $settings).each |String $section, Hash $section_settings| {
    $section_settings.each |String $key, $value| {
      ini_setting { "${title} ${section} ${key}":
        ensure  => present,
        path    => $ini,
        section => $section,
        setting => $key,
        value   => String($value),
        require => File[$ini],
      }
    }
  }
}
