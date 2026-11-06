# @summary Sidekiq worker for ontologies_api background jobs.
#
# Runs from the API capistrano release and queues jobs in the persistent redis.
#
# @param user Service account.
# @param app_root ontologies_api root holding current/.
# @param environment Rack/rails environment.
# @param redis_host Redis holding the queues.
# @param redis_port Port of that redis.
# @param redis_db Redis database index for the queues.
# @param concurrency Worker threads.
# @param parsing_concurrency Threads allowed to parse ontologies at once.
# @param log_file Stdout and stderr of the worker.
# @param bundle_bin bundler shim.
# @param log_retention_days Days of worker logs kept.
class ontoportal::sidekiq (
  String $user                     = 'ontoportal',
  Stdlib::Absolutepath $app_root   = '/opt/ontoportal/ontologies_api',
  String $environment              = 'appliance',
  Stdlib::Host $redis_host         = 'localhost',
  Stdlib::Port $redis_port         = 6379,
  Integer $redis_db                = 10,
  Integer $concurrency             = 1,
  Integer $parsing_concurrency     = 1,
  Stdlib::Absolutepath $log_file   = '/var/log/sidekiq.log',
  Stdlib::Absolutepath $bundle_bin = '/usr/local/rbenv/shims/bundle',
  Integer $log_retention_days      = 14,
) {
  systemd::unit_file { 'sidekiq.service':
    content => epp('ontoportal/sidekiq.service.epp', {
        'user'                => $user,
        'app_root'            => $app_root,
        'environment'         => $environment,
        'redis_host'          => $redis_host,
        'redis_port'          => $redis_port,
        'redis_db'            => $redis_db,
        'concurrency'         => $concurrency,
        'parsing_concurrency' => $parsing_concurrency,
        'log_file'            => $log_file,
        'bundle_bin'          => $bundle_bin,
    }),
  }
  ~> service { 'sidekiq':
    ensure => running,
    enable => true,
  }

  logrotate::rule { 'sidekiq':
    path         => $log_file,
    rotate       => $log_retention_days,
    rotate_every => 'day',
    compress     => true,
    copytruncate => true,
    missingok    => true,
  }
}
