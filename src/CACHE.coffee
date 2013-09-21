
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
immediately               = setImmediate
eventually                = process.nextTick
#...........................................................................................................
### used to build the MRU list; see https://github.com/qiao/heap.js ###
Heap                      = require 'heap'
#...........................................................................................................
### used to enable proxies; see https://github.com/tvcutsem/harmony-reflect ###
require 'harmony-reflect'


#===========================================================================================================
# TIME
#-----------------------------------------------------------------------------------------------------------
@_now = -> return 1 * new Date()

#-----------------------------------------------------------------------------------------------------------
@_update_mru = ( carrier, entry, method_name ) ->
  return entry unless carrier[ 'use-cache' ] ? yes
  cache = carrier[ '%cache' ]
  if ( mru = cache[ '%mru' ] )?
    entry[ '%touched' ] = @_now()
    mru[ if method_name is 'update' then 'updateItem' else 'push' ] entry
    while mru.size() > cache[ 'max-entry-count' ]
      oldest_entry  = mru.pop()
      id            = oldest_entry[ 'id' ]
      type          = oldest_entry[ 'isa' ]
      ### TAINT we should only delete enries that are known not to be referenced elsewhere ###
      delete cache[ 'value-by-id' ][ id ]
      ### TAINT use dedicated methods here; same applies to counting up (further down) ###
      cache[ 'purge-count' ] += 1
      cache[ 'count-by-type' ][ type ]  = ( cache[ 'count-by-type' ][ type ] ? 0 ) - 1
      log TRM.grey '©5r2', "deleted object with ID #{id}"
  return entry

#===========================================================================================================
# ENTRY WRAPPER
#-----------------------------------------------------------------------------------------------------------
@entry_wrapper =
  #.........................................................................................................
  get: ( target, name ) ->
    # log TRM.green ( rpr name )
    return true if name is '%is-wrapped'
    return target[ name ]
  #.........................................................................................................
  set: ( target, name, value ) ->
    # log TRM.red ( rpr name ), ( rpr value ), ( value isnt target[ name ] )
    ### avoid to mark entry as changed when it has been touched: ###
    return target[ name ] = value if name is '%touched'
    #.......................................................................................................
    target[ '%is-clean' ] = no if value isnt target[ name ]
    if value is undefined then delete target[ name ]
    else                       target[ name ] = value
    return value

#-----------------------------------------------------------------------------------------------------------
@_clean = ( carrier, entry ) ->
  entry[ '%is-clean' ] = yes
  return entry

#-----------------------------------------------------------------------------------------------------------
@_spoil = ( carrier, entry ) ->
  entry[ '%is-clean' ] = no
  return entry


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@_assign_new_cache = ( carrier, max_entry_count ) ->
  return null unless carrier[ 'use-cache' ] ? yes
  #.........................................................................................................
  if max_entry_count?
    mru = new Heap ( a, b ) -> return a[ '%touched' ] - b[ '%touched' ]
  else
    max_entry_count = Infinity
    mru             = null
  #.........................................................................................................
  carrier[ '%cache' ] =
    '~isa':             'SOLR/cache'
    '%mru':             mru
    'value-by-id':      {}
    'count-by-type':    {}
    'hit-count':        0
    'miss-count':       0
    'purge-count':      0
    'max-entry-count':  max_entry_count
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@wrap_and_register = ( carrier, entry ) ->
  unless entry[ '%is-wrapped' ]
    entry = Proxy entry, @entry_wrapper
    @_spoil carrier, entry
  #.........................................................................................................
  return entry unless carrier[ 'use-cache' ] ? yes
  #.........................................................................................................
  id            = entry[   'id'          ]
  type          = entry[   'isa'         ] ? '(unknown)'
  cache         = carrier[ '%cache'      ]
  value_by_id   = cache[   'value-by-id' ]
  cached_entry  = value_by_id[ id ]
  #.........................................................................................................
  # log '©5t1', entry
  if cached_entry?
    if entry isnt cached_entry
      throw new Error "another entry with ID #{rpr id} already exists: #{rpr cached_entry}"
    @_update_mru carrier, entry, 'update'
  #.........................................................................................................
  else
    value_by_id[ id ]                 = entry
    cache[ 'count-by-type' ][ type ]  = ( cache[ 'count-by-type' ][ type ] ? 0 ) + 1
    @_update_mru carrier, entry, 'push'
  #.........................................................................................................
  return entry

#-----------------------------------------------------------------------------------------------------------
@clear = ( carrier ) ->
  ### Given a `carrier` object, clear its cache. This will remove all entries in `cache[ 'value-by-id' ]`,
  and set all counters in `cache[ 'count-by-type' ]` to zero. This method does nothing in case `carrier` is
  configured not to use a cache. ###
  return null unless carrier[ 'use-cache' ] ? yes
  cache         = carrier[ '%cache'        ]
  value_by_id   = cache[   'value-by-id'   ]
  count_by_type = cache[   'count-by-type' ]
  #.........................................................................................................
  delete value_by_id[ id ] for id of value_by_id
  count_by_type[ type ] = 0 for type of count_by_type
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@retrieve = ( carrier, id, retrieve, handler ) ->
  ### Given a `carrier` object, an `id`, a `retrieve` method, and a callback `handler`, try to locate a
  value with the desired ID in the cache; if a value is found, `handler` is called. Otherwise, `retrieve
  carrier, id, handler` is called. Note that no matter how the value (if any) is retrieved—by locating it in
  the cache or by calling the supplied method—it will always act asynchronously. See `retrieve_sync` for a
  synchronous alternative. ###
  #.........................................................................................................
  if use_cache = ( carrier[ 'use-cache' ] ? yes )
    cache         = carrier[ '%cache'      ]
    value_by_id   = cache[   'value-by-id' ]
    Z             = value_by_id[ id ]
    #.......................................................................................................
    if Z?
      @_update_mru carrier, Z, 'update'
      cache[ 'hit-count' ] += 1
      return eventually -> handler null, Z
    #.......................................................................................................
    cache[ 'miss-count' ] += 1
  #.........................................................................................................
  eventually =>
    #.......................................................................................................
    retrieve carrier, id, ( error, result ) =>
      return handler error if error?
      result = @wrap_and_register carrier, result
      handler null, result
  #.........................................................................................................
  return null


#===========================================================================================================
# RESULTS REPORTING
#-----------------------------------------------------------------------------------------------------------
@log_report = ( carrier ) ->
  log @report carrier
  return null

#-----------------------------------------------------------------------------------------------------------
@report = ( carrier ) ->
  R   = []
  pen = ( P... ) -> R.push TRM.pen P...
  #.........................................................................................................
  if carrier[ 'use-cache' ] ? yes
    total         = 0
    cache         = carrier[ '%cache'      ]
    count_by_type = cache[ 'count-by-type' ]
    types         = ( name for name of count_by_type ).sort()
    pen()
    pen TRM.grey    '   ----------------------------'
    pen TRM.orange  '   CoffeeNode SOLR/CACHE Report'
    pen TRM.grey    '   ----------------------------'
    pen()
    #.......................................................................................................
    for type, idx in types
      count   = count_by_type[ type ]
      total  += count
      pen TRM.blue  " #{if idx is 0 then ' ' else '+'} #{count} entries of type #{type}"
    #.......................................................................................................
    pen TRM.grey    '   ----------------------------'
    pen TRM.blue    " = #{total} entries"
    pen TRM.grey    "   (#{cache[ 'purge-count'  ]} cache purges)"
    pen TRM.grey    '   ============================'
    pen()
    pen TRM.green   "   #{cache[ 'hit-count'  ]} cache hits"
    pen TRM.red     " + #{cache[ 'miss-count' ]} cache misses"
    pen TRM.grey    '   ----------------------------'
    pen TRM.orange  " = #{cache[ 'hit-count' ] + cache[ 'miss-count' ]} cache accesses"
    pen TRM.grey    '   ============================'
    pen()
  #.........................................................................................................
  else
    pen()
    pen TRM.grey    '(cache not used for this object)'
    pen()
  #.........................................................................................................
  return R.join ''

