

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
  log TRM.steel db
  step ( resume ) =>*
    document =
      'id':       '1234'
      'name':     'I. C. Wiener'
    try
      response = yield SOLR.update db, document, resume
    catch error
      test.done() if ( error[ 'message' ].match /^Unknown command: id/ )?

#-----------------------------------------------------------------------------------------------------------
@ok_update_command = ( test ) ->
  db = SOLR.new_db hostname: '127.0.0.1'
  log TRM.steel db
  step ( resume ) =>*
    document =
      'id':       '1234'
      'name':     'I. C. Wiener'
    documents = [ document, ]
    try
      response = yield SOLR.update db, documents, resume
    catch error
      test.done() if ( error[ 'message' ].match /^Unknown command: id/ )?


#-----------------------------------------------------------------------------------------------------------
# @main = ( test ) ->
#   wrong_update_command test
  # assert.throws ( step ( resume ) =>* yield @wrong_update_command resume ), /^Error: Unknown command: id/







############################################################################################################
# async_testing @main

