
async = require 'async'
path = require 'path'
_ = require 'underscore'
passport = require 'passport'
TwitterStrategy = require('passport-twitter').Strategy;

Store =  require('./store')
store = new Store()

twitterData =
    consumerKey: process.env.TWITTER_ID
    consumerSecret: process.env.TWITTER_SECRET
    callbackURL: "http://my-books.herokuapp.com/auth/twitter/callback"


module.exports = (app, static_route) ->

    ensureAuthenticated = (req, res, next) ->
        if (req.isAuthenticated())
            next()
        else
            res.redirect('/')

    lookupAuthors = (req, res, next) ->
        store.getAuthorMap (err, authorMap) ->
            if (err)
                return res.send(500)
            else
                req.authorMap = authorMap
                next()

    lookupBooks = (req, res, next) ->
        store.getBookMap (err, bookMap) ->
            if (err)
                return res.send(500)
            else
                req.bookMap = bookMap
                next()

    # uses id of authenticated user to get account info
    lookupAccount = (req, res, next) ->
        store.getAccount req.user, (err, account) ->
            if (err)
                return res.send(500)
            else
                req.account = account
                next()

    booklistData = (book, authorMap) ->
        count = if (book.ratings) then book.ratings.length else 0
        ratingVals = book.ratings.map (item) -> item.rating
        sum = 0
        if ratingVals.length > 0
            sum = ratingVals.reduce (a,b) -> a + b
        average = if (count > 0) then (sum / count) else 0
        {_id: book._id, title: book.title, sub: book.sub, author: authorMap[book.aid], count: count, average: average}


    passport.use new TwitterStrategy(twitterData, (token, tokenSecret, profile, done) ->
        account =
            _id: profile.username
            name: profile.displayName
            provider: profile.provider
        store.findOrCreateAccount account, (err, item) ->
            if (err)
                console.log "error", err
                done(err)
            else
                done(null, item)
    )

    passport.serializeUser (user, done) ->
        done(null, user._id)

    passport.deserializeUser (id, done) ->
        store.getAccount id, (err, account) ->
            done(err, account)

    # Routes
    #
    app.get '/auth/twitter', passport.authenticate('twitter'), (req, res) ->
        # The request will be redirected to Twitter for authentication, so this
        # function will not be called.
        console.log "called ???"
        res.send(500)

    app.get '/auth/twitter/callback', passport.authenticate('twitter', { failureRedirect: '/' }), (req, res) ->
        console.log "it works!!"
        res.redirect('/home')

    app.get '/logout', (req, res) ->
        req.logout()
        res.redirect('/')

    app.get '/', (req,res) ->
        res.render 'login',

    app.get '/home', ensureAuthenticated, lookupAccount, lookupBooks, lookupAuthors,  (req,res) ->

        myBooks = req.account.mybooks.filter (item) ->
            item?

        if (req.query.year)
            myBooks = req.account.mybooks.filter (item) ->
                item.year == parseInt(req.query.year)

        getBooklistData = (book) -> booklistData(book, req.authorMap)


        list = myBooks.map (item) ->
            book = req.bookMap[item._id]
            rich = getBooklistData(book)
            rich.date = "#{item.year} - #{String('00' + item.month).slice(-2)}"
            rich

        if (req.query.authorname)
            list = list.filter (item) ->
                item.author.indexOf(req.query.authorname) > -1

        res.render 'index',
            books: _(list).sortBy (b) -> [b.date]
            authorname: req.query.authorname
            year: req.query.year
            user: req.user

    app.get '/top', ensureAuthenticated, lookupAccount, lookupBooks, lookupAuthors, (req,res) ->
        toplistData = (book) ->
            {_id: book._id, author: req.authorMap[book.aid]}

        list = req.account.mybooks.map (item) ->
            book = req.bookMap[item._id]
            toplistData(book)

        counts = {}
        for item in list
            counts[item.author] = (counts[item.author] or 0) + 1

        ranked = _.sortBy _.keys(counts), (item) ->
            #Sort them by their negated counts
            -counts[item]

        toplist = ranked.map (item) -> {author: item, count: counts[item]}
        res.render 'top',
            tops:  toplist.slice(0,50)
            user: req.user


    app.get '/authors', ensureAuthenticated, (req,res) ->
        store.listAuthors (err, authors) ->
            res.render 'authors',
                authors: authors
                user: req.user

    app.get '/authors/add', ensureAuthenticated, lookupAuthors, (req,res) ->
        res.render 'newauthor',
            user: req.user

    app.post '/authors', lookupAuthors, (req,res) ->
        store.createAuthor req.body.first, req.body.last, (err) ->
            if (err)
                console.log "error ", err
                return res.send 500
        res.redirect '/authors'


    app.get '/authors/:id', ensureAuthenticated, lookupAuthors, (req,res) ->

        store.listBooksByAuthor req.params.id, (err, books) ->
            if (err)
                return res.send(500)

            getBooklistData = (book) -> booklistData(book, req.authorMap)

            booklist = books.map getBooklistData

            res.render 'books',
                books: booklist
                user: req.user


    app.get '/books', ensureAuthenticated, lookupAuthors, (req,res) ->
        store.listBooks (err, books) ->
            if (err)
                return res.send(500)

            getBooklistData = (book) -> booklistData(book, req.authorMap)

            booklist = books.map getBooklistData

            res.render 'books',
                books: booklist
                user: req.user

    app.get '/books/:id', ensureAuthenticated, lookupAuthors, lookupAccount, (req,res) ->
        authorsA = []
        authorsG = []
        authorsM = []
        authorsS = []

        store.listAuthors (err, authors) ->
            authorsA = authors.filter (item) ->
                item.last.charAt(0).toUpperCase() in ['A', 'B', 'C', 'D', 'E', 'F']
            authorsG = authors.filter (item) ->
                item.last.charAt(0).toUpperCase() in ['G', 'H', 'I', 'J', 'K', ]
            authorsM = authors.filter (item) ->
                item.last.charAt(0).toUpperCase() in ['L', 'M', 'N', 'O', 'P', 'Q', 'R']
            authorsS = authors.filter (item) ->
                item.last.charAt(0).toUpperCase() in [ 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'Ä', 'Ö', 'Å']

            if req.params.id == "add"
                res.render 'newbook',
                    AFauthors: authorsA
                    GLauthors: authorsG
                    MRauthors: authorsM
                    SZauthors: authorsS
                    user: req.user
            else
                readInfo = null
                readInfos = req.account.mybooks.filter (item) ->
                    item._id == parseInt(req.params.id)
                if (readInfos.length > 0)
                    monthNames = [ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" ]
                    readInfo =
                        year: readInfos[0].year
                        month: monthNames[readInfos[0].month - 1]

                store.findBookById req.params.id , (err, book) ->
                    if (err)
                        return res.send(500)

                    res.render 'editbook',
                        AFauthors: authorsA
                        GLauthors: authorsG
                        MRauthors: authorsM
                        SZauthors: authorsS
                        book: book
                        info: readInfo
                        user: req.user

    app.post '/books/:id', ensureAuthenticated, (req,res) ->
        book =
            aid: parseInt(req.body.authorId)
            title: req.body.title
            sub: req.body.subtitle
            url: req.body.url
            isbn10: req.body.isbn10
            isbn13: req.body.isbn13
        store.updateBook req.params.id, book, (err) ->
            if (err)
                res.send(500)
            else
                res.redirect "/books/#{req.params.id}"

    app.post '/books/:id/ratings', ensureAuthenticated, lookupAccount, (req,res) ->
        rating =
            _id: req.account._id
            rating: req.body.score
        console.log "new rating ", rating
        store.upsertRating req.params.id, rating, (err) ->
            if (err)
                return res.send 500
            res.redirect "/books/#{req.params.id}"

    app.post '/books', ensureAuthenticated, (req,res) ->
        bid = new Date().getTime()
        data =
            _id: bid
            aid: parseInt(req.body.authorId)
            title: req.body.title
            sub: req.body.subtitle
            isbn10: req.body.isbn10
            isbn13: req.body.isbn13
            url: req.body.url
            ratings: []
        store.createBook data, (err) ->
            if (err)
                console.log "error ", err
                return res.send 500
            res.redirect "/books/#{bid}"

    app.post '/mybooks', ensureAuthenticated, lookupAccount, (req,res) ->

        mybook =
            _id: parseInt(req.body.bookId)
            month: parseInt((req.body.endMonth))
            year: parseInt((req.body.endYear))
        console.log "add ", mybook
        store.addToMyBooks req.account._id, mybook, (err) ->
            if (err)
                return res.send(500)
            res.redirect "/books/#{req.body.bookId}"


return {}
    
