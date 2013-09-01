

############################################################################################################
# njs_os                    = require 'os'
# njs_fs                    = require 'fs'
# njs_path                  = require 'path'
# njs_url                   = require 'url'
# mik_request               = require 'request' # https://github.com/mikeal/request
#...........................................................................................................
SOLR                      = require '..'
TEXT                      = require 'coffeenode-text'
TYPES                     = require 'coffeenode-types'
TRM                       = require 'coffeenode-trm'
log                       = TRM.log.bind TRM
rpr                       = TRM.rpr.bind TRM
echo                      = TRM.echo.bind TRM
#...........................................................................................................
suspend                   = require 'coffeenode-suspend'
step                      = suspend.step
collect                   = suspend.collect
immediately               = setImmediate
spawn                     = ( require 'child_process' ).spawn
#...........................................................................................................
default_options           = require '../options'
assert                    = require 'assert'


#-----------------------------------------------------------------------------------------------------------
@wrong_update_command = ( test ) ->
  db = SOLR.new_db hostname: '127.0.0.1'
  # log TRM.steel db
  step ( resume ) =>*
    document =
      'id':       '1234'
      'name':     'I. C. Wiener'
    try
      response = yield SOLR.update db, document, resume
    catch error
      assert ( error[ 'message' ].match /^Unknown command: id/ )?
      test.done()

#-----------------------------------------------------------------------------------------------------------
@ok_update_command = ( test ) ->
  db = SOLR.new_db hostname: '127.0.0.1'
  # log TRM.steel db
  step ( resume ) =>*
    document =
      'id':       '1234'
      'name':     'I. C. Wiener'
    documents = [ document, ]
    response  = yield SOLR.update db, documents, resume
    delete response[ 'dt' ]
    # log TRM.plum JSON.stringify response
    assert.deepEqual response, {"~isa":"SOLR/response","url":"http://127.0.0.1:8983/solr/update/json?commit=true&wt=json","status":0,"error":null,"parameters":{},"results":[],"first-idx":null}
    test.done()

#-----------------------------------------------------------------------------------------------------------
@low_level_search = ( test ) ->
  ### TAINT only works on otherwise empty DB after @ok_update_command has been run
  ###
  db = SOLR.new_db hostname: '127.0.0.1'
  # log TRM.steel db
  step ( resume ) =>*
    response  = yield SOLR._search db, '*:*', resume
    delete response[ 'dt' ]
    # log TRM.pink JSON.stringify response
    for document in response[ 'results' ]
      assert.equal document[ 'id' ], '1234'
      assert.equal document[ 'name' ], 'I. C. Wiener'
    test.done()

#-----------------------------------------------------------------------------------------------------------
# @main = ( test ) ->
#   wrong_update_command test
  # assert.throws ( step ( resume ) =>* yield @wrong_update_command resume ), /^Error: Unknown command: id/







############################################################################################################
# async_testing @main

# test = done: ->
# # @wrong_update_command test
# # @ok_update_command test
# @low_level_search test






