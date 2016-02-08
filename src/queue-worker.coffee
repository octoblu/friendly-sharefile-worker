FriendlySharefile = require 'friendly-sharefile'
debug             = require('debug')('friendly-sharefile-worker:queue-worker')

class QueueWorker
  constructor: ({@jobManager,@meshbluConfig}) ->
  run: (callback) =>
    debug 'running...'
    @jobManager.getRequest ['request'], (error, result) =>
      debug 'brpop response', error: error, result: result
      return callback error if error?
      return callback() unless result?

      {token,domain,jobType,options,responseId} = result.metadata
      data = JSON.parse result.rawData
      options.data = data

      friendlySharefile = new FriendlySharefile {@meshbluConfig,token,domain}
      friendlySharefile[jobType] options, (error, sharefileResult) =>
        return @respondWithError error, responseId, callback if error?
        @respondWithSuccess sharefileResult, responseId, callback

  respondWithError: (error, responseId, callback) =>
    response =
      metadata:
        responseId:responseId
        code: error.code
      data: error.message
    @jobManager.createResponse 'response', response, callback

  respondWithSuccess: (result, responseId, callback) =>
    response =
      metadata:
        responseId: responseId
        code: result.code
      data: result.body
    @jobManager.createResponse 'response', response, callback

module.exports = QueueWorker
