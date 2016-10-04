debug = require("debug")("winston-blob-transport")

_ = require "lodash"
util = require "util"
azure = require "azure-storage"
async = require "async"
winston = require "winston"

Transport = winston.Transport

module.exports = 
  class BlobTransport extends Transport

    constructor: ({account, @containerName, @blobName, @level = "info"}) ->
      @name = "BlobTransport"
      @cargo = @_buildCargo()
      @client = @_buildClient account

    log: (level, msg, meta, callback) =>
      line = @_formatLine {level, msg, meta}
      @cargo.push { line, callback }
      return

    _buildCargo: =>
      async.cargo (tasks, __whenFinishCargo) =>
        __whenFinishTasks = -> 
          debug "Finish append all lines to blob"
          _.each tasks, ({callback}) -> callback null, true
          __whenFinishCargo()

        debug "Log #{tasks.length}th lines"
        logBlock = _.map(tasks, "line").join ""
        debug "Starting append log lines to blob. Size #{logBlock.length}"
        @client.appendFromText @containerName, @blobName, logBlock, (err, result) =>
          return @_retryIfNecessary(err, logBlock, __whenFinishTasks) if err
          __whenFinishTasks()

    _retryIfNecessary: (err, block, callback) =>
      __append = => @client.createAppendBlobFromText @containerName, @blobName, block, {}, __handle
      __doesNotExistFile = -> err.code? && err.code is "NotFound"
      __handle = (err) ->
        debug "Error in append", err if err
        callback()

      if __doesNotExistFile() then __append() else __handle err
      
    _formatLine: ({level, msg, meta}) => "[#{level}] - #{@_timestamp()} - #{msg} #{@_meta(meta)} \n"

    _timestamp: -> new Date().toISOString()

    _meta: (meta) => if _.isEmpty meta then "" else "- #{util.inspect(meta)}"

    _buildClient : ({name, key}) =>
      azure.createBlobService name, key