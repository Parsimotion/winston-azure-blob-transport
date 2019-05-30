_ = require "lodash"
Promise = require "bluebird"
sinon = require "sinon"
should = require "should"
require "should-sinon"
proxyquire = require "proxyquire"

azure = require "azure-storage"
MAX_BLOCK_SIZE = azure.Constants.BlobConstants.MAX_APPEND_BLOB_BLOCK_SIZE

mockAzure = (mock) ->
  "azure-storage":
    createBlobService: -> mock

transportWithStub = ({ nameResolver } = {}) ->
  stub = mockAzure {
    appendFromText: sinon.stub().callsArgWith 3, null, null
    createContainerIfNotExists: sinon.stub().callsArgWith 2, null
  }

  AzureBlobTransport = proxyquire("./blobTransport", stub)
  new AzureBlobTransport {
    account:
      name: "accountName"
      key: "accountKey"
    containerName: "containerName"
    blobName: "blobName"
    nameResolver
  }

testLogInBlocksSucessfully = ({ messages: { sampleMessage, n = 1 }, calls = 1 }) ->

  describe "when log #{ n } line(s) with length #{ sampleMessage.length }", ->

    { transport, callback } = {}
    
    beforeEach ->
      transport = transportWithStub()
      callback = sinon.spy()

      lines = _.times n, _.constant(sampleMessage)
      for line in lines
        transport.log "INFO", line, {}, callback

      Promise.delay(1000)
      
    it "should be call #{calls} time(s) to Azure", ->
      transport.client.appendFromText.should.have.callCount calls

    it "should be call #{n} time(s) to success callback", ->
      callback.should.have.callCount n

    it "should be called with file and container", ->
      transport.client.appendFromText.alwaysCalledWithMatch "containerName", "blobName", sinon.match.string, sinon.match.function

describe "use custom name resolver", ->

  { nameResolver, container, id } = { container: 1923, id: 123 }

  beforeEach ->
    nameResolver = {
      getBlobName: sinon.spy ({ meta }) -> meta.id
      getContainerName: sinon.spy ({ meta }) -> meta.container
    }

  it "should be called with file and container", ->
    transport = transportWithStub { nameResolver }
    lines = _.times 10, (i) -> transport.log "INFO", "line #{i}", { id, container }, _.noop
    Promise.delay(1000).then ->
      nameResolver.getBlobName.should.have.callCount 10
      transport.client.appendFromText.alwaysCalledWithMatch container, id, sinon.match.string, sinon.match.function

sample = (n) ->
  paddingLeft = "[INFO] - #{new Date().toISOString()} - ".length
  paddingRight = "\n".length
  maxSizeMessage = n - paddingLeft - paddingRight
  _.repeat "*", maxSizeMessage

testLogInBlocksSucessfully({
  messages:
    sampleMessage: sample 100
})
testLogInBlocksSucessfully({
  messages:
    sampleMessage: sample 100
    n: 10
})
testLogInBlocksSucessfully({
  messages:
    sampleMessage: sample MAX_BLOCK_SIZE - 1
})
testLogInBlocksSucessfully({
  messages:
    sampleMessage: sample MAX_BLOCK_SIZE + 1
  calls: 2
})