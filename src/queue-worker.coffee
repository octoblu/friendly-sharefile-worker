FriendlySharefile = require 'friendly-sharefile'
debug             = require('debug')('friendly-sharefile-worker:queue-worker')

class QueueWorker
  constructor: ({@jobManager,@meshbluConfig}) ->
  run: (callback) =>
    @jobManager.getRequest ['request'], (error, result) =>
      return callback error if error?
      return callback() unless result?
      debug "jobManager result:", JSON.stringify(result,null,2)

      {token,domain,jobType,options,responseId} = result.metadata
      data = JSON.parse result.rawData
      options.data = data

      friendlySharefile = new FriendlySharefile {@meshbluConfig,token,domain}
      func = friendlySharefile[jobType]
      unless func?
        error = new Error "jobType not found: #{jobType}"
        console.error error.stack
        return @respondWithError error, responseId, callback

      debug "passing in options to friendlySharefile.#{jobType}", JSON.stringify(options,null,2)
      func options, (error, sharefileResult) =>
        return @respondWithError error, responseId, callback if error?
        @respondWithSuccess sharefileResult, responseId, callback

  respondWithError: (error, responseId, callback) =>
    response =
      metadata:
        responseId:responseId
        code: error.code
      data: error.message
    debug 'responding with error', response
    @jobManager.createResponse 'response', response, callback

  respondWithSuccess: (result, responseId, callback) =>
    response =
      metadata:
        responseId: responseId
        code: result.code
      data: result.body
    debug 'responding with success', response
    @jobManager.createResponse 'response', response, callback

module.exports = QueueWorker
