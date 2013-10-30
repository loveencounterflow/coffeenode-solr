

###

all stored values (entries) must be JavaScript objects / PODs and serializable with `JSON.stringify`

each entry *must* have a member `id` (a string) that is unique across the entire collection


###


############################################################################################################
# njs_os                    = require 'os'
# njs_fs                    = require 'fs'
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
# suspend                   = require 'coffeenode-suspend'
# step                      = suspend.step
# collect                   = suspend.collect
# immediately               = setImmediate
# spawn                     = ( require 'child_process' ).spawn
#...........................................................................................................
default_options           = require '../options'


#===========================================================================================================
# DB CREATION
#-----------------------------------------------------------------------------------------------------------
@_get_options = ( user_options ) ->
  user_options ?= {}
  R             = {}
  #.........................................................................................................
  ### TAINT: these routes shoud be made configurable ###
  route_by_name =
    'update':         'update/json'
    'query':          'select'
  #.........................................................................................................
  for name, default_setting of default_options
    R[ name ] = default_setting
  #.........................................................................................................
  for name, user_setting of user_options
    R[ name ] = user_options[ name ]
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
  R           = @_get_options user_options
  R[ '~isa' ] = 'SOLR/db'
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
# RETRIEVAL
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
    url:      me[ 'urls' ][ 'query' ]
    json:     true
    body:     ''
    qs:
      q:      solr_query
      wt:     'json'
      # sort:   options[ 'sort'         ] ?= 'score desc'
      rows:   options[ 'result-count' ] ? 100
      start:  options[ 'first-idx'    ] ? 0
  #.........................................................................................................
  if ( fields = options[ 'fields' ] )?
    switch type = TYPES.type_of fields
      when 'text' then fields = fields.split /\s*,\s*|\s+/
      when 'list' then null
      else return handler new Error "unknown type for option 'fields': #{type}"
    request_options[ 'qs' ][ 'fl' ] = fields.join ','
  #.........................................................................................................
  # log TRM.cyan '©5t1', request_options
  @_query me, 'get', request_options, handler
  return null

#-----------------------------------------------------------------------------------------------------------
@count = ( me, solr_query, options, handler ) ->
  unless handler?
    handler = options
    options = null
  #.........................................................................................................
  options = if options? then Object.create options else {}
  options[ 'result-count' ] = 0
  #.........................................................................................................
  @_search me, solr_query, options, ( error, response ) ->
    return handler error if error?
    handler null, response[ 'count' ]
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@batch_search = ( me, query, options, handler ) ->
  ### Method to simplify paging over vast amounts of data. In this method, `options` is a mandatory
  argument, but it may be an empty object. With each iteration, its attributes `first-idx` and `page-nr`
  will be updated to reflect the current state; it is possible to re-set `options[ 'first-idx' ]` and / or
  `options[ 'result-count' ]` to influence the outcome of the next iteration.

  Besides the error as the customary first callback argument, the handler will be called with a list
  containing the documents of the current iteration or `null` in case the query has been exhausted. This
  means that the call may be conveniently placed inside a suspend-style `while` loop, as shown below.

  Usage example:

      f = ->
        step ( resume ) ->*
          db      = MOJIKURA.new_db()
          query   = ...
          options =
            'result-count':     15000
          #.......................................................................
          while ( batch = yield SOLR.batch_search db, query, options, resume )
            log TRM.green options, TRM.pink batch.length

  ###
  result_count  = options[ 'result-count' ]?= 500
  first_idx     = options[ 'first-idx'    ] = ( options[ 'first-idx' ] ? -result_count ) + result_count
  page_nr       = options[ 'page-nr'      ] = ( options[ 'page-nr'   ] ?             0 ) + 1
  #.........................................................................................................
  @search me, query, options, ( error, response ) ->
    return handler error if error?
    #.......................................................................................................
    handler null, if response[ 'results' ].length is 0 then null else response
  #.........................................................................................................
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
  @_get me, id, ( error, Z ) =>
    if error?
      if fallback isnt undefined and TEXT.starts_with error[ 'message' ], 'invalid ID: '
        return handler null, fallback
      return handler error
    handler null, Z
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@_get = ( me, id, handler ) ->
  #.........................................................................................................
  @_search me, "id:#{@quote id}", null, ( error, response ) =>
    return handler error if error?
    #.......................................................................................................
    results = response[ 'results' ]
    return handler new Error "invalid ID: #{rpr id}" if results.length is 0
    #.......................................................................................................
    Z = results[ 0 ]
    handler null, Z
  #.........................................................................................................
  return null


#===========================================================================================================
# UPDATES
#-----------------------------------------------------------------------------------------------------------
@update = ( me, entries, handler ) ->
  entries = [ entries ] unless TYPES.isa_list entries
  #.........................................................................................................
  options =
    url:      me[ 'urls' ][ 'update' ]
    json:     true
    body:     entries
    qs:
      # commit: true
      commit: false
      wt:     'json'
  #.........................................................................................................
  return @_update me, entries, options, handler

#-----------------------------------------------------------------------------------------------------------
@update_from_file = ( me, route, content_type, handler ) ->
  unless handler?
    handler       = content_type
    content_type  = 'text/json;charset=utf-8'
  #.........................................................................................................
  options =
    url:      me[ 'urls' ][ 'update' ]
    json:     true
    # body:     entries
    qs:
      # commit: true
      commit: false
      'stream.file':          route
      'stream.contentType':   content_type
  #.........................................................................................................
  return @_query me, 'post', options, handler

#-----------------------------------------------------------------------------------------------------------
@_update = ( me, entries, options, handler ) ->
  #.........................................................................................................
  @_query me, 'post', options, ( error, P... ) =>
    throw error if error?
    handler null, P...
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@commit = ( me, handler ) ->
  #.........................................................................................................
  options =
    url:      me[ 'urls' ][ 'update' ]
    json:     true
    body:     null
    qs:
      # commit: true
      commit: true
      wt:     'json'
  #.........................................................................................................
  @_query me, 'post', options, handler
  #.........................................................................................................
  return null


#===========================================================================================================
# REMOVAL
#-----------------------------------------------------------------------------------------------------------
@clear = ( me, handler ) ->
  #.........................................................................................................
  options =
    url:      me[ 'urls' ][ 'update' ]
    json:     true
    body:     { 'delete': { 'query': '*:*' } }
    qs:
      commit: true
      wt:     'json'
  #.........................................................................................................
  @_query me, 'post', options, handler
  #.........................................................................................................
  return null

# #-----------------------------------------------------------------------------------------------------------
# @clear_fields = ( me, field_names, handler ) ->
#   field_names   = [ field_names, ] unless TYPES.isa_list field_names
#   delete_fields = []
#   for field_name in field_names
#     delete_fields.push ( @escape field_name ).concat ':*'
#   delete_fields = delete_fields.join ' OR '
#   #.........................................................................................................
#   options =
#     url:      me[ 'urls' ][ 'update' ]
#     json:     true
#     body:     { 'delete': { 'query': delete_fields } }
#     qs:
#       commit: true
#       wt:     'json'
#   #.........................................................................................................
#   @_query me, 'post', options, handler
#   #.........................................................................................................
#   return null


#===========================================================================================================
# REQUEST HANDLER
#-----------------------------------------------------------------------------------------------------------
@_query = ( me, method, options, handler ) ->
  #.........................................................................................................
  mik_request[ method ] options, ( error, response ) =>
    return handler error if error?
    Z = @_new_response me, response
    # return handler Z[ 'error' ] if Z[ 'error' ]?
    # log TRM.pink '©5l2', Z
    if ( error = Z[ 'error' ] )?
      ### Some Solr errors do not come with a trace in error[ 'trace' ]... ###
      trace = error[ 'trace' ] ? error[ 'msg' ]
      trace = ( ( trace.split /\n/g )[ .. 10 ].join '\n' ).concat '\n...\n'
      handler new Error 'Lucene/Solr error:\n'.concat error[ 'msg' ], '\n', trace
    else
      handler null, Z
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@_new_response = ( me, http_response ) ->
  ### TAINT need to examine status code ###
  # log http_response
  http_request  = http_response[  'request'         ]
  body          = http_response[  'body'            ]
  request_url   = http_request[   'href'            ]
  error         = body[           'error'           ] ? null
  header        = body[           'responseHeader'  ]
  status        = header[         'status'          ]
  dt            = header[         'QTime'           ]
  parameters    = header[         'params'          ] ? {}
  solr_response = body[           'response'        ]
  #.........................................................................................................
  if solr_response?
    count         = solr_response[  'numFound'        ]
    first_idx     = solr_response[ 'start'    ]
    results       = solr_response[ 'docs'     ]
  else
    count         = 0
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
    'count':        count
    'first-idx':    first_idx
    'dt':           dt
  #.........................................................................................................
  return R



############################################################################################################











