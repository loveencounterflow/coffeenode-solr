

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

#-----------------------------------------------------------------------------------------------------------
@main = ->
  db = SOLR.new_db hostname: '127.0.0.1'
  log TRM.steel db
  step ( resume ) =>*
    document =
      'id':       '1234'
      'name':     'I. C. Wiener'
    response = yield SOLR.update db, document, resume
    log TRM.pink response

############################################################################################################
do @main





