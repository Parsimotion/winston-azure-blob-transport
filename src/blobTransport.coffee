debug = require("debug")("winston-azure-blob-transport")

_ = require "lodash"
util = require "util"
errorToJson = require "error-to-json"
azure = require "azure-storage"
async = require "async"
winston = require "winston"
chunk = require "chunk"
Promise = require "bluebird"

Transport = winston.Transport

MAX_BLOCK_SIZE = azure.Constants.BlobConstants.MAX_APPEND_BLOB_BLOCK_SIZE

class BlobTransport extends Transport

  constructor: ({ @account, @containerName, @blobName, @level = "info", @nameResolver = {} }) ->
    super()
    @name = "BlobTransport"
    @cargo = @_buildCargo()
    @client = @_buildClient @account
    @nameResolver.getBlobName ?= => @blobName
    @nameResolver.getContainerName ?= => @containerName
    @_createContainer = async.memoize @__createContainer

  initialize: ->
    Promise.resolve()
    
  log: (level, msg, meta, callback) =>
    line = @_formatLine { level, msg, meta }
    @cargo.push { 
      level
      msg
      meta
      container: @nameResolver.getContainerName { level, msg, meta }
      blobName: @nameResolver.getBlobName { level, msg, meta }
      callback
    }
    return

  __createContainer: (containerName, callback) =>
    @client.createContainerIfNotExists containerName, { publicAccessLevel: "blob" }, callback

  _buildCargo: =>
    async.cargo (tasks, __whenFinishCargo) =>
      logsByBlob = _(tasks)
        .groupBy ({ container, blobName }) -> "#{ container }_#{ blobName }"
        .values().value()

      debug "Log in #{ logsByBlob.length } file(s)"
      async.eachSeries logsByBlob, (linesToLog, whenLogToBlob) =>
        containerName = linesToLog[0].container
        @_createContainer containerName, (err) =>
          whenLogToBlob err if err?
          @_logInFile containerName, linesToLog[0].blobName, linesToLog, whenLogToBlob
      , (err) =>
        __whenFinishCargo()

  _logInFile: (containerName, blobName, linesToLog, callback) =>
    __whenLogAllBlock = ->
      line.callback() for line in linesToLog 
      callback()

    logBlock = _.map(linesToLog, @_formatLine).join ""

    debug "Starting append log lines to /#{ containerName }/#{ blobName }. Size #{ logBlock.length }"
    chunks = chunk logBlock, MAX_BLOCK_SIZE
    debug "Saving #{ chunks.length } chunk(s) to /#{ containerName }/#{ blobName }"

    async.eachSeries chunks, (chunk, whenLoggedChunk) =>
      debug "Saving log with size #{ chunk.length } to /#{ containerName }/#{ blobName }"
      @client.appendFromText containerName, blobName, chunk, (err, result) =>
        return @_retryIfNecessary(err, containerName, blobName, chunk, whenLoggedChunk) if err
        whenLoggedChunk()
    , (err) ->
      debug "Error in block  /#{ containerName }/#{ blobName }" if err
      __whenLogAllBlock()

  _retryIfNecessary: (err, containerName, blobName, block, whenLoggedChunk) =>
    __createAndAppend = => @client.createAppendBlobFromText containerName, blobName, block, {}, __handle
    __doesNotExistFile = -> err.code? && err.code is "NotFound"
    __handle = (err) ->
      debug "Error in append", err if err
      whenLoggedChunk()

    if __doesNotExistFile() then __createAndAppend() else __handle err

  _formatLine: ({ level, msg, meta }) => "[#{level}] - #{@_timestamp()} - #{msg} #{@_meta(meta)}\n"

  _timestamp: -> new Date().toISOString()

  _meta: (meta) =>
    meta = errorToJson meta if meta instanceof Error
    if _.isEmpty meta then "" else "- #{util.inspect(meta)}"

  _buildClient : ({name, key}) =>
    azure.createBlobService name, key

#
# Define a getter so that `winston.transports.AzureBlob`
# is available and thus backwards compatible.
#
winston.transports.AzureBlob = BlobTransport

module.exports = BlobTransport
