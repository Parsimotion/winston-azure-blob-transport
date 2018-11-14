"use strict"

require("coffeescript/register")

module.exports = (grunt) ->

  #-------
  #Plugins
  #-------
  grunt.loadNpmTasks "grunt-contrib-clean"
  grunt.loadNpmTasks "grunt-exec"
  grunt.loadNpmTasks "grunt-bump"


  #-----
  #Tasks
  #-----
  grunt.registerTask "default", "build"
  grunt.registerTask "build", ["clean:build", "exec:compile", "clean:specs"]

  #------
  #Config
  #------
  grunt.initConfig
    #Clean build directory
    clean:
      build: src: "lib"
      specs: src: "lib/*.spec.js"

    #Compile coffee
    exec: compile: cmd: "coffee --compile --transpile --output lib/ src/"

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
