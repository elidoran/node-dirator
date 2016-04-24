fs         = require 'fs'
corepath   = require 'path'
Path       = require 'fspath'

class Dirator extends (require 'events').EventEmitter
  constructor: (options, done) -> @_configure options, done

  _configure: (options = {}, done) ->
    @only = []
    @target = options.target ? process.cwd()

    done ?= options.done ? (if 'function' is typeof options then options)

    # when there's a `done` callback, add it and change processing to async
    if done?
      @on 'done', done
      @async = true

    # add the each callbacks, when specfied. add the type to `only`
    for event in ['file', 'dir', 'path']
      if options[event]?
        @on event, options[event]
        @only.push event + 's'

    # add the array callbacks, when specfied. add the type to `only`
    for event in ['files', 'dirs', 'paths']
      if options[event]?
        @on event, options[event]
        if event not in @only then @only.push event

    # store both accept filters provided (when not provided, they become undefined)
    for accept in ['acceptString', 'acceptPath']
      @['_' + accept] = options[accept]

    # always recurse unless options specify *not* to
    if options.recurse isnt false then @recurse = true

    # override `only` settings from events when `only` is explicitly set in options
    if options.only? then @only = options.only
    # if no `only` settings then default to only paths
    unless @only?.length then @only = ['paths']

  on: (event, listener) ->
    switch event
      when 'done'          then @async = true
      when 'file', 'files' then @only.push 'files'
      when 'dir',  'dirs'  then @only.push 'dirs'
      when 'path', 'paths' then @only.push 'paths'

    super event, listener

  run: (options, done) ->
    if options? then @_configure options, done
    unless @target? then throw new Error 'dirator requires a `target` to run'
    if @async then @_iterate [new Path @target] else @_iterateSync()

  _iterateSync: ->
    # TODO:
    #  adapt to use emit to send them instead of gathering it all up into arrays
    #  only when there *are* listeners. otherwise, return all the arrays.
    #  combine ops as in node-paths ...?
    results = found: {}, rejected: paths:0, strings:0
    emit = {}
    for type in ['files', 'dirs', 'paths']
      if type in @only
        results[type] = []
        results.found[type] = 0

    dirArray = [new Path @target]

    options = acceptString:@_acceptString, acceptPath:@_acceptPath

    while dirArray.length > 0
      dir = dirArray.pop()

      result = dir.list options

      results.rejected.paths   += result.rejected.paths
      results.rejected.strings += result.rejected.strings

      results.found.paths += result.paths.length if results.found?.paths?

      for path in result.paths
        results?.paths?.push path
        if path.isDir()
          results.found?.dirs += 1 if results.found?.dirs?
          dirArray.push path if @recurse
          results?.dirs?.push path
        else if path.isFile()
          results.found?.files += 1 if results.found?.files?
          results?.files?.push path

    return results

  _iterate: (dirArray, options) ->
    unless options?
      options = @_buildAsyncOptions dirArray
      dirArray.options = options

    if dirArray.length > 0
      dir = dirArray.pop()
      dir.list options.list # option actions take care of everything else
    else @emit 'done', undefined, options.results

  _buildAsyncOptions: (dirArray) ->

    action = {}  # holds temp arrays and *each* actions

    # holds statistics for `done`
    results = found: {}, rejected: paths:0, strings:0

    list = # holds options to give to path.list()
      acceptString: @_acceptString
      acceptPath: @_acceptPath
      each: (result) => # these also increment the results.found values
        action?.file? result
        action?.dir?  result
        action?.path? result
      all: (error, result) =>
        if error? then return @emit 'done', error, result
        action?.files? result # action.files doesn't use result...pass anyway
        action?.dirs?  result # action.dirs doesn't use result...pass anyway
        action?.paths? result
        results.rejected.paths   += result.rejected.paths
        results.rejected.strings += result.rejected.strings
        # now call this again if @recurse
        if @recurse then @_iterate dirArray, dirArray.options
        else @emit 'done', undefined, results

    if 'files' in @only
      action.tempFiles = []
      results.found.files = 0
      action.file = (result) => if result.path.isFile()
        action.tempFiles.push result.path
        result.file = result.path
        @emit 'file', result

      action.files = =>
        results.found.files += action.tempFiles.length
        @emit 'files', files:action.tempFiles
        delete action.tempFiles
        action.tempFiles = []

    if 'dirs' in @only
      action.tempDirs = []
      results.found.dirs = 0
      action.dir = (result) => if result.path.isDir()
        if @recurse then dirArray.push result.path
        action.tempDirs.push result.path
        result.dir = result.path
        @emit 'dir', result

      action.dirs = =>
        results.found.dirs += action.tempDirs.length
        @emit 'dirs', dirs:action.tempDirs
        delete action.tempDirs
        action.tempDirs = []

    else if @recurse
      action.dir = (result) ->
        if result.path.isDir() then dirArray.push result.path

    if 'paths' in @only
      results.found.paths = 0
      action.path  = (result) =>  @emit 'path', result
      action.paths = (result) =>
        results.found.paths += result.paths.length
        @emit 'paths', result

    return action:action, results:results, list:list # return options object

# Use three ways:
#  1. Dirator = require('dirator').Dirator
#  2. dirator = require('dirator')
#     dirator options
#  3. require('dirator') (options)
module.exports = (args...) -> new Dirator(args...).run()
module.exports.Dirator = Dirator
for type in ['files', 'dirs', 'paths']
  do (type) ->
    module.exports[type] = (options = {}, done) ->
      options.only = [type]
      options.done = done if done?
      new Dirator(options).run()
