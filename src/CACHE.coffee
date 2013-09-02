
############################################################################################################
# njs_os                    = require 'os'
# njs_fs                    = require 'fs'
# njs_path                  = require 'path'
# njs_url                   = require 'url'
# mik_request               = require 'request' # https://github.com/mikeal/request
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
immediately               = setImmediate
# spawn                     = ( require 'child_process' ).spawn
# #...........................................................................................................
# default_options           = require '../options'


#===========================================================================================================
# CACHE
#-----------------------------------------------------------------------------------------------------------
### Cache is maintained on module level, as this library is not intented to work with more than a single
database collection—which means that IDs uniquely identify entries across our problem domain. ###
@_cache                   = {}
@_cache_node_entry_count  = 0
@_cache_edge_entry_count  = 0
@_cache_entry_count       = 0
@_cache_hit_count         = 0
@_cache_miss_count        = 0

#-----------------------------------------------------------------------------------------------------------
@assign_new_cache = ( carrier ) ->
  return null unless carrier[ 'use-cache' ] ? yes
  #.........................................................................................................
  carrier[ '%cache' ] =
    '~isa':           'SOLR/cache'
    'value-by-id':    {}
    'count-by-type':  {}
    'hit-count':      0
    'miss-count':     0
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@register = ( carrier, entry ) ->
  return null unless carrier[ 'use-cache' ] ? yes
  #.........................................................................................................
  id            = entry[   'id'          ]
  type          = entry[   'isa'         ] ? '(unknown)'
  cache         = carrier[ '%cache'      ]
  value_by_id   = cache[   'value-by-id' ]
  cached_entry  = value_by_id[ id ]
  #.........................................................................................................
  # log '©5t1', entry
  if cached_entry?
    throw new Error "another entry with ID #{rpr id} already exists" if entry isnt cached_entry
  #.........................................................................................................
  else
    value_by_id[ id ]                 = entry
    cache[ 'count-by-type' ][ type ]  = ( cache[ 'count-by-type' ][ type ] ? 0 ) + 1
  #.........................................................................................................
  return entry

#-----------------------------------------------------------------------------------------------------------
@retrieve = ( carrier, id, retrieve, handler ) ->
  ### Given a `carrier` object, an `id`, a `retrieve` method, and a callabck `handler`, try to locate a
  value with the desired ID in the cache; if a value is found, `handler` is called asynchronously.
  Otherwise, `retrieve carrier, id, handler` is called. ###
  #.........................................................................................................
  if use_cache = ( carrier[ 'use-cache' ] ? yes )
    cache         = carrier[ '%cache'      ]
    value_by_id   = cache[   'value-by-id' ]
    Z             = value_by_id[ id ]
    #.......................................................................................................
    if Z?
      cache[ 'hit-count' ] += 1
      return immediately -> handler null, Z
    #.......................................................................................................
    cache[ 'miss-count' ] += 1
  #.........................................................................................................
  immediately =>
    #.......................................................................................................
    retrieve carrier, id, ( error, result ) =>
      return handler error if error?
      @register carrier, result
      handler null, result
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@log_cache_report = ( carrier ) ->
  #.........................................................................................................
  if carrier[ 'use-cache' ] ? yes
    total         = 0
    cache         = carrier[ '%cache'      ]
    count_by_type = cache[ 'count-by-type' ]
    types         = ( name for name of count_by_type ).sort()
    log()
    log TRM.grey    '   ----------------------------'
    log TRM.orange  '   CoffeeNode SOLR/CACHE Report'
    log TRM.grey    '   ----------------------------'
    log()
    #.......................................................................................................
    for type, idx in types
      count   = count_by_type[ type ]
      total  += count
      log TRM.blue  " #{if idx is 0 then ' ' else '+'} #{count} entries of type #{type}"
    #.......................................................................................................
    log TRM.grey    '   ----------------------------'
    log TRM.blue    " = #{total} entries"
    log TRM.grey    '   ============================'
    log()
    log TRM.green   "   #{cache[ 'hit-count'  ]} cache hits"
    log TRM.red     " + #{cache[ 'miss-count' ]} cache misses"
    log TRM.grey    '   ----------------------------'
    log TRM.orange  " = #{cache[ 'hit-count' ] + cache[ 'miss-count' ]} cache accesses"
    log TRM.grey    '   ============================'
    log()
  #.........................................................................................................
  else
    log()
    log TRM.grey    '(cache not used for this object)'
    log()
  #.........................................................................................................
  return null

