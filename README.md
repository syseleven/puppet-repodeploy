# repodeploy
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

