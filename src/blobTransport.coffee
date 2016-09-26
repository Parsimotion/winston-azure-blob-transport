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
      async.cargo (tasks, whenFinishCargo) =>
        whenFinishTasks = -> 
          _.each tasks, ({callback}) -> callback null, true
          whenFinishCargo()

        debug "Log #{tasks.length}th lines"
        logBlock = _.map(tasks, "line").join ""
        debug "Starting append log line to blob. Size #{logBlock.length}"
        @client.appendFromText @containerName, @blobName, logBlock, (err, result) =>
          debug "Error in append", err if err
          debug "Finish append all lines to blob"
          whenFinishTasks()
      
    _formatLine: ({level, msg, meta}) => "[#{level}] - #{@_timestamp()} - #{msg} #{@_meta(meta)} \n"

    _timestamp: -> new Date().toISOString()

    _meta: (meta) => if _.isEmpty meta then "" else "- #{util.inspect(meta)}"

    _buildClient : ({name, key}) =>
      azure.createBlobService name, key