'use strict';

module.exports = function (grunt) {

  require('load-grunt-tasks')(grunt);

  require('time-grunt')(grunt);

  // Configurable paths for the application
  var appConfig = {
    app: 'app',
    dist: 'dist'
  };

  // Define the configuration for all the tasks
  grunt.initConfig({

    // Project settings
    geokorp: appConfig,

    // Watches files for changes and runs tasks based on the changed files
    watch: {
      coffee: {
        files: ['<%= geokorp.app %>/scripts/{,*/}*.{coffee,litcoffee,coffee.md}'],
        tasks: ['newer:coffee:dist']
      },
      gruntfile: {
        files: ['Gruntfile.js']
      }
    },

    // The actual grunt server settings
    connect: {
      options: {
        port: 9000,
        // Change this to '0.0.0.0' to access the server from outside.
        hostname: 'localhost'
      }
    },

    // Empties folders to start fresh
    clean: {
      dist: {
        files: [{
          dot: true,
          src: [
            '.tmp',
            '<%= geokorp.dist %>'
          ]
        }]
      },
      server: '.tmp'
    },

    // Add vendor prefixed styles
    autoprefixer: {
      options: {
        browsers: ['last 1 version']
      },
      server: {
        options: {
          map: true,
        },
        files: [{
          expand: true,
          cwd: '.tmp/styles/',
          src: '{,*/}*.css',
          dest: '.tmp/styles/'
        }]
      },
      dist: {
        files: [{
          expand: true,
          cwd: '.tmp/styles/',
          src: '{,*/}*.css',
          dest: '.tmp/styles/'
        }]
      }
    },

    // Compiles CoffeeScript to JavaScript
    coffee: {
      options: {
        sourceMap: true,
        sourceRoot: ''
      },
      dist: {
        files: [{
          expand: true,
          cwd: '<%= geokorp.app %>/scripts',
          src: '{,*/}*.coffee',
          dest: '.tmp/scripts',
          ext: '.js'
        }]
      }
    },

    // Copies remaining files to places other tasks can use
    copy: {
      dist: {
        files: [{
          expand: true,
          dot: true,
          cwd: '<%= geokorp.app %>',
          dest: '<%= geokorp.dist %>',
          src: [
            'templates/{,*/}*.*',
            'data/places.json',
            'data/name_mapping.json',
            'styles/geokorp.css'
          ]
        }, {
          expand: true,
          cwd: '.tmp/images',
          dest: '<%= geokorp.dist %>/images',
          src: ['generated/*']
        }, {
          expand: true,
          cwd: '.tmp',
          src: 'scripts/sb_map.js',
          dest: '<%= geokorp.dist %>',
          rename: function(dest,src) {
            return dest + "/scripts/geokorp.js";
          }
        }, {
          expand: true,
          cwd: '.tmp',
          src: 'scripts/geokorp-templates.js',
          dest: '<%= geokorp.dist %>'
        }]
      },
      styles: {
        expand: true,
        cwd: '<%= geokorp.app %>/styles',
        dest: '.tmp/styles/',
        src: '{,*/}*.css'
      }
    },

    // Run some tasks in parallel to speed up the build process
    concurrent: {
      server: [
        'coffee:dist'
      ],
      dist: [
        'coffee'
      ]
    },
    html2js: {
      options: {
        base: 'app',
        module: 'sbMapTemplate'
      },
      main: {
        src: ['app/template/*.html'],
        dest: '.tmp/scripts/geokorp-templates.js'
      },
    },
    concat: {
      dist: {
        src: ['.tmp/scripts/*.js'],
        dest: '.tmp/geokorp.js',
      },
    },

  });

  grunt.registerTask('build', [
    'clean:dist',
    'concurrent:dist',
    'autoprefixer',
    'html2js',
    'concat',
    'copy:dist',
    'clean:server',
  ]);

  grunt.registerTask('default', [
    'build'
  ]);
};
