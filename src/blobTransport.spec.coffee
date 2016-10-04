_ = require "lodash"
vows = require "vows"
async = require "async"
sinon = require "sinon"
should = require "should"
proxyquire = require "proxyquire"
helpers = require "winston/test/helpers"

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

transportWithMock = (n) ->
  mock = 
    callCount: 0
    appendFromText: (a,b,c,callback) -> 
      @callCount++
      callback()

  { 
    transport: createTransport proxyquire "./blobTransport", mockAzure mock
    mock
  }

testLogging = ({messages: {length, n = 1}, calls = 1}) ->
  {transport, mock} = transportWithMock calls
  successfulLineLogs = 0
  "when log #{n} line(s) with length #{length}":
    "topic": -> 
      lines = _.times n, -> _.repeat "*", length
      _.each lines, (line) =>
        transport.log "INFO", line, {}, =>
          successfulLineLogs++
          @callback() if successfulLineLogs is n
      return
    "should be call #{calls} time(s) to Azure": (topic) ->
      successfulLineLogs.should.be.eql n
      mock.callCount.should.be.eql calls

tests = _.merge( 
  helpers.testNpmLevels(transportWithStub(), "should log messages to azure blob", (ign, err, logged) ->
    should(err).be.null()
    logged.should.be.not.null()
  ),
  testLogging(messages: length: 10),
  testLogging(messages: { length: 10, n: 10 })
)

vows.describe("winston-azure-blob-transport").addBatch(
  "the log() method": tests
).export(module);