# @summary OFAIRe (fairness-assessment) webapp: API route and nightly score cache.
#
# The war itself is built from github.com/agroportal/fairness and deployed by hand
# into tomcat; this class wires everything around it:
#
#   https://<api domain>/ofaire/ --nginx--> tomcat :8082/fairness-assessment/
#   00:00 cache_reset.sh --> recomputes the scores of every ontology
#
# cache_reset.sh is a copy of cron/cache_reset.sh from the fairness repository.
#
# @param webapp Tomcat context name of the war.
# @param user Account running the nightly cache refresh.
# @param tomcat_port Tomcat HTTP connector.
# @param cache_hour Hour of the nightly cache refresh.
# @param cache_minute Minute of the nightly cache refresh.
# @param log_dirs Cache refresh logs, purged after $log_retention_days.
# @param log_retention_days Days of cache refresh logs kept.
class ontoportal::fairness (
  String $webapp                        = 'fairness-assessment',
  String $user                          = 'ontoportal',
  Stdlib::Port $tomcat_port             = 8082,
  Integer[0, 23] $cache_hour            = 0,
  Integer[0, 59] $cache_minute          = 0,
  Array[Stdlib::Absolutepath] $log_dirs = ['/var/log/tomcat/FAIR_CACHE', '/var/log/tomcat/log/FAIR_CACHE'],
  Integer $log_retention_days           = 3,
) {
  $cache_script = '/usr/local/bin/cache_reset.sh'
  $war_dir = "${ontoportal::tomcat::catalina_base}/webapps/${webapp}"

  file { $cache_script:
    ensure => file,
    owner  => $user,
    group  => $user,
    mode   => '0755',
    source => 'puppet:///modules/ontoportal/usr/local/bin/cache_reset.sh',
  }

  cron::job { 'ofaire-cache-reset':
    command => "${cache_script} ${war_dir}",
    user    => $user,
    hour    => $cache_hour,
    minute  => $cache_minute,
    require => File[$cache_script],
  }

  cron::job { 'ofaire-cache-logs':
    command => "/usr/bin/find ${join($log_dirs, ' ')} -mindepth 1 -mtime +${log_retention_days} -delete",
    hour    => 23,
    minute  => 0,
  }

  nginx::resource::location { '/ofaire/':
    ensure => present,
    ssl    => true,
    server => 'ontologies_api',
    proxy  => "http://localhost:${tomcat_port}/${webapp}/",
  }
}
