debug = require("debug")("winston-blob-transport")

_ = require "lodash"
util = require "util"
errorToJson = require "error-to-json"
azure = require "azure-storage"
async = require "async"
winston = require "winston"
chunk = require "chunk"
Promise = require "bluebird"

Transport = winston.Transport

MAX_BLOCK_SIZE = azure.Constants.BlobConstants.MAX_BLOCK_SIZE

class BlobTransport extends Transport

  constructor: ({ @account, @containerName, @blobName, @level = "info", @nameResolver }) ->
    super()
    @name = "BlobTransport"
    @cargo = @_buildCargo()
    @client = @_buildClient @account
    @nameResolver ?= { getBlobName: => @blobName }

  initialize: ->
    connectionString = "DefaultEndpointsProtocol=https;AccountName=#{@account.name};AccountKey=#{@account.key}"
    Promise.promisifyAll azure.createBlobService connectionString
      .createContainerIfNotExistsAsync @containerName, publicAccessLevel: "blob"
      .then (created) => debug "Container: #{@container} - #{if created then 'creada' else 'existente'}"

  log: (level, msg, meta, callback) =>
    line = @_formatLine {level, msg, meta}
    @cargo.push { line, callback }
    return

  _buildCargo: =>
    async.cargo (tasks, __whenFinishCargo) =>
      __whenLogAllBlock = ->
        debug "Finish append all lines to blob"
        _.each tasks, ({callback}) -> callback null, true
        __whenFinishCargo()

      debug "Log #{tasks.length}th lines"
      logBlock = _.map(tasks, "line").join ""

      debug "Starting append log lines to blob. Size #{logBlock.length}"
      chunks = chunk logBlock, MAX_BLOCK_SIZE
      debug "Saving #{chunks.length} chunk(s)"

      async.eachSeries chunks, (chunk, whenLoggedChunk) =>
        debug "Saving log with size #{chunk.length}"
        @client.appendFromText @containerName, @nameResolver.getBlobName(), chunk, (err, result) =>
          return @_retryIfNecessary(err, chunk, whenLoggedChunk) if err
          whenLoggedChunk()
      , (err) ->
        debug "Error in block" if err
        __whenLogAllBlock()

  _retryIfNecessary: (err, block, whenLoggedChunk) =>
    __createAndAppend = => @client.createAppendBlobFromText @containerName, @nameResolver.getBlobName(), block, {}, __handle
    __doesNotExistFile = -> err.code? && err.code is "NotFound"
    __handle = (err) ->
      debug "Error in append", err if err
      whenLoggedChunk()

    if __doesNotExistFile() then __createAndAppend() else __handle err

  _formatLine: ({level, msg, meta}) => "[#{level}] - #{@_timestamp()} - #{msg} #{@_meta(meta)}\n"

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
