# Cakefile

{spawn, exec} = require 'child_process'
async = require 'async'

REPORTER = 'spec'
BUILD_DEBUG = './build/debug'
BUILD_RELEASE = './build/release'
MOCHA = './node_modules/.bin/mocha'
COFFEE = 'node ./node_modules/.bin/coffee --compile'

# run unit tests
task 'test', 'run unit tests', ->
    exec "NODE_ENV=test
             ./node_modules/.bin/mocha
             --compilers coffee:coffee-script
             --reporter #{REPORTER}
             --require coffee-script
             --colors
           ", (err, output) ->
        throw err if err
        console.log output

# run integration tests
task 'test-integration', 'run integration tests', ->
    exec "NODE_ENV=test
              ./node_modules/.bin/mocha
              --compilers coffee:coffee-script
              --reporter #{REPORTER} test-integration
              --require coffee-script
              --colors
            ", (err, output) ->
        throw err if err
        console.log output

# clean code coverage report
task 'clean_coverage', 'clean tmp data from code coverage', ->
    clean '/tmp/coverage', ->

# clean given path
clean = (path, callback) ->
    command = "rm -rf #{path}"
    console.log command
    exec command, -> callback?()

# instrument code coverage
instrument = (callback) ->
    clean '/tmp/coverage', ->
        exec "mkdir -p /tmp/coverage && tar -cf - . | (cd /tmp/coverage && tar -xf -)", (err, output) ->
            if (err)
                console.log(err)
                return err
            exec "cd /tmp/coverage && ./node_modules/coffee-coverage/bin/coffeecoverage --initfile init.js --exclude node_modules,.git,test,test-integration,assets . .", (err, output) ->
                if (err)
                    console.log(err)
                else callback()

# generate code coverage report
task 'coverage', 'generate code coverage report', ->
    instrument () ->
        command = "cd /tmp/coverage && #{MOCHA} --require init.js --reporter html-cov >output.html"
        console.log command
        exec command, (err, output) ->
            if (err)
                console.log(err)
                return err
            console.log "open /tmp/coverage/output.html"
            exec "open /tmp/coverage/output.html", (err, output) ->

# build
task 'build', ->
    build()

build = (callback) ->
    clean "#{BUILD_DEBUG}", ->
    command = "#{COFFEE} --output #{BUILD_DEBUG}/scripts public/scripts/ && cp -r public #{BUILD_DEBUG}"
    console.log command
    exec command, (err, output) ->
        if (err)
            console.log(err)
            return err
        command = "mkdir -p #{BUILD_DEBUG}/vendor && cp node_modules/socket.io/node_modules/socket.io-client/dist/socket.io.js #{BUILD_DEBUG}/vendor/"
        console.log command
        exec command, (err, output) ->
            if (err)
                console.log(err)


# run server in DEV mode
task 'run', 'run node in development env', ->
    invoke 'build'
    node = spawn 'node', ['server.js']
    node.stdout.on 'data', (data) -> console.log data.toString()
    node.stderr.on 'data', (data) -> console.log data.toString()
    process.on 'SIGINT', () -> node.kill 'SIGINT'


