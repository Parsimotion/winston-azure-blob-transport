_ = require "lodash"
vows = require "vows"
async = require "async"
sinon = require "sinon"
should = require "should"
require "should-sinon"
proxyquire = require "proxyquire"
helpers = require "winston/test/helpers"

azure = require "azure-storage"
MAX_BLOCK_SIZE = azure.Constants.BlobConstants.MAX_BLOCK_SIZE

createTransport = (AzureBlobTransport) ->
  new AzureBlobTransport
    account:
      name: "accountName"
      key: "accountKey"
    containerName: "containerName"
    blobName: "blobName"

mockAzure = (mock) -> "azure-storage": createBlobService: -> mock

transportWithStub = ->
  stub = mockAzure appendFromText: sinon.stub().callsArgWith 3, null, null
  createTransport proxyquire "./blobTransport", stub

testLogging = ({messages: { sampleMessage, n = 1 }, calls = 1}) ->
  successfulLineLogs = 0
  "when log #{n} line(s) with length #{sampleMessage.length}":
    "topic": ->
      transport = transportWithStub()
      callback = sinon.spy()

      lines = _.times n, _.constant(sampleMessage)
      for line in lines
        transport.log "INFO", line, {}, callback

      setTimeout =>
        @callback null, { transport, callback }
      , 2000

      return

    "should be call #{calls} time(s) to Azure": ({ transport }) ->
      transport.client.appendFromText.should.have.callCount calls

    "should be call #{n} time(s) to success callback": ({ callback }) ->
      callback.should.have.callCount n

sample = (n) ->
  paddingLeft = "[INFO] - #{new Date().toISOString()} - ".length
  paddingRight = "\n".length
  maxSizeMessage = n - paddingLeft - paddingRight
  _.repeat "*", maxSizeMessage

tests = _.merge(
  helpers.testNpmLevels(transportWithStub(), "should log messages to azure blob", (ign, err, logged) ->
    should(err).be.null()
    logged.should.be.not.null()
  ),
  testLogging(
    messages:
      sampleMessage: sample 10
  ),
  testLogging(
    messages:
      sampleMessage: sample 10
      n: 10
  ),
  testLogging(
    messages:
      sampleMessage: sample MAX_BLOCK_SIZE - 1
  ),
  testLogging(
    messages:
      sampleMessage: sample MAX_BLOCK_SIZE + 1
    calls: 2
  )
)

vows.describe("winston-azure-blob-transport").addBatch(
  "the log() method": tests
).export(module);
