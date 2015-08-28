# This class uses the vcsrepo module to deploy repositories. Unlike vcsrepo it
# is driven by a hash, i.e. its $repos parameter can include an arbitrary
# number of repositories. Other features include a per-repository post-checkout
# hook and a mechanism for extracting arbitrary directories from repositories.
# As an added benefit it will install mr(1) and generate a ~/.mrconfig
# containing all repositories managed by repodeploy.
# 
# The hash of repositories must be supplied through the Hiera key
# `repodeploy::repos` and can not be passed to repodeploy directly. A regular
# hash merge (not a deep merge) will be performed on this Hiera key.
# 
# `repodeploy::repos` is keyed by file system path (i.e. the directory to clone
# the repository in question into). Its values are themselves hashes with the
# following keys:
# 
# source:: The Repository's source URL.
#
# ensure (optional):: 'String' An ensure value to be passed through to vcsrepo. Valid values are 'present', 'latest' and 'absent'. Defaults to 'present' if unset.
#
# include (optional):: 'Array' A list of directories from this repository to copy to 'include_base_path'.
#
# provider (optional):: 'String' The vcsrepo provider to retrieve this repository with (defaults to 'git').
#
# post-checkout (optional):: 'String' A post-checkout hook for this repository.
# This hook will be run both if the repository is updated and if the hook's
# contents change. By default this is empty.
#
# revision (optional):: 'String' The revision to check out (defaults to 'master').
#
# @example
#    repodeploy::repos:
#      '/opt/puppet-modules/repodeploy':
#        source: https://github.com/syseleven/puppet-repodeploy.git
#        provider: git
#      '/opt/scripts/cloudstrap-utils':
#        source: git@gitlab.syseleven.de:cloudstrap/cloudstrap-utils.git
#        provider: git
#        post-checkout: |
#          #!/bin/sh
#          repo="<%= @name %>"
#          for i in ${repo}/bin/*
#            do
#              if [ ! -e /usr/local/bin/$(basename $i) ]; then
#                ln -s $i /usr/local/bin
#              fi
#            done
#
# @param [String] include_base_path A directory to copy repository subdirectories selected using a repository's include array to.
#
class repodeploy(
  $include_base_path = hiera('repodeploy::include_base_path', '/opt/puppet-modules'),
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
      if $provider == 'git' {
        $revision = 'master' # os-568: fixes ensure => latest with empty revision.
      } else {
        $revision = undef
      }
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

    file { $post_checkout_hook:
      ensure  => file,
      mode    => '0755',
      content => inline_template($post_checkout),
      }

    # ...and ensure it gets run, despite vcsrepo's `git reset --hard` (os-569):

    exec { "run $post_checkout_hook":
      path        => '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
      provider    => 'shell',
      command     => "cd ${name}; git checkout",
      subscribe   => [ Vcsrepo[$name], File[$post_checkout_hook] ],
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
      if ! defined(File[$include_base_path]) {
        file {$include_base_path:
          ensure => directory,
        }
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
