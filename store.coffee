mongoose = require 'mongoose'

module.exports.mongoUrl = mongoUrl = () ->
    url = process.env.MONGO_URL || 'mongodb://localhost:27017/mybooks'
    return url

db = mongoose.createConnection(mongoUrl())

exports.db = db

db.on 'open', () -> console.log("Connected to mongodb")
db.on 'error', (err) -> console.log "Mongodb connection failed. #{err}"

# ratings
ratingSchema = mongoose.Schema({
    _id : String,     # account id (email)
    rating : Number  # rating 1-5
});
ratingSchema.index({ _id: 1})


# authors
authorSchema = mongoose.Schema({
    _id: Number,       # author id
    first: String,     # first name
    last: String      # last name
});
authorSchema.index({ last: 1 })

# books
bookSchema = mongoose.Schema({
    _id: Number,       # book id
    aid: Number,      # author id
    title: String,     # book title
    sub: String,       # subtitle
    isbn10: String,    # isbn10
    isbn13: String,    # isbn13
    url: String,       # url
    ratings: [ratingSchema]    # ratings
})
bookSchema.index({ aid: 1 })


mybooksSchema = mongoose.Schema({
    _id : Number,     # book id
    month: Number,
    year: Number
});
mybooksSchema.index({ year: 1, month: 1})

# users
accountSchema = mongoose.Schema({
    _id: String,        # account id = twitter name
    name: String,
    provider: String,
    mybooks: [mybooksSchema]     # book infos
})

ratingSchema.set 'autoIndex', true
authorSchema.set 'autoIndex', true
bookSchema.set 'autoIndex', true
accountSchema.set 'autoIndex', true
mybooksSchema.set 'autoIndex', true

Author = db.model('Author', authorSchema)
Book = db.model('Book', bookSchema)
Account = db.model('Account', accountSchema)


#Migration
migSchema = mongoose.Schema({
    _id: Number,
    bid: Number,
    uid: String,
    rating: Number
})
Mig = db.model('Rating', migSchema)

#Migration Infos
infoSchema = mongoose.Schema({
    _id: Number,
    bid: Number,
    month: Number,
    year: Number
})
Info = db.model('Info', infoSchema)


class Store

    MAX_FETCH_SIZE = 500

    constructor:() ->

    # Accounts
    findOrCreateAccount: (newAccount, callback) ->
        console.log "Account: ", newAccount
        Account.findById newAccount._id, (err, account) ->
            if (err)
                console.log "error", err
                return callback(err)
            if (account)
                callback(null, account)
            else
                Account.create newAccount, (err, item) ->
                    if (err)
                        console.log "error", err
                    callback(err, item)

    getAccount: (aid, callback) ->
        Account.findOne({_id: aid}).exec(callback)


    addToMyBooks: (aid, mybook, callback) =>
        console.log "add ", mybook
        this.getAccount aid, (err, account) ->
            infos = account.mybooks || []
            infos.push mybook
            Account.update {_id: aid}, {$set: {mybooks: infos}}, (err) ->
                callback(err)


    # Authors

    # callback(err, authors)
    listAuthors: (callback) ->
        Author.find().limit(MAX_FETCH_SIZE).sort('last').exec(callback)

    getAuthorMap: (callback) ->
        authorMap = {}
        Author.find().limit(MAX_FETCH_SIZE).exec (err, authors) ->
            authorMap[a._id] = "#{a.first} #{a.last}" for a in authors
            callback(err, authorMap)

    getAuthor: (lastname, callback) ->
        Author.findOne({ last: lastname }).exec(callback)

    getAuthorById: (aid, callback) ->
        Author.findOne({ _id: aid }).exec(callback)

    createAuthor: (firstname, lastname, callback) ->
        id = new Date().getTime()
        Author.create {_id: id, first: firstname, last: lastname}, callback


    # Books

    createBook: (data, callback) ->
        Book.create data, callback

    updateBook: (bid, data, callback) ->
        Book.findOneAndUpdate {_id: bid}, data, callback


    findBookById: (bid, callback) ->
        Book.findOne({_id: bid}).exec(callback)

    listBooksByAuthor: (aid, callback) ->
        Book.find({aid: aid}).limit(MAX_FETCH_SIZE).exec(callback)

    listBooks: (callback) ->
        Book.find().limit(MAX_FETCH_SIZE).exec(callback)

    getBookMap: (callback) ->
        bookMap = {}
        Book.find().limit(MAX_FETCH_SIZE).exec (err, books) ->
            bookMap[book._id] = book for book in books
            callback(err, bookMap)

    upsertRating: (bid, newRating, callback) =>
        this.findBookById bid, (err, book) ->
            console.log "book= ", book
            allRatings = book.ratings || []
            otherRatings = allRatings

            if (allRatings.length > 0)
                otherRatings = allRatings.filter (item) -> item._id != newRating._id

            otherRatings.push newRating
            Book.update {_id: bid}, {$set: {ratings: otherRatings}}, (err) ->
                callback(err)


    # Migration code
    #
    listMigs: (callback) ->
        Mig.find().limit(MAX_FETCH_SIZE).exec(callback)

    listInfos: (callback) ->
        Info.find().limit(MAX_FETCH_SIZE).exec(callback)


module.exports = Store




