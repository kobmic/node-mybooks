express = require 'express'
path = require 'path'
passport = require 'passport'


logger = require 'morgan'
cookieParser = require 'cookie-parser'
bodyParser = require 'body-parser'
session = require 'express-session'

module.exports = (initFn)->
    app = express()
    env = process.env.NODE_ENV || 'development'

    module.exports.static_route

    app.set('port', process.env.PORT || 8080);

    app.use(bodyParser.json())
    app.use(bodyParser.urlencoded({ extended: false }))
    app.use(cookieParser())

    if ('production' == env)
        app.use(logger(':req[x-forwarded-for] - - [:date] ":method :url HTTP/:http-version" :status :res[content-length] ":referrer" ":user-agent" :response-time ms'))
    else
        app.use(logger('dev'))

    app.use(session({ secret: 'somesecret' }));
    app.use(passport.initialize())
    app.use(passport.session())
    module.exports.static_route = path.join __dirname, 'public'
    app.use(express.static(path.join(__dirname, 'public')))
    app.set('views', __dirname + '/public/views')

    # use hogan express
    app.set 'view engine', 'html'
    app.engine 'html', require('hogan-express')
    app.set('layout', 'layout')
    app.set('partials', head: "head")


    #Init Routes
    require('./routes')(app, module.exports.static_route)

    if initFn?
        http = require 'http'
        server = http.createServer app
        server.listen app.get('port'), initFn
    app
