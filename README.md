# g5kapi

This application is in charge of providing the core APIs for Grid'5000.

The project is hosted at <ssh://git.grid5000.fr/srv/git/repos/g5kapi>.
Please send an email to <cyril.rohr@inria.fr> if you cannot access the code.


## Installation

The app is packaged for Debian Squeeze. Therefore installation is as follows:

    sudo apt-get update
    sudo apt-get install g5k-api

In particular, runtime dependencies of the app include `ruby1.9.1-full` and `git-core`.


## Development

* This app does not work with `ruby` 1.8. Therefore you need to have a working
  installation of `ruby` 1.9.2+. We recommend using `rvm` to manage your ruby
  installations.

* As with every Rails app, it uses the `bundler` gem to manage dependencies:

        $ gem install bundler --no-ri --no-rdoc

  Note: in the next sections we'll run `rake` or `cap` executables. If you're
  using an old version of bundler and are not using `rvm` to manage your ruby
  installations, you will probably need to prefix every executable with
  `bundle exec`. E.g. `rake -T` will become `bundle exec rake -T`.

* From the application root, install the application dependencies,
  mysql2 gem need deb package libmysqlclient-dev, and for nokogiri see
  [Nokogiri](http://nokogiri.org/tutorials/installing_nokogiri.html):

        $ bundle install

* [option1 - the hard way - setup the full development environment on your machine]

  Install a MySQL database, and any other dependency that can be required by
  the API to run, and adapt the configuration files located in
  `config/options/`. Look at the puppet recipes that can be found in the
  `puppet/` directory to know more about the software that should be installed
  to mirror the production servers.

* [option2 - the easy way - use a Grid'5000 node as your development server]

  If you don't want to install a mysql server and other dependencies on your
  machine, you can use one of the Capistrano tasks that are bundled with the
  app to install the full development environment on a Grid'5000 node. If you
  enter the following command, then you'll have a Grid'5000 node provisioned
  for you with the right version of the OS and all the software dependencies
  and port forwarding setup (takes about 5-10 minutes to deploy and
  configure):

        $ cap develop

  This is the recommended approach, and you can reuse the node for packaging a
  new release once you've made some changes.

* Setup the database schema:

        $ rake db:setup RACK_ENV=development

* To run the server, just enter:

        $ ./bin/g5k-api server start -e development

  If you want to develop on the UI, you should probably setup an SSH tunnel
  between your machine and one of the MySQL server of Grid'5000, so that you
  can access the current jobs:

        $ ssh -NL 13307:mysql.rennes.grid5000.fr:3306 access.rennes.grid5000.fr


That's it. If you're not too familiar with `rails` 3, have a look at
<http://guides.rubyonrails.org/>.

You can also list the available rake tasks and capistrano tasks to see what's
already automated for you:

    $ rake -T
    $ cap -T


## Testing

Assuming you have your development environment setup, the only missing step is
to create a test database, and a fake OAR database.

* Create the test database as follows:

        $ RACK_ENV=test rake db:setup

* Create the fake OAR database as follows:

        $ RACK_ENV=test rake db:oar:setup

  or `RACK_ENV=test rake db:oar:seed` if the OAR database already exists.

* Launch the tests:

        $ RACK_ENV=test rake # or `bundle exec autotest` if this fails (issue with Rails<3.1 and em_mysql2 adapter with evented code).


## Packaging

* Bumping the version number is done as follows (a new changelog entry is
  automatically generated in `debian/changelog`):

        $ rake package:bump:patch # or: package:bump:minor, package:bump:major

* Building the `.deb` package is easy, since we kindly provide a `capistrano`
  recipe that will automatically reserve a machine on Grid'5000, deploy a
  squeeze-based image, upload the latest committed code (`HEAD`) in the
  current branch, generate a `.deb` package, and download the generated
  package back to your machine, in the `pkg/` directory.

  Just execute:

        $ cap package

  You can also pass a specific HOST if you wish (in this case it won't reserve
  a node on Grid'5000):

        $ cap package HOST=...
        $ cap package HOST=griffon-71.nancy.user SSH_KEY=~/.ssh/id_userg5k

## Releasing and Installing and new version

* Once you've packaged the new version, you must release it to the APT
  repository hosted on apt.grid5000.fr. There is Capistrano task for this:

        $ REMOTE_USER=g5kadmin cap release

  Note that you can use the same task to release on a different host (for
  testing purposes for example), by setting the HOST environment variable to
  another server (a Grid'5000 node for instance).

* If you released on apt.grid5000.fr, then you are now able to install the new
  version on any server by launching the following commands:

        puppet-repo $ bundle exec cap shell ROLES=devel
        cap> sudo apt-get update && sudo apt-get install g5k-api -y && sudo puppetd -t

  For this command to work, you should have a look in the
  `script/puppet-repo-custom.rb` file, which in my case was dropped into the
  `config/` directory of the `puppet-repo` repository.

  Then you can check that every server has the correct version running by
  grepping through the processlist to check the version numbers:

        puppet-repo $ bundle exec cap shell ROLES=devel
        cap> ps aux | grep g5k-api | grep -v grep
        [establishing connection(s) to api-server-devel.bordeaux.grid5000.fr, api-server-devel.grenoble.grid5000.fr, api-server-devel.lille.grid5000.fr, api-server-devel.lyon.grid5000.fr, api-server-devel.luxembourg.grid5000.fr, api-server-devel.nancy.grid5000.fr, api-server-devel.reims.grid5000.fr, api-server-devel.rennes.grid5000.fr, api-server-devel.orsay.grid5000.fr, api-server-devel.sophia.grid5000.fr, api-server-devel.toulouse.grid5000.fr]
         ** [out :: api-server-devel.bordeaux.grid5000.fr] g5k-api  26110  0.3 13.9 246432 72840 ?        Sl   Nov20  14:43 thin server (0.0.0.0:8000) [g5k-api-3.0.16]
         ** [out :: api-server-devel.grenoble.grid5000.fr] g5k-api  18510  0.3  7.5 249072 78620 ?        Sl   Nov18  22:48 thin server (0.0.0.0:8000) [g5k-api-3.0.16]
         ** [out :: api-server-devel.luxembourg.grid5000.fr] g5k-api  13384  0.1 13.6 203396 71184 ?        Sl   Nov22   1:29 thin server (0.0.0.0:8000) [g5k-api-3.0.16]
         ** [out :: api-server-devel.nancy.grid5000.fr] g5k-api  12702  0.3 26.9 312236 69704 ?        Sl   Nov20  17:27 thin server (0.0.0.0:8000) [g5k-api-3.0.16]
         ** [out :: api-server-devel.sophia.grid5000.fr] g5k-api  19366  0.2 16.2 325972 84864 ?        Sl   Nov18  21:03 thin server (0.0.0.0:8000) [g5k-api-3.0.16]
         ** [out :: api-server-devel.rennes.grid5000.fr] g5k-api  19353  0.9  7.2 246492 76220 ?        Sl   05:53   4:38 thin server (0.0.0.0:8000) [g5k-api-3.0.16]
         ** [out :: api-server-devel.lille.grid5000.fr] g5k-api  18563  0.2 35.3 262788 92760 ?        Sl   Nov18  19:43 thin server (0.0.0.0:8000) [g5k-api-3.0.16]
         ** [out :: api-server-devel.orsay.grid5000.fr] g5k-api  30348  0.3 27.4 244552 71028 ?        Sl   Nov22   4:57 thin server (0.0.0.0:8000) [g5k-api-3.0.16]
         ** [out :: api-server-devel.toulouse.grid5000.fr] g5k-api   3825  0.3 32.3 259840 83660 ?        Sl   Nov18  23:54 thin server (0.0.0.0:8000) [g5k-api-3.0.16]
         ** [out :: api-server-devel.reims.grid5000.fr] g5k-api   1749  0.8 31.9 324736 82696 ?        Sl   Nov18  65:08 thin server (0.0.0.0:8000) [g5k-api-3.0.16]
         ** [out :: api-server-devel.lyon.grid5000.fr] g5k-api   9940  0.5 33.9 329864 87796 ?        Sl   Nov18  40:32 thin server (0.0.0.0:8000) [g5k-api-3.0.16]


## Statistics

* Generate general statistics:

        $ bundle exec rake stats

  Example of output you'll get on the STDOUT:

        +----------------------+-------+-------+---------+---------+-----+-------+
        | Name                 | Lines |   LOC | Classes | Methods | M/C | LOC/M |
        +----------------------+-------+-------+---------+---------+-----+-------+
        | Controllers          |   447 |   352 |      14 |      31 |   2 |     9 |
        | Helpers              |    54 |    26 |       0 |       5 |   0 |     3 |
        | Models               |   351 |   288 |       7 |      25 |   3 |     9 |
        | Libraries            |     3 |     3 |       0 |       0 |   0 |     0 |
        | Model specs          |   340 |   315 |       0 |       0 |   0 |     0 |
        | Controller specs     |   550 |   523 |       0 |       0 |   0 |     0 |
        | Helper specs         |    15 |     3 |       0 |       0 |   0 |     0 |
        +----------------------+-------+-------+---------+---------+-----+-------+
        | Total                |  1760 |  1510 |      21 |      61 |   2 |    22 |
        +----------------------+-------+-------+---------+---------+-----+-------+
          Code LOC: 669     Test LOC: 841     Code to Test Ratio: 1:1.3

* Generate the test coverage:

        $ bundle exec rake test:rcov
        $ open coverage/index.html


## Maintenance

* <https://www.grid5000.fr/mediawiki/index.php/API_Maintenance>;

* There exist monit recipes that send emails when an alert is raised. At the
  time of writing (2011-10-18), these alerts are sent to
  <cyril.rohr@irisa.fr>. You might want to change that.


## Authors
* Cyril Rohr <cyril.rohr@inria.fr>
