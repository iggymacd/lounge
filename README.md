lounge
======

A collection of utilities for Dart and CouchDb

This library is was created out of a need for me to make it easy to deploy my Dart project to CouchDb in a repeatable way.

Many improvements will be made over time, but for now it is functional.

To use the library in it's current form, add the following lines to your dependencies section of your pubspec.yaml file;

  deploy_utils:
    git:
      url: https://github.com/iggymacd/lounge.git

Also, in your build.dart file, add a new line to main something like;

      main() {
        build(new Options().arguments, ['web/index.html']);
        deploy(['<name_of_directory1>', '<name_of_directory2>'], 'https://<username>:<password>@<cloudDb_db_url>');
      }

The next time you run build, the directories that you indicated in the deploy command will be uploaded to the couchDB db indicated in the url.

If you are using web_ui, and I assume you are if you have a build.dart file, at a minimum, you should include the directory 'out'. 

The first time I run a deploy, I include all of the directories that contain static content, like 'images' and 'styles'.

Once these static files have been uploaded, I usually remove the directories from the deploy command.

The way this technique works is by taking advantage of how couchDb stores information. Each directory becomes a document in the db. Every file in the directory gets uploaded as an attachment. 

If you compile javascript in your project, that will be uploaded to the db as well, and your app will work as a dart or javascript application.

Feel free to improve this library in any way you like. I will continue to improve it over time by refactoring and including tests.

A small tutorial will be provided shortly.