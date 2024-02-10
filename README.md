# deploy

Deploy script to release builds from git repositories into web folders

## Description

Script for releasing from git repositories with the possibility to merge additional code from provided archive files.

Organizes releases in `/var/www` folder in the following manner:

```
/var/www:
  site.net -> site.net-230929-055438/
  site.net-230929-055438/
  html/
  example.com -> example.com-231012-151633/
  example.com-231011-083320/
  example.com-231011-103529/
  example.com-231012-135855/
  example.com-231012-150241/
  example.com-231012-151633/
```

Here, `site.net` and `example.com` are configured as doc roots for corresponding sites in Apache. These are symlinks
pointing to timestamped folders with real releases.

New release for `site.net` project will be created in a folder `/var/www/site.net-TIMESTAMP`, it's content will be
pulled from a git project and the webroot subfolder of the project will be copied inside the release folder.

If provided, an archive with additional content (like frontend facelifts) will be unarchived and copied to the release
folder, merging with the existing code from the git project.

Script will check diff of the current release and the next release to verify correctness. If the new release has no diff
with the current one, it will be deleted.

Allows to run user-defined scripts at different build phases.

Provides commands to switch to the next release or rollback to the previous one.

May delete old releases keeping a number of the most recent releases.

## Installation

- clone this `deploy.sh` script to `/opt` folder and create a global symlink:

   ```shell
   cd /opt
   sudo git clone https://github.com/vertilia/deploy.git
   sudo ln -s /opt/deploy/deploy.sh /usr/local/bin/deploy
   ```

## Examples

Given you have 2 web sites described in [Description]() which are also stored as git projects (`example-com` and
`site-net`), cloned in `/opt` folder, together with this `deploy` project.

Your sources are organized as follows:

```
/opt:
  deploy/
  example-com/
  example-com-darktheme.zip
  site-net/
```

- build a new release from a git project `site-net` already cloned in `/opt` dir (creates a new
  folder `/var/www/site.net-TIMESTAMP` without moving the current symlink):

   ```shell
   sudo deploy build site.net /opt/site-net
   ```

- build a new release from a git project `example-com` (it's `www/` subfolder) already cloned in `/opt` dir, copying
  additional dark theme of zip archive `/opt/example-com-darktheme.zip` stored in `build/` folder inside it (creates
  a new folder `/var/www/example.com-TIMESTAMP` without moving the current symlink):

   ```shell
   sudo deploy build example.com /opt/example-com/www /opt/example-com-darktheme.zip:build
   ```

- build release in non-default web folder:

   ```shell
   BASE_WWW=/usr/local/nginx sudo -E deploy build example.com
   ```

- change release folder owner to non-default value after build:

   ```shell
   OWNER=john sudo -E deploy build example.com
   ```

- run an after build script passing current and new release folders as arguments; an after-build script is executed
  after build but before diff phase (that identifies whether the new release contains updated files over the current
  release):

   ```shell
   SCRIPT_AFTER_BUILD=./after-build.sh sudo -E deploy build example.com
   ```

- run an after diff script passing current and new release folders as arguments; an after-diff script is executed
  after the diff phase (that identifies whether the new release contains updated files over the current release) and
  only if the diff is non-empty:

   ```shell
   SCRIPT_AFTER_DIFF=./after-diff.sh sudo -E deploy build example.com
   ```

- verify differences between current release and the new one for `example.com` symlink (without moving the current
  symlink):

   ```shell
   deploy diff example.com
   ```

- deploy the pre-built release for `example.com` symlink (will point the symlink to the most recent release
  in `/var/www/example.com-TIMESTAMP`):

   ```shell
   sudo deploy switch example.com
   ```

- rollback the `example.com` symlink (will point the symlink to the release in `/var/www` that precedes the current
  one):

   ```shell
   sudo deploy rollback example.com
   ```

### Sample workflow with explanation of `switch` and `rollback` modes

Starting with the file structure given in [Description](), with `example.com` symlink pointing
to `example.com-231012-151633` folder.

- first `sudo deploy rollback example.com` command will change symlink to point to `example.com-231012-150241` (previous
  release)

- next `sudo deploy rollback example.com` command will change symlink to point to `example.com-231012-135855`
  (before-previous release)

- final `sudo deploy switch example.com` command will change symlink to point back to `example.com-231012-151633` (the
  most recent release)
