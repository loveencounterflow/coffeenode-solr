

###

all stored values (entries) must be JavaScript objects / PODs and serializable with `JSON.stringify`

each entry *must* have a member `id` (a string) that is unique across the entire collection

each entry *should* have a member `isa` (a string) that specifies the type of the entry

unless `use-cache: no` is specified in the database object, all updates and retrievals will be cached to
ensure object identity (i.e. `( SOLR.get db_1, id_1 ) == ( SOLR.get db_2, id_2 )` will hold exactly when
`( db_1 == db_2 ) and ( id_1 == id_2 )` holds).

With `use-cache: no`, each `get` (and `search` etc) operation will return a new object, i.e.
`SOLR.get db_1, id_1 != SOLR.get db_2, id_2` will hold for any legal values of `db_1`, `db_2`, `id_1`,
`id_2`.

Note that this means that you may end up with the entire database content in memory if a single `db`
object is used extensively.

There is at present no way to invalidate cache entries or automatically update entries in the database that
were modified in the application.

###


############################################################################################################
njs_os                    = require 'os'
njs_fs                    = require 'fs'
njs_path                  = require 'path'
njs_url                   = require 'url'
mik_request               = require 'request' # https://github.com/mikeal/request
#...........................................................................................................
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
@CACHE                    = require './CACHE'


#===========================================================================================================
# DB CREATION
#-----------------------------------------------------------------------------------------------------------
@_get_options = ( user_options ) ->
  user_options ?= {}
  R             = {}
  #.........................................................................................................
  ### TAINT: these routes shoud be mage configurable ###
  route_by_name =
    'update':         'update/json'
    'query':          'select'
  #.........................................................................................................
  for name, default_value of default_options
    R[ name ] = user_options[ name ] ? default_value
  #.........................................................................................................
  base_route    = R[ 'base-route' ].replace /// ^ /* ( .*? ) /* $ ///g, '$1'
  R[ 'urls' ]   = {}
  #.........................................................................................................
  for name, route of route_by_name
    R[ 'urls' ][ name ] = njs_url.format
      protocol:       R[ 'protocol' ]
      hostname:       R[ 'hostname' ]
      port:           R[ 'port' ]
      pathname:       njs_path.join R[ 'base-route' ], route
  #.........................................................................................................
  return R

#-----------------------------------------------------------------------------------------------------------
@new_db = ( user_options ) ->
  options = @_get_options user_options
  #.........................................................................................................
  R =
    '~isa':       'SOLR/db'
    'options':    options
  #.........................................................................................................
  @CACHE._assign_new_cache R
  #.........................................................................................................
  return R


#===========================================================================================================
# QUERY ESCAPING & QUOTING
#-----------------------------------------------------------------------------------------------------------
@escape = ( me, text ) ->
  text = me unless text?
  return text.replace /// ( [ + \- & | ! () {} \[ \] ^ " ~ * ? : \\ / ] ) ///g, '\\$1'

#-----------------------------------------------------------------------------------------------------------
@quote = ( me, text ) ->
  text = me unless text?
  return '"'.concat ( text.replace /"/g, '\\"' ), '"'


#===========================================================================================================
# SEARCH
#-----------------------------------------------------------------------------------------------------------
@search = ( me, solr_query, options, handler ) ->
  #.........................................................................................................
  if handler?
    options ?= {}
  #.........................................................................................................
  else
    handler = options
    options = {}
  #.........................................................................................................
  return @_search me, solr_query, options, handler

#-----------------------------------------------------------------------------------------------------------
@_search = ( me, solr_query, options, handler ) ->
  options ?= {}
  #.........................................................................................................
  request_options =
    url:      me[ 'options' ][ 'urls' ][ 'query' ]
    json:     true
    body:     ''
    # headers:
    #   'Content-type': 'application/json'
    qs:
      q:      solr_query
      wt:     'json'
      sort:   options[ 'sort'         ] ?= 'score desc'
      rows:   options[ 'result-count' ] ?= 10
      start:  options[ 'first-idx'    ] ?= 0
  #=========================================================================================================
  @_request me, 'get', request_options, ( error, response ) =>
    #.......................................................................................................
    for entry in response[ 'results' ]
      @CACHE.register me, entry
    #.......................................................................................................
    handler null, response
  #=========================================================================================================
  return null

#-----------------------------------------------------------------------------------------------------------
@get = ( me, id, fallback, handler ) ->
  ### Given an `id`, call handler with corresponding value from DB or from cache. When ID is not found in
  the DB, handler will be called either with an error as first oder `fallback` as second argument. ###
  unless handler?
    handler   = fallback
    ### TAINT: shouldn't use `undefined` ###
    fallback  = undefined
  #.........................................................................................................
  misfit  = {}
  RETRIEVE FROM CACHE
  #=========================================================================================================
  @_search me, "id:#{@quote id}", null, ( error, response ) =>
    return handler error if error?
    #.......................................................................................................
    results = response[ 'results' ]
    #.......................................................................................................
    if results.length is 0
      return handler new Error "invalid ID: #{rpr id}" if fallback is undefined
      Z = fallback
    else
      Z = results[ 0 ]
    @CACHE.register me, Z
    handler null, Z
  #=========================================================================================================
  return null


#===========================================================================================================
# UPDATES
#-----------------------------------------------------------------------------------------------------------
@update = ( me, entries, handler ) ->
  entries = [ entries, ] unless TYPES.isa_list entries
  #.........................................................................................................
  options =
    url:      me[ 'options' ][ 'urls' ][ 'update' ]
    json:     true
    body:     entries
    qs:
      commit: true
      wt:     'json'
  #.........................................................................................................
  @_request me, 'post', options, handler
  return null


#===========================================================================================================
# REQUEST HANDLER
#-----------------------------------------------------------------------------------------------------------
@_request = ( me, method, options, handler ) ->
  #=========================================================================================================
  mik_request[ method ] options, ( error, response ) =>
    return handler error if error?
    Z = @_new_response me, response
    if Z[ 'error' ] is null then handler null, Z else handler new Error Z[ 'error' ][ 'msg' ]
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@_new_response = ( me, http_response ) ->
  ### TAINT need to examine status code ###
  http_request  = http_response[ 'request'  ]
  body          = http_response[ 'body'     ]
  request_url   = http_request[ 'href'      ]
  error         = body[ 'error'             ] ? null
  header        = body[ 'responseHeader'    ]
  status        = header[ 'status'          ]
  dt            = header[ 'QTime'           ]
  parameters    = header[ 'params'          ] ? {}
  solr_response = body[ 'response'          ]
  #.........................................................................................................
  if solr_response?
    first_idx     = solr_response[ 'start'    ]
    results       = solr_response[ 'docs'     ]
  else
    first_idx     = null
    results       = []
  #.........................................................................................................
  R =
    '~isa':         'SOLR/response'
    'url':          request_url
    'status':       status
    'error':        error
    'parameters':   parameters
    'results':      results
    'first-idx':    first_idx
    'dt':           dt
  #.........................................................................................................
  return R



############################################################################################################











