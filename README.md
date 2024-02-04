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

Allows navigation to switch to the next release or rollback to the previous one.

May delete old releases keeping a number of the most recent releases.

## Installation

- clone this `deploy.sh` script to `/opt` folder and create a global symlink:

   ```shell
   cd /opt
   sudo git clone git@github.com:vertilia/deploy.git
   sudo ln -s /opt/deploy/deploy.sh /usr/local/bin/deploy
   ```

## Examples

- build a new release from a git project `site-net` already cloned in `/opt` dir (creates a new
  folder `/var/www/site.net-TIMESTAMP` without moving the current symlink):

   ```shell
   sudo deploy build site.net /opt/site-net
   ```

- build a new release from a git project `example-com` (folder `www/`) already cloned in `/opt` dir, merging additional
  frontend stored in local `front-example-com.zip` file with `build/` folder inside the archive (creates a new
  folder `/var/www/example.com-TIMESTAMP` without moving the current symlink):

   ```shell
   sudo deploy build example.com /opt/example-com/www ~/front-example-com.zip:build
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
