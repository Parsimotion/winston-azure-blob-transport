_ = require "lodash"
winston = require "winston"
chance = new (require "chance")()

require "winston-azure-blob-transport"

logger = new (winston.Logger)(
  transports: [
    new (winston.transports.AzureBlob)
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