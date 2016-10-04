_ = require "lodash"
winston = require "winston"
BlobTransport = require "../src"
chance = new (require "chance")()

logger = new (winston.Logger)(
  transports: [
    new BlobTransport
      account:
        name: process.env.ACCOUNT_NAME
        key: process.env.ACCOUNT_KEY
      containerName: process.env.CONTAINER_NAME or "test"
      blobName: process.env.BLOB_NAME or "example.log"
      level: process.env.LOG_LEVEL or "info"
  ]
)

_.times 10000, (index) -> 
  logger.info "#{index}: Log a simple line: #{chance.paragraph()}"