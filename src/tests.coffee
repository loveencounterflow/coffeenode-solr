

############################################################################################################
# njs_os                    = require 'os'
# njs_fs                    = require 'fs'
# njs_path                  = require 'path'
# njs_url                   = require 'url'
# mik_request               = require 'request' # https://github.com/mikeal/request
#...........................................................................................................
SOLR                      = require '..'
CACHE                     = require './CACHE'
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

f = ->
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
    #=========================================================================================================
    step ( resume ) =>*
      response  = yield SOLR._search db, '*:*', null, resume
      #.......................................................................................................
      for document in response[ 'results' ]
        assert.equal document[ 'id' ], '1234'
        assert.equal document[ 'name' ], 'I. C. Wiener'
      test.done()

  #-----------------------------------------------------------------------------------------------------------
  @high_level_search = ( test ) ->
    ### TAINT only works on otherwise empty DB after @ok_update_command has been run
    ###
    db = SOLR.new_db hostname: '127.0.0.1'
    #=========================================================================================================
    step ( resume ) =>*
      #.......................................................................................................
      options =
        'sort':           'score asc'
        'first-idx':      0
        'result-count':   50
      #.......................................................................................................
      response  = yield SOLR.search db, '*:*', resume
      log TRM.rainbow response
      #.......................................................................................................
      for document in response[ 'results' ]
        # log TRM.rainbow document
        assert.equal document[ 'id' ], '1234'
        assert.equal document[ 'name' ], 'I. C. Wiener'
      test.done()

#-----------------------------------------------------------------------------------------------------------
@query = ( test ) ->
  db = SOLR.new_db()
  log TRM.orange db
  SOLR.search db, """key:/has.*/""", ( error, results ) ->
    bye error if error?
    log TRM.gold '©8u7', results
    log TRM.cyan '©8u8', db
    test.done()

#-----------------------------------------------------------------------------------------------------------
@escaping = ( test ) ->
  db = null
  assert.equal ( SOLR.escape db, '(1+1):2' ), "\\(1\\+1\\)\\:2"
  assert.equal ( SOLR.escape db, '+ - && || ! ( ) { } [ ] ^ " ~ * ? : \ /' ), "\\+ \\- \\&\\& \\|\\| \\! \\( \\) \\{ \\} \\[ \\] \\^ \\\" \\~ \\* \\? \\:  \\/"
  assert.equal ( SOLR.quote  db, '(1+1):2' ), '"(1+1):2"'
  assert.equal ( SOLR.quote  db, '+ - && || ! ( ) { } [ ] ^ " ~ * ? : \ /' ), "\"+ - && || ! ( ) { } [ ] ^ \\\" ~ * ? :  /\""
  assert.equal ( SOLR.escape     '(1+1):2' ), "\\(1\\+1\\)\\:2"
  assert.equal ( SOLR.escape     '+ - && || ! ( ) { } [ ] ^ " ~ * ? : \ /' ), "\\+ \\- \\&\\& \\|\\| \\! \\( \\) \\{ \\} \\[ \\] \\^ \\\" \\~ \\* \\? \\:  \\/"
  assert.equal ( SOLR.quote      '(1+1):2' ), '"(1+1):2"'
  assert.equal ( SOLR.quote      '+ - && || ! ( ) { } [ ] ^ " ~ * ? : \ /' ), "\"+ - && || ! ( ) { } [ ] ^ \\\" ~ * ? :  /\""
  test.done()

#-----------------------------------------------------------------------------------------------------------
@assign_cache = ( test ) ->
  db = {}
  CACHE._assign_new_cache db
  assert.deepEqual db, {"%cache":{"~isa":"SOLR/cache","value-by-id":{},"count-by-type":{},"hit-count":0,"miss-count":0}}
  db = 'use-cache': yes
  CACHE._assign_new_cache db
  # log JSON.stringify db
  assert.deepEqual db, {"use-cache":true,"%cache":{"~isa":"SOLR/cache","value-by-id":{},"count-by-type":{},"hit-count":0,"miss-count":0}}
  test.done()

#-----------------------------------------------------------------------------------------------------------
@dont_assign_cache = ( test ) ->
  db = 'use-cache': no
  CACHE._assign_new_cache db
  # log TRM.yellow db
  assert.deepEqual db, { 'use-cache': false }
  test.done()

#-----------------------------------------------------------------------------------------------------------
populate_cache = ( db ) ->
  CACHE._assign_new_cache db
  CACHE.register db, { id: 'id-1', foo: 42, bar: 'helo', isa: 'fancy' }
  CACHE.register db, { id: 'id-2', ding: yes, dong: no }
  CACHE.register db, { id: 'id-3', key: 'some-key', value: 'a value', isa: 'brunz' }
  CACHE.register db, { id: 'id-4', key: 'some-key', value: 'other value', isa: 'brunz' }
  return null

#-----------------------------------------------------------------------------------------------------------
@register_value_in_cache = ( test ) ->
  db = {}
  populate_cache db
  CACHE.log_cache_report db
  # log JSON.stringify db
  assert.deepEqual db, {"%cache":{"~isa":"SOLR/cache","value-by-id":{"id-1":{"id":"id-1","foo":42,"bar":"helo","isa":"fancy"},"id-2":{"id":"id-2","ding":true,"dong":false},"id-3":{"id":"id-3","key":"some-key","value":"a value","isa":"brunz"},"id-4":{"id":"id-4","key":"some-key","value":"other value","isa":"brunz"}},"count-by-type":{"fancy":1,"(unknown)":1,"brunz":2},"hit-count":0,"miss-count":0}}
  test.done()

#-----------------------------------------------------------------------------------------------------------
@retrieve_value_from_cache = ( test ) ->
  db = {}
  populate_cache db
  #.........................................................................................................
  CACHE.retrieve db, 'id-1', null, ( error, value ) ->
    throw error if error?
    assert.deepEqual value, { id: 'id-1', foo: 42, bar: 'helo', isa: 'fancy' }
    assert value is db[ '%cache' ][ 'value-by-id' ][ 'id-1' ]
    CACHE.log_cache_report db
    log TRM.orange db
    test.done()

#-----------------------------------------------------------------------------------------------------------
@retrieve_value_from_retrieve_method = ( test ) ->
  db = {}
  value_id_88 = { 'id': 'id-88', 'isa': 'strange', 'key': 'boring', 'value': 'interesting' }
  populate_cache db
  #.........................................................................................................
  retrieve = ( db, id, handler ) ->
    assert.equal id, 'id-88'
    handler null, value_id_88
  #.........................................................................................................
  CACHE.retrieve db, 'id-88', retrieve, ( error, value ) ->
    throw error if error?
    CACHE.log_cache_report db
    assert.deepEqual db, {"%cache":{"~isa":"SOLR/cache","value-by-id":{"id-1":{"id":"id-1","foo":42,"bar":"helo","isa":"fancy"},"id-2":{"id":"id-2","ding":true,"dong":false},"id-3":{"id":"id-3","key":"some-key","value":"a value","isa":"brunz"},"id-4":{"id":"id-4","key":"some-key","value":"other value","isa":"brunz"},"id-88":{"id":"id-88","isa":"strange","key":"boring","value":"interesting"}},"count-by-type":{"fancy":1,"(unknown)":1,"brunz":2,"strange":1},"hit-count":0,"miss-count":1}}
    assert value is value_id_88
    test.done()




############################################################################################################
# async_testing @main

# test = done: ->
# @wrong_update_command test
# @ok_update_command test
# @low_level_search test
# @high_level_search test
# @caching test





