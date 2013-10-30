

############################################################################################################
# njs_os                    = require 'os'
# njs_fs                    = require 'fs'
# njs_path                  = require 'path'
# njs_url                   = require 'url'
# mik_request               = require 'request' # https://github.com/mikeal/request
#...........................................................................................................
SOLR                      = require '..'
# CACHE                     = require './CACHE'
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
get_test_entries = ->
  R = [
    {"id":"glyph/國","isa":"node","key":"glyph","format":null,"value":"國"}
    {"id":"glyph/或","isa":"node","key":"glyph","format":null,"value":"或"}
    {"id":"glyph/王","isa":"node","key":"glyph","format":null,"value":"王"}
    {"id":"glyph/𤣩","isa":"node","key":"glyph","format":null,"value":"𤣩"}
    {"id":"glyph/[\"一\",\"二\",\"龶\",\"&jzr#xe189;\",\"夊\",\"黽\"]","isa":"node","key":"glyph","format":"json","value":"[\"一\",\"二\",\"龶\",\"&jzr#xe189;\",\"夊\",\"黽\"]"}
    {"id":"glyph/习","isa":"node","key":"glyph","format":null,"value":"习"}
    {"id":"reading/py/tonal/wáng","isa":"node","key":"reading/py/tonal","format":null,"value":"wáng"}
    {"id":"reading/py/base/wang","isa":"node","key":"reading/py/base","format":null,"value":"wang"}
    {"id":"usage/code/CJKTHM","isa":"node","key":"usage/code","format":null,"value":"CJKTHM"}
    {"id":"flag/true","isa":"node","key":"flag","format":"json","value":"true"}
    {"id":"flag/false","isa":"node","key":"flag","format":"json","value":"false"}
    {"id":"glyph/國;shape/contains#0;glyph/或","idx":0,"isa":"edge","key":"shape/contains","from":"glyph/國","to":"glyph/或"}
    {"id":"reading/py/tonal/wáng;has/reading/py/base#0;reading/py/base/wang","idx":0,"isa":"edge","key":"has/reading/py/base","from":"reading/py/tonal/wáng","to":"reading/py/base/wang"}
    {"id":"glyph/𤣩;has/shape/identity/tag:components#0;glyph/王","idx":0,"isa":"edge","key":"has/shape/identity/tag:components","from":"glyph/𤣩","to":"glyph/王"}
    {"id":"glyph/王;has/usage/code#0;usage/code/CJKTHM","idx":0,"isa":"edge","key":"has/usage/code","from":"glyph/王","to":"usage/code/CJKTHM"}
    {"id":"glyph/王;has/reading/py/tonal#0;reading/py/tonal/wáng","idx":0,"isa":"edge","key":"has/reading/py/tonal","from":"glyph/王","to":"reading/py/tonal/wáng"}
    {"id":"glyph/习;is/constituent#0;flag/true","idx":0,"isa":"edge","key":"is/constituent","from":"glyph/习","to":"flag/true"}
    {"id":"glyph/习;is/guide#0;flag/true","idx":0,"isa":"edge","key":"is/guide","from":"glyph/习","to":"flag/true"}
    ]
  return R

# f = ->
#-----------------------------------------------------------------------------------------------------------
@update_single_entry = ( test ) ->
  entries = do get_test_entries
  entry   = entries[ 0 ]
  db      = SOLR.new_db hostname: '127.0.0.1'
  step ( resume ) =>*
    response = yield SOLR.update db, entry, resume
    delete response[ 'dt' ]
    assert.deepEqual response, {"~isa":"SOLR/response","url":"http://127.0.0.1:8983/solr/update/json?commit=true&wt=json","status":0,"error":null,"parameters":{},"results":[],"first-idx":null}
    assert.deepEqual db[ '%cache' ], {"~isa":"SOLR/cache","value-by-id":{"glyph/國":{"id":"glyph/國","isa":"node","key":"glyph","format":null,"value":"國"}},"count-by-type":{"node":1},"hit-count":0,"miss-count":0}
    # log TRM.steel db
    # log TRM.pink JSON.stringify response
    # log TRM.pink JSON.stringify db[ '%cache' ]
    # SOLR.CACHE.log_report db
    test.done()

#-----------------------------------------------------------------------------------------------------------
@update_several_entries = ( test ) ->
  db      = SOLR.new_db hostname: '127.0.0.1'
  entries = do get_test_entries
  step ( resume ) =>*
    response  = yield SOLR.update db, entries, resume
    delete response[ 'dt' ]
    log TRM.plum JSON.stringify response
    assert.deepEqual response, {"~isa":"SOLR/response","url":"http://127.0.0.1:8983/solr/update/json?commit=true&wt=json","status":0,"error":null,"parameters":{},"results":[],"first-idx":null}
    # log TRM.pink db[ '%cache' ]
    # SOLR.CACHE.log_report db
    test.done()

#-----------------------------------------------------------------------------------------------------------
@clear_db = ( test ) ->
  db      = SOLR.new_db()
  entries = do get_test_entries
  step ( resume ) =>*
    response  = yield SOLR.clear db, resume
    response  = yield SOLR._search db, '*:*', null, resume
    log TRM.pink response
    # delete response[ 'dt' ]
    # log TRM.plum JSON.stringify response
    # assert.deepEqual response, {"~isa":"SOLR/response","url":"http://127.0.0.1:8983/solr/update/json?commit=true&wt=json","status":0,"error":null,"parameters":{},"results":[],"first-idx":null}
    # log TRM.pink db[ '%cache' ]
    # SOLR.CACHE.log_report db
    test.done()

#-----------------------------------------------------------------------------------------------------------
@using_get_with_correct_id = ( test ) ->
  db      = SOLR.new_db()
  entries = do get_test_entries
  step ( resume ) =>*
    response  = yield SOLR.clear db, resume
    response  = yield SOLR.update db, entries, resume
    entry     = yield SOLR.get db, 'glyph/王', resume
    assert.deepEqual entry, {"id":"glyph/王","isa":"node","key":"glyph","format":null,"value":"王"}
    assert.equal db[ '%cache' ][ 'hit-count'  ], 1
    assert.equal db[ '%cache' ][ 'miss-count' ], 0
    # log TRM.pink entry
    # delete response[ 'dt' ]
    # log TRM.plum JSON.stringify response
    # assert.deepEqual response, {"~isa":"SOLR/response","url":"http://127.0.0.1:8983/solr/update/json?commit=true&wt=json","status":0,"error":null,"parameters":{},"results":[],"first-idx":null}
    # log TRM.pink db[ '%cache' ]
    # SOLR.CACHE.log_report db
    test.done()

#-----------------------------------------------------------------------------------------------------------
@using_get_with_invalid_id = ( test ) ->
  db      = SOLR.new_db()
  entries = do get_test_entries
  step ( resume ) =>*
    response  = yield SOLR.clear db, resume
    response  = yield SOLR.update db, entries, resume
    try
      entry     = yield SOLR.get db, 'NOTEXIST', resume
    catch error
      assert.equal error[ 'message' ], "invalid ID: 'NOTEXIST'"
      test.done()

#-----------------------------------------------------------------------------------------------------------
@using_get_with_fallback = ( test ) ->
  db      = SOLR.new_db()
  entries = do get_test_entries
  step ( resume ) =>*
    response  = yield SOLR.clear db, resume
    response  = yield SOLR.update db, entries, resume
    entry     = yield SOLR.get db, 'glyph/王', 'FALLBACK', resume
    assert.deepEqual entry, {"id":"glyph/王","isa":"node","key":"glyph","format":null,"value":"王"}
    assert.equal db[ '%cache' ][ 'hit-count'  ], 1
    assert.equal db[ '%cache' ][ 'miss-count' ], 0
    # log TRM.pink entry
    # delete response[ 'dt' ]
    # log TRM.plum JSON.stringify response
    # assert.deepEqual response, {"~isa":"SOLR/response","url":"http://127.0.0.1:8983/solr/update/json?commit=true&wt=json","status":0,"error":null,"parameters":{},"results":[],"first-idx":null}
    # log TRM.pink db[ '%cache' ]
    # SOLR.CACHE.log_report db
    test.done()

#-----------------------------------------------------------------------------------------------------------
@using_get_with_invalid_id_and_fallback = ( test ) ->
  db      = SOLR.new_db()
  entries = do get_test_entries
  step ( resume ) =>*
    response  = yield SOLR.clear db, resume
    response  = yield SOLR.update db, entries, resume
    entry     = yield SOLR.get db, 'NOTEXIST', 'FALLBACK', resume
    assert.equal entry, 'FALLBACK'
    assert.equal db[ '%cache' ][ 'hit-count'  ], 0
    assert.equal db[ '%cache' ][ 'miss-count' ], 1
    # log TRM.pink entry
    # delete response[ 'dt' ]
    # log TRM.plum JSON.stringify response
    # assert.deepEqual response, {"~isa":"SOLR/response","url":"http://127.0.0.1:8983/solr/update/json?commit=true&wt=json","status":0,"error":null,"parameters":{},"results":[],"first-idx":null}
    # log TRM.pink db[ '%cache' ]
    # SOLR.CACHE.log_report db
    test.done()

#-----------------------------------------------------------------------------------------------------------
@using_async_retrieve = ( test ) ->
  db      = SOLR.new_db()
  entries = do get_test_entries
  step ( resume ) =>*
    response  = yield SOLR.clear db, resume
    response  = yield SOLR.update db, entries, resume
    id        = 'glyph/习'
    entry     = yield SOLR.CACHE.retrieve db, id, null, resume
    assert.deepEqual entry, {"id":"glyph/习","isa":"node","key":"glyph","format":null,"value":"习"}
    assert.equal db[ '%cache' ][ 'hit-count'  ], 1
    assert.equal db[ '%cache' ][ 'miss-count' ], 0
    SOLR.CACHE.log_report db
    test.done()

#-----------------------------------------------------------------------------------------------------------
@using_async_retrieve_with_fallback = ( test ) ->
  db      = SOLR.new_db()
  entries = do get_test_entries
  step ( resume ) =>*
    response  = yield SOLR.clear db, resume
    response  = yield SOLR.update db, entries, resume
    id        = 'NOTEXIST'
    retrieve  = ( db, id, handler ) =>
      # log TRM.cyan '©5o9', 'retrieving value from fallback method'
      handler null, { 'id': 'GENERATED', }
    entry     = yield SOLR.CACHE.retrieve db, id, retrieve, resume
    log TRM.orange JSON.stringify entry
    assert.deepEqual entry, { 'id': 'GENERATED', }
    assert.equal db[ '%cache' ][ 'hit-count'  ], 0
    assert.equal db[ '%cache' ][ 'miss-count' ], 1
    test.done()

#-----------------------------------------------------------------------------------------------------------
@using_sync_retrieve = ( test ) ->
  db      = SOLR.new_db()
  entries = do get_test_entries
  step ( resume ) =>*
    response  = yield SOLR.clear db, resume
    response  = yield SOLR.update db, entries, resume
    id        = 'glyph/习'
    entry     = SOLR.CACHE.retrieve_sync db, id, null
    assert.deepEqual entry, {"id":"glyph/习","isa":"node","key":"glyph","format":null,"value":"习"}
    assert.equal db[ '%cache' ][ 'hit-count'  ], 1
    assert.equal db[ '%cache' ][ 'miss-count' ], 0
    SOLR.CACHE.log_report db
    test.done()

#-----------------------------------------------------------------------------------------------------------
@using_sync_retrieve_with_fallback = ( test ) ->
  db      = SOLR.new_db()
  entries = do get_test_entries
  step ( resume ) =>*
    response  = yield SOLR.clear db, resume
    response  = yield SOLR.update db, entries, resume
    id        = 'NOTEXIST'
    retrieve  = ( db, id ) =>
      # log TRM.cyan '©5o9', 'retrieving value from fallback method'
      return { 'id': 'GENERATED', }
    entry     = SOLR.CACHE.retrieve_sync db, id, retrieve
    log TRM.orange JSON.stringify entry
    assert.deepEqual entry, { 'id': 'GENERATED', }
    assert.equal db[ '%cache' ][ 'hit-count'  ], 0
    assert.equal db[ '%cache' ][ 'miss-count' ], 1
    test.done()

#-----------------------------------------------------------------------------------------------------------
@low_level_search = ( test ) ->
  ### TAINT only works on otherwise empty DB after @update_several_entries has been run
  ###
  db = SOLR.new_db hostname: '127.0.0.1'
  #.........................................................................................................
  options =
    'result-count':   50
  #=========================================================================================================
  step ( resume ) =>*
    response  = yield SOLR._search db, '*:*', options, resume
    #.......................................................................................................
    entries = response[ 'results' ]
    assert.equal entries.length, 18
    # log TRM.pink response
    #   assert.equal entry[ 'name' ], 'I. C. Wiener'
    test.done()

# #-----------------------------------------------------------------------------------------------------------
# @high_level_search = ( test ) ->
#   ### TAINT only works on otherwise empty DB after @update_several_entries has been run
#   ###
#   db = SOLR.new_db hostname: '127.0.0.1'
#   #=========================================================================================================
#   step ( resume ) =>*
#     #.......................................................................................................
#     options =
#       'sort':           'score asc'
#       'first-idx':      0
#       'result-count':   50
#     #.......................................................................................................
#     response  = yield SOLR.search db, '*:*', resume
#     log TRM.rainbow response
#     #.......................................................................................................
#     for entry in response[ 'results' ]
#       # log TRM.rainbow entry
#       assert.equal entry[ 'id' ], '1234'
#       assert.equal entry[ 'name' ], 'I. C. Wiener'
#     test.done()

#-----------------------------------------------------------------------------------------------------------
@query = ( test ) ->
  db = SOLR.new_db()
  log TRM.orange db
  SOLR.search db, """key:/has.*/""", ( error, results ) ->
    throw new Error error if error?
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
  CACHE.wrap_and_register db, { id: 'id-1', foo: 42, bar: 'helo', isa: 'fancy' }
  CACHE.wrap_and_register db, { id: 'id-2', ding: yes, dong: no }
  CACHE.wrap_and_register db, { id: 'id-3', key: 'some-key', value: 'a value', isa: 'brunz' }
  CACHE.wrap_and_register db, { id: 'id-4', key: 'some-key', value: 'other value', isa: 'brunz' }
  return null

#-----------------------------------------------------------------------------------------------------------
@register_value_in_cache = ( test ) ->
  db = {}
  populate_cache db
  CACHE.log_report db
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
    CACHE.log_report db
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
    CACHE.log_report db
    assert.deepEqual db, {"%cache":{"~isa":"SOLR/cache","value-by-id":{"id-1":{"id":"id-1","foo":42,"bar":"helo","isa":"fancy"},"id-2":{"id":"id-2","ding":true,"dong":false},"id-3":{"id":"id-3","key":"some-key","value":"a value","isa":"brunz"},"id-4":{"id":"id-4","key":"some-key","value":"other value","isa":"brunz"},"id-88":{"id":"id-88","isa":"strange","key":"boring","value":"interesting"}},"count-by-type":{"fancy":1,"(unknown)":1,"brunz":2,"strange":1},"hit-count":0,"miss-count":1}}
    assert value is value_id_88
    test.done()

# #-----------------------------------------------------------------------------------------------------------
# @clear_fields = ( test ) ->
#   db      = SOLR.new_db()
#   SOLR.clear_fields db, 'factorial', ( error, report ) ->
#     throw error if error?
#     log report


############################################################################################################
# async_testing @main

test = done: ->
# @update_single_entry                    test
# @update_several_entries                 test
# @clear_db                               test
# @using_get_with_correct_id              test
# @using_get_with_invalid_id              test
# @using_get_with_fallback                test
# @using_get_with_invalid_id_and_fallback test
# @low_level_search                       test
# @high_level_search                      test
# @query                                  test
# @escaping                               test
# @assign_cache                           test
# @dont_assign_cache                      test
# @register_value_in_cache                test
# @retrieve_value_from_cache              test
# @retrieve_value_from_retrieve_method    test
# @using_async_retrieve                   test
# @using_async_retrieve_with_fallback     test
# @using_sync_retrieve                    test
# @using_sync_retrieve_with_fallback      test
@clear_fields                           test






