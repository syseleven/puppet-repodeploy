# repodeploy: Hash wrapper around vcsrepo with mr(1) configuration generator.

## Sample Usage (Hiera configuration)

```
repodeploy::repos:
  '/opt/puppet':
    source: git@github.com:syseleven/cloudstrap-utils.git
    provider: git
    include:
      - docs
    post-checkout:
      #!/bin/sh
      repo="<%= @name %>"
      ln -s "${repo}/bin/*" /usr/local/bin
```

## Requirements
* vcsrepo

