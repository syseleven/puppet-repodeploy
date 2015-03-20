# repodeploy: Hash wrapper around vcsrepo with mr(1) configuration generator.
## Sample Usage
hiera:
```
repodeploy::repos:
  '/opt/puppet':
    source: git@github.com:puppetlabs/puppet.git
    provider: git
    include:
      - docs
```

## Requirements
* vcsrepo

