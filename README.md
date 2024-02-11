# deploy

Deploy script to release builds from git repositories into web folders

## Description

Script for releasing from git repositories with the possibility to merge additional code from provided archive files.

### Organizes releases in `/var/www` folder in the following manner:

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
pointing to timestamped folders with real releases.

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

New release for `site.net` project will be created in a folder `/var/www/site.net-TIMESTAMP`, it's contents will be
first pulled by a git project in `/opt/site-net` folder and then copied into the release folder.

When creating a new release for `example.com` site, the script should pull the last version of `/opt/example-com`, copy
the contents of its `www/` sub-folder to the new release folder, then unzip the `/opt/example-com-darktheme.zip` file to
temporary directory and copy the contents of its `build/` subdirectory to the release folder.

The script will check the diff of the current release and the just produced candidate release. If both releases have no
differences, the candidate release will be deleted.

At different build phases, user-defined scripts may be executed. These scripts may do some additional tasks like
deleting unnecessary files from the release folder or copying env files from the current release. They may be executed
before and/or after the final diff operation.

When the release is built, deploy may help with observing the file differences between the current release and the
candidate one.

It also provides commands to switch to the new candidate release or rollback to the previous one.

May delete old releases keeping a number of the most recent releases.

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

- build a new release from a git project `/opt/site-net` (creates a new folder `/var/www/site.net-TIMESTAMP` without
  moving the current symlink):

   ```shell
   sudo deploy build site.net /opt/site-net
   ```

- build a new release from a git project `/opt/example-com` (it's `www/` sub-folder), copying additional dark theme of
  zip archive `/opt/example-com-darktheme.zip` stored in `build/` folder inside it (creates a new
  folder `/var/www/example.com-TIMESTAMP` without moving the current symlink):

   ```shell
   sudo deploy build example.com /opt/example-com/www /opt/example-com-darktheme.zip:build
   ```

- change a release folder owner to non-default value after build (set an owner to `john` instead of `www-data`):

   ```shell
   OWNER=john sudo -E deploy build site.net
   ```

- build release in non-default web folder (if web folders are organized in `/usr/local/nginx` instead of `/var/www`):

   ```shell
   BASE_WWW=/usr/local/nginx sudo -E deploy build site.net
   ```

- run an after build script passing current and new release folders as arguments; an after-build script is executed
  after the build but before the diff phase (that identifies whether the new candidate release contains updated files
  over the current release):

   ```shell
   SCRIPT_AFTER_BUILD=./after-build.sh sudo -E deploy build site.net
   ```

- run an after diff script passing current and new release folders as arguments; an after-diff script is executed after
  the diff phase (that identifies whether the new candidate release contains updated files over the current release) and
  only if the diff is non-empty:

   ```shell
   SCRIPT_AFTER_DIFF=./after-diff.sh sudo -E deploy build site.net
   ```

- compare current release and the new one for `example.com` symlink (without moving the current symlink):

   ```shell
   deploy diff example.com
   ```

- deploy the new candidate release for `example.com` symlink (will point the symlink to the most recent release
  in `/var/www/example.com-TIMESTAMP`):

   ```shell
   sudo deploy commit example.com
   ```

- rollback the `example.com` symlink (will point the symlink to the release in `/var/www` that precedes the current
  one):

   ```shell
   sudo deploy rollback example.com
   ```

### Sample workflow with explanation of `commit` and `rollback` modes

Starting with the file structure given in [Description](#description), with `example.com` symlink pointing
to `example.com-231012-151633` folder.

- first `sudo deploy rollback example.com` command will change symlink to point to `example.com-231012-150241` (previous
  release)

- next `sudo deploy rollback example.com` command will change symlink to point to `example.com-231012-135855`
  (before-previous release)

- final `sudo deploy commit example.com` command will change symlink to point back to `example.com-231012-151633` (the
  most recent release)
