"use strict"

require("coffee-script/register")

module.exports = (grunt) ->

  #-------
  #Plugins
  #-------
  grunt.loadNpmTasks "grunt-contrib-clean"
  grunt.loadNpmTasks "grunt-contrib-coffee"
  grunt.loadNpmTasks "grunt-mocha-test"
  grunt.loadNpmTasks "grunt-bump"


  #-----
  #Tasks
  #-----
  grunt.registerTask "default", "build"
  grunt.registerTask "test", "mochaTest"
  grunt.registerTask "build", ["clean:build", "coffee", "clean:specs"]

  #------
  #Config
  #------
  grunt.initConfig
    #Clean build directory
    clean:
      build: src: "lib"
      specs: src: "lib/*.spec.js"

    #Compile coffee
    coffee:
      compile:
        expand: true
        cwd: "#{__dirname}/src"
        src: ["**/{,*/}*.coffee"]
        dest: "lib/"
        rename: (dest, src) ->
          dest + "/" + src.replace(/\.coffee$/, ".js")

    # Run tests
    mochaTest:
      options:
        reporter: "spec"
      src: ["src/**/*.spec.coffee"]

    # Upgrade the version of the package
    bump:
      options:
        files: ["package.json"]
        commit: true
        commitMessage: "Release v%VERSION%"
        commitFiles: ["--all"]
        createTag: true
        tagName: "%VERSION%"
        tagMessage: "Version %VERSION%"
        push: false
