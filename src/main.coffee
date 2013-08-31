


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


#===========================================================================================================
# DB CREATION
#-----------------------------------------------------------------------------------------------------------
@_get_options = ( user_options ) ->
  user_options ?= {}
  R             = {}
  #.........................................................................................................
  ### TAINT: these routes shoud be mage configurable ###
  route_by_name =
    'update/json':    'update/json'
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
  return R


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------



# @start = ->
#   R = spawn './start-lucene'
#   #.........................................................................................................
#   R.stderr.on 'data', ( error ) =>
#     log TRM.red error
#   #.........................................................................................................
#   R.stdout.on 'data', ( data_buffer ) =>
#     log TRM.grey ( data_buffer.toString 'utf-8' ).trim()
#   #.........................................................................................................
#   R.on 'close', ( code ) =>
#     log TRM.red "Lucene terminated with error code #{code}"
#   #.........................................................................................................
#   return R

# #-----------------------------------------------------------------------------------------------------------
# @clear = ( handler ) ->
#   #.........................................................................................................
#   query =
#     ### TAINT url should go to options ###
#     url:  'http://localhost:8983/solr/update/json?commit=true'
#     headers:
#       'Accept':         'application/json'
#       'Content-type':   'application/json'
#     json:               { 'delete': { 'query': '*:*' } }
#   #.........................................................................................................
#   request query, ( error, response ) =>
#     return handler error if error?
#     # log TRM.steel response[ 'body' ]
#     handler null, response[ 'body' ]

# #-----------------------------------------------------------------------------------------------------------
# @post_xml = ( me, route, handler ) ->
#   #.........................................................................................................
#   ### TAINT url should go to options ###
#   url     =  'http://localhost:8983/solr/update/json?softCommit=true'
#   stream  = njs_fs.createReadStream route
#   stream.pipe request.post url
#   stream.on 'finish', ->
#     handler null
#   # request query, ( error, response ) =>
#   #   return handler error if error?
#   #   # log TRM.steel response[ 'body' ]
#   #   handler null, response[ 'body' ]

# #-----------------------------------------------------------------------------------------------------------
# @post_json = ( me, route, handler ) ->
#   throw new Error "not implemented"

# #-----------------------------------------------------------------------------------------------------------
# @solr_query_from_web_query = ( web_query, format, term_joiner ) ->
#   #.........................................................................................................
#   # `format` specifies how / which fields are queried; we have `levenshtein` for the edit similarity,
#   # searched over normalized fields stored as unanalyzed strings, and `ngram` for nGram similarity
#   # searched over nGram-indexed fields.
#   switch format
#     when 'levenshtein'
#       format = 'edit'
#     when 'ngram'
#       format = 'ngram'
#     when 'literal'
#       format = 'literal'
#     else
#       throw new Error "unknown SOLR query format: #{rpr format}"
#   #.........................................................................................................
#   if format is 'literal'
#     address = web_query[ 'address' ].trim()
#     q       = """isa:"address" AND address_s:#{address}"""
#     #.......................................................................................................
#     R =
#       ### TAINT url should go to options ###
#       url:  'http://localhost:8983/solr/select'
#       qs:
#         q:      q
#         hl:     true
#         'hl.fl':  'address_s'
#         wt:     'json'
#         rows:   30
#     return [ no, ( address: address ), R, ]
#   #.........................................................................................................
#   # `term_joiner` specifies how to join terms when more than one field is queried. Due to the way we
#   # are building queries, there is `sum` and `product` available to aggregate edit similarities when
#   # searching with format `levenshtein`.
#   #
#   # ERASED: while `and`, `or` are used to join fields to aggregate nGram searches:
#   #.........................................................................................................
#   if format is 'edit'
#     switch term_joiner
#       when 'sum', 'product'
#         null # term_joiner = term_joiner
#       else
#         throw new Error "unknown SOLR term joiner for format levenshtein: #{rpr term_joiner}"
#   #.........................................................................................................
#   # For format `ngram`:
#   else
#     switch term_joiner
#       when null
#         null
#       # when 'and'
#       #   term_joiner = ' AND '
#       # when 'or'
#       #   term_joiner = ' OR '
#       else
#         throw new Error "unknown SOLR term joiner for format ngram: #{rpr term_joiner}"
#   #.........................................................................................................
#   address     = web_query[ 'address'  ].trim()
#   postcode    = web_query[ 'postcode' ].trim()
#   city        = web_query[ 'city'     ].trim()
#   street      = web_query[ 'street'   ].trim()
#   is_detailed = no
#   norms       = {}
#   #.........................................................................................................
#   # Detailed query using `postcode` ∨ `city` ∨ `street`:
#   if postcode.length > 0 or city.length > 0 or street.length > 0
#     is_detailed             = yes
#     norms[ 'postcode' ]     =                        postcode  if postcode.length > 0
#     norms[ 'city'     ]     = HELPERS.normalize_name city      if     city.length > 0
#     norms[ 'street'   ]     = HELPERS.normalize_name street    if   street.length > 0
#     web_query[ 'address' ]  = HELPERS.generate_address postcode, city, street
#   #.........................................................................................................
#   # General query, using only `address`:
#   else if address.length isnt 0
#     address_norm = HELPERS.normalize_name address
#   #.........................................................................................................
#   # No query if all fields are empty:
#   else
#     return [ null, null, null, ]
#   #.........................................................................................................
#   R =
#     ### TAINT url should go to options ###
#     url:  'http://localhost:8983/solr/select'
#     qs:
#       q:      null
#       sort:   null
#       wt:     'json'
#       rows:   30
#   #.........................................................................................................
#   # Formulation of detailed queries:
#   if is_detailed
#     # q     = ( "#{name}_norm:*" for name of norms ).join ' AND '
#     # sort  = ( "strdist(\"#{norm}\",#{name}_norm,edit)" for name, norm of norms )
#     # if sort.length is 1
#     #   sort = sort[ 0 ] + ' desc'
#     # else
#     #   sort = "#{term_joiner}(#{sort.join ','}) desc"
#     # R[ 'qs' ][ 'q'    ] = """isa:"address" AND """ + q
#     # R[ 'qs' ][ 'sort' ] = sort
#     q     = [ """isa:"address" AND (""", ]
#     q.push ( """#{name}_norm:(#{value})""" for name, value of norms ).join ' AND '
#     q.push ')'
#     R[ 'qs' ][ 'q' ] = q.join ' '
#   #.........................................................................................................
#   # Formulation of general queries:
#   else
#     if format is 'edit'
#       R[ 'qs' ][ 'q'    ] = """isa:"address" AND address:*"""
#       R[ 'qs' ][ 'sort' ] = """strdist("#{address_norm}",address_norm,#{format}) desc"""
#     else
#       words = address_norm.split /\s+/
#       # q     = '(' + ( ( "address_ngram:#{word}~" for word in words ).join term_joiner ) + ')'
#       # q     = 'address_ngram:(' + ( ( "#{word}~" for word in words ).join ' ' ) + ')'
#       # q     = """address_ngram:(#{address_norm})"""
#       # q     = 'address_ngram:("' + address_norm + '")'
#       # q     = 'address_ngram:(' + ( ( "#{word}" for word in words ).join ' ' ) + ')~'
#       R[ 'qs' ][ 'q'    ] = """isa:"address" AND address_ngram:(#{address_norm})"""
#   #.........................................................................................................
#   log '©5r2', TRM.grey 'query:', R[ 'qs' ][ 'q' ]
#   log '©5r2', TRM.grey 'sort:', R[ 'qs' ][ 'sort' ] if R[ 'qs' ][ 'sort' ]?
#   return [ is_detailed, norms, R, ]

#-----------------------------------------------------------------------------------------------------------
# @search = ( postcode, city, street, address, handler ) ->
@search = ( web_query, format, term_joiner, handler ) ->
  # return handler null, null unless city? or street?
  # query = @solr_query_from_web_query postcode, city, street, address
  [ is_detailed
    norms
    solr_query ] = @solr_query_from_web_query web_query, format, term_joiner
  log TRM.steel '©6z3', solr_query
  return handler null, null unless solr_query?
  #=========================================================================================================
  request solr_query, ( error, response ) =>
    # log error
    return handler error if error?
    #.......................................................................................................
    response            = JSON.parse response[ 'body' ]
    header              = response[ 'responseHeader' ]
    error               = response[ 'error' ]
    return handler error[ 'msg' ] ? error[ 'trace' ] if error?
    result              = response[ 'response' ]
    log TRM.pink  response[ 'highlighting' ]
    # log TRM.pink result
    #.....................................................................................................
    Z =
      'dt':             header[ 'QTime' ]
      'web-query':      web_query
      'solr-query':     solr_query
      'hit-count':      result[ 'numFound' ]
      'first-idx':      result[ 'start' ]
      'is-detailed':    is_detailed
      'entries':        result[ 'docs' ]
    #.......................................................................................................
    # log '©6z9', TRM.gold is_detailed
    #.......................................................................................................
    handler null, Z

#===========================================================================================================
# UPDATES
#-----------------------------------------------------------------------------------------------------------
@update = ( me, document, handler ) ->
  url     = me[ 'options' ][ 'urls' ][ 'update/json' ]
  #.........................................................................................................
  options =
    # headers:
    #   'Content-type':   'text/json'
    url:      url
    qs:
      commit: true
      # wt:     'json'
      # q:      q
      # hl:     true
      # 'hl.fl':  'address_s'
      # rows:   30
  #=========================================================================================================
  log '©7e7', TRM.pink options
  mik_request options, ( error, response) =>
    return handler error if error?
    handler null, response
  #.........................................................................................................
  return null

# #-----------------------------------------------------------------------------------------------------------
# @update_from_file = ( me, route ) ->
#   url     = me[ 'options' ][ 'urls' ][ 'update/json' ]
#   stream  = njs_fs.createReadStream route
#   stream.pipe request.post url
#   #.........................................................................................................
#   stream.on 'error', =>
#     handler null
#   #.........................................................................................................
#   stream.on 'finish', =>
#     handler null


############################################################################################################




