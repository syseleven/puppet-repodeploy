# Class repodeploy
#
# This class deploys repos by the vcsrepo module but configureable via a hash
#
# Parameters:
#   $repos = hiera('repodeploy::repos', false),
#   $include_base_path = hiera('repodeploy::include_base_path', '/opt/puppet-modules-vcsrepo'),
#
class repodeploy(
  $repos = hiera('repodeploy::repos', false),
  $include_base_path = hiera('repodeploy::include_base_path', '/opt/puppet-modules-vcsrepo'),
) {
  define copy_directory(
    $source,
    $include_base_path = undef,
  ) {
    $path = split($title, '/')
    file { "${include_base_path}/${path[-1]}":
      ensure  => directory,
      source  => "$source/$title",
      recurse => true,
    }
  }

  define deploy_repo(
    $repos,
    $include_base_path = undef,
  ) {
    if $repos[$name]['provider'] {
      $provider = $repos[$name]['provider']
    } else {
      $provider = 'git'
    }

    if $repos[$name]['revision'] {
      $revision = $repos[$name]['revision']
    } else {
      $revision = undef
    }


    if $repos[$name]['source'] {
      $source = $repos[$name]['source']
    } else {
      fail('You need to provide a source as parameter!')
    }

    vcsrepo { $name:
      ensure   => present,
      provider => $provider,
      source   => $source,
      revision => $revision,
    }

    if $repos[$name]['include'] {
      file {$include_base_path:
        ensure => directory,
      }
      copy_directory { $repos[$name]['include']:
        source            => $name,
        include_base_path => $include_base_path,
        require           => Vcsrepo[$name],
      }

      exec{"mr register ${repos[$name]['include']}":
        require     => Package['myrepos'],
        subscribe   => Copy_directory["$repos[$name]['include']"],
        refreshonly => true,
        }

    }
    else {
      exec{"mr register $name":
        subscribe   => Vcsrepo[$name],
        refreshonly => true,
      }
    }
  }

  if $repos {
    $repos_keys = keys($repos)
    deploy_repo { $repos_keys:
      repos             => $repos,
      include_base_path => $include_base_path,
    }
  }

  package{'myrepos': }
}
