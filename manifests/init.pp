# Class repodeploy
#
# This class deploys repos by the vcsrepo module but configureable via a hash
#
# Parameters:
#   $repos = hiera('repodeploy::repos', false),
#   $include_base_path = hiera('repodeploy::include_base_path', '/opt/puppet-modules-vcsrepo'),
#
class repodeploy(
  $include_base_path = hiera('repodeploy::include_base_path', '/opt/puppet-modules-vcsrepo'),
) {
  $repos = hiera_hash('repodeploy::repos', {})

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
    if $repos[$name]['ensure'] {
      $ensure = $repos[$name]['ensure']
    } else {
      $ensure = 'present'
    }


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

    $post_checkout_hook = "$name/.git/hooks/post-checkout"

    if $repos[$name]['post-checkout'] {
      $post_checkout = $repos[$name]['post-checkout']
    } else {
      $post_checkout = undef
    }

    if $repos[$name]['source'] {
      $source = $repos[$name]['source']
    } else {
      fail('You need to provide a source as parameter!')
    }

    if $post_checkout {
    vcsrepo { $name:
      ensure   => $ensure,
      provider => $provider,
      source   => $source,
      revision => $revision,
      notify   => File[$post_checkout_hook],
    }

    # Install a post-checkout hook for building documentation...

    file { "$name/.git/hooks/post-checkout":
      ensure  => file,
      mode    => '0755',
      content => inline_template($post_checkout),
      }

    # ...and ensure it gets run upon the repository's initial checkout

    exec { "$name/.git/hooks/post-checkout":
      subscribe   => File["$name/.git/hooks/post-checkout"],
      refreshonly => true,
    }
  } else {
      vcsrepo { $name:
          ensure   => $ensure,
          provider => $provider,
          source   => $source,
          revision => $revision,
          # Remove hook before checkout if it has been deconfigured:
          require  => File[$post_checkout_hook],
        }

        # Remove post-checkout hook if one exists.

        file { $post_checkout_hook:
          ensure  => absent,
          }
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
    }
  }

  if $repos {
    $repos_keys = keys($repos)
    deploy_repo { $repos_keys:
      repos             => $repos,
      include_base_path => $include_base_path,
    }
  }

  ensure_packages(['myrepos'])

  # Create mrconfig entries for all repositories.

  file{'/root/.mrconfig':
    ensure  => file,
    mode    => '0600',
    content => template("$module_name/mrconfig.erb"),
  }

}
