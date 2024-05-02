# deploy

Deploy script to release builds from git repositories into web folders

## Description

Script for releasing from git repositories with the possibility to merge additional code from provided archive files.

### Organizes builds in `/var/www` folder in the following manner:

```
/var/www:
  example.com -> example.com-231012-151633/
  example.com-231011-083320/
  example.com-231011-103529/
  example.com-231012-135855/
  example.com-231012-150241/
  example.com-231012-151633/
  site.net -> site.net-230929-055438/
  site.net-230929-055438/
```

Here, `site.net` and `example.com` are configured as doc roots for corresponding sites in Apache. These are symlinks
pointing to timestamped folders with real builds.

### Corresponding sources are cloned as git working directories

```
/opt:
  example-com/
    .git/
    .gitignore
    composer.json
    docker-compose.yml
    LICENSE
    README.md
    www/
      index.php
  example-com-darktheme.zip
  site-net/
    .git/
    index.html
```

Here, you have sources for both your sites inside the corresponding git projects. 

New build for `site.net` project will be created in a folder `/var/www/site.net-TIMESTAMP`, it's contents will be
first pulled by a git project in `/opt/site-net` folder and then copied into the build folder.

When creating a new build for `example.com` site, the script should pull the last version of `/opt/example-com`, copy
the contents of its `www/` sub-folder to the new build folder, then unzip the `/opt/example-com-darktheme.zip` file to
temporary directory and copy the contents of its `build/` subdirectory to the build folder.

The script will check the diff of the current build and the just produced candidate build. If both builds have no
differences, the candidate build will be deleted.

At different build phases, user-defined scripts may be executed. These scripts may do some additional tasks like
deleting unnecessary files from the build folder or copying env files from the current build. They may be executed
before and/or after the final diff operation.

When the build is constructed, deploy may help with observing the file differences between the current build and the
candidate one.

It also provides commands to release the new candidate build or rollback to one of the previous ones.

May delete old builds keeping a number of the most recent builds.

## Installation

- clone this `deploy.sh` script to `/opt` folder and create a global symlink:

   ```shell
   cd /opt
   sudo git clone https://github.com/vertilia/deploy.git
   sudo ln -s /opt/deploy/deploy.sh /usr/local/bin/deploy
   ```

## Examples

Given you have two websites described [above](#description), which are stored in `/var/www` folder and also as cloned
git projects (`example-com` and `site-net`) in `/opt` folder, together with a dark theme for `example.com` site as an
archive.

Then the following operations are available to you:

- prepare a new build from a git project `/opt/site-net` (creates a new folder `/var/www/site.net-TIMESTAMP` without
  moving the current symlink):

   ```shell
   sudo deploy build site.net /opt/site-net
   ```

- prepare a new build from a git project `/opt/example-com` (it's `www/` sub-folder), copying additional dark theme of
  zip archive `/opt/example-com-darktheme.zip` stored in `build/` folder inside it (creates a new
  folder `/var/www/example.com-TIMESTAMP` without moving the current symlink):

   ```shell
   sudo deploy build example.com /opt/example-com/www /opt/example-com-darktheme.zip:build
   ```

- change a build folder owner to non-default value (set an owner to `john` instead of `www-data`):

   ```shell
   OWNER=john sudo -E deploy build site.net
   ```

- prepare build in non-default web folder (if web folders are organized in `/usr/local/nginx` instead of `/var/www`):

   ```shell
   BASE_WWW=/usr/local/nginx sudo -E deploy build site.net
   ```

- run an after-build script passing current and new build folders as arguments; an after-build script is executed
  after the build but before the diff phase (that identifies whether the new candidate build contains updated files
  over the current build):

   ```shell
   SCRIPT_AFTER_BUILD=./after-build.sh sudo -E deploy build site.net
   ```

- run an after-diff script passing current and new build folders as arguments; an after-diff script is executed after
  the diff phase (that identifies whether the new candidate build contains updated files over the current build) and
  only if the diff is non-empty:

   ```shell
   SCRIPT_AFTER_DIFF=./after-diff.sh sudo -E deploy build site.net
   ```

- compare current build and the new one for `example.com` symlink (without moving the current symlink):

   ```shell
   deploy diff example.com
   ```

- release the new candidate build for `example.com` symlink (will point the symlink to the most recent build
  in `/var/www/example.com-TIMESTAMP`):

   ```shell
   sudo deploy release example.com
   ```

- rollback the `example.com` symlink (will point the symlink to the build in `/var/www` that precedes the current
  one):

   ```shell
   sudo deploy rollback example.com
   ```

### Sample workflow with explanation of `release` and `rollback` modes

Starting with the file structure given in [Description](#description), with `example.com` symlink pointing
to `example.com-231012-151633` folder.

- first `sudo deploy rollback example.com` command will change symlink to point to `example.com-231012-150241` (previous
  build)

- next `sudo deploy rollback example.com` command will change symlink to point to `example.com-231012-135855`
  (before-previous build)

- final `sudo deploy commit example.com` command will change symlink to point back to `example.com-231012-151633` (the
  most recent build)
