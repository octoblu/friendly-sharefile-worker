commander     = require 'commander'
async         = require 'async'
redis         = require 'redis'
RedisNS       = require '@octoblu/redis-ns'
MeshbluConfig = require 'meshblu-config'
JobManager    = require 'meshblu-core-job-manager'
packageJSON   = require './package.json'
QueueWorker   = require './src/queue-worker'

class Command
  parseInt: (str) =>
    parseInt str

  parseOptions: =>
    commander
      .version packageJSON.version
      .option '-n, --namespace <friendly-sharefile>', 'job handler queue namespace.', 'friendly-sharefile'
      .option '-s, --single-run', 'perform only one job.'
      .option '-t, --timeout <600>', 'seconds to wait for a next job.', @parseInt, 600
      .parse process.argv

    {@namespace,@singleRun,@timeout} = commander

    @jobLogQueue      = process.env.JOB_LOG_QUEUE
    @jobLogRedisUri   = process.env.JOB_LOG_REDIS_URI
    @jobLogSampleRate = parseFloat process.env.JOB_LOG_SAMPLE_RATE || '0.01'

    if process.env.FRIENDLY_SHAREFILE_NAMESPACE?
      @namespace = process.env.FRIENDLY_SHAREFILE_NAMESPACE

    if process.env.FRIENDLY_SHAREFILE_SINGLE_RUN?
      @singleRun = process.env.FRIENDLY_SHAREFILE_SINGLE_RUN == 'true'

    if process.env.FRIENDLY_SHAREFILE_TIMEOUT?
      @timeout = parseInt process.env.FRIENDLY_SHAREFILE_TIMEOUT

    if process.env.REDIS_URI
      @redisUri = process.env.REDIS_URI
    else
      @redisUri = 'redis://localhost:6379'

  run: =>
    console.log 'Starting...'
    @parseOptions()
    client = new RedisNS @namespace, redis.createClient @redisUri
    jobManager = new JobManager {client, timeoutSeconds: @timeout, @jobLogRedisUri, @jobLogQueue, @jobLogSampleRate }
    process.on 'SIGTERM', => @terminate = true
    process.on 'SIGINT', => @terminate = true

    meshbluConfig = new MeshbluConfig().toJSON()

    return @queueWorkerRun {jobManager, meshbluConfig}, @die if @singleRun
    async.until @terminated, async.apply(@queueWorkerRun, {jobManager, meshbluConfig}), @die

  terminated: => @terminate

  queueWorkerRun: ({jobManager, meshbluConfig}, callback) =>
    queueWorker = new QueueWorker {jobManager,meshbluConfig}

    queueWorker.run (error) =>
      if error?
        console.error error.stack
      process.nextTick callback

  die: (error) =>
    return process.exit(0) unless error?
    console.error error.stack
    process.exit 1

commandWork = new Command()
commandWork.run()
