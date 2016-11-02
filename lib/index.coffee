fs         = require 'fs'
corepath   = require 'path'
Path       = require 'fspath'

class Dirator extends require('events').EventEmitter

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
    # handle some extra implied stuff based on adding listeners.
    # if they add a done() listener, then process asynchronously.
    # if they listen to events for a mode, add that mode to what we do.
    switch event
      when 'done'          then @async = true
      when 'file', 'files' then @only.push 'files'
      when 'dir',  'dirs'  then @only.push 'dirs'
      when 'path', 'paths' then @only.push 'paths'

    # always perform the on() operation
    super event, listener

  run: (options, done) ->

    # if they specified options, done, or both, then reconfigure
    if arguments.length > 0 then @_configure options, done

    # there must be a `target` for us to start at
    unless @target? then throw new Error 'dirator requires a `target` to run'

    # use two different processing styles based on the `async` setting
    if @async then @_iterate [new Path @target] else @_iterateSync()


  _iterateSync: ->
    # TODO:
    #  adapt to use emit to send them instead of gathering it all up into arrays
    #  only when there *are* listeners. otherwise, return all the arrays.
    #  combine ops as in node-paths ...?

    # hold all results info in this as we do all the work
    results = found: {}, rejected: paths:0, strings:0

    emit = {}

    # if these modes are enabled, then gather their stuff and counts
    for type in ['files', 'dirs', 'paths']
      if type in @only
        results[type] = []
        results.found[type] = 0

    # begin at the target path.
    # if it has directories, and `recurse` is on, then we'll add them to
    # this array, and keep processing this until there aren't anymore.
    dirArray = [new Path @target]

    # get configured filters
    options = acceptString:@_acceptString, acceptPath:@_acceptPath

    # keep processing directories in the array until there aren't any more.
    # when we find more directories we append them to the array
    while dirArray.length > 0

      # process last dir so we continue down into a directory until there
      # aren't anymore, then, we go back up to the dir which led us there
      # and begin the next directory there.
      # basically, this makes us traverse the directories in a sensible order
      dir = dirArray.pop()

      # use dir's list() operation to see what we have in this dir
      result = dir.list options

      # update `results` counts from this `result`
      results.rejected.paths   += result.rejected.paths
      results.rejected.strings += result.rejected.strings
      # this one is conditional because we may not be tracking paths
      results.found.paths += result.paths.length if results.found?.paths?

      # look at each path the list() op found
      for path in result.paths

        # if we're tracking paths, then store each path
        results?.paths?.push path

        # if it's a directory
        if path.isDir()

          # update the count only if we're tracking directories
          results.found?.dirs += 1 if results.found?.dirs?

          # only add this directory to our workload if `recurse` is on
          dirArray.push path if @recurse

          # add directory to our results only if we're tracking them
          results?.dirs?.push path

        # if it's a file then conditionally track the count and the file
        else if path.isFile()
          results.found?.files += 1 if results.found?.files?
          results?.files?.push path

    # loop is complete, so, return all our results
    return results


  _iterate: (dirArray, options) ->

    # won't have options the first time. later times provide it
    # to keep the operation going
    unless options?
      options = @_buildAsyncOptions dirArray
      dirArray.options = options

    # if there's another directory to iterate then pop() it and do a list() op
    if dirArray.length > 0
      dir = dirArray.pop()
      dir.list options.list # option actions take care of everything else

    # all done, so, emit the event
    else @emit 'done', undefined, options.results


  _buildAsyncOptions: (dirArray) ->

    action = {}  # holds temp arrays and actions

    # holds statistics for `done`
    results = found: {}, rejected: paths:0, strings:0

    list = # holds options to give to path.list()
      acceptString: @_acceptString
      acceptPath: @_acceptPath

      each: (result) => # these also increment the results.found values

        # call each actions with conditional '?' in case they don't exist
        action.file? result
        action.dir?  result
        action.path? result

      all: (error, result) =>

        if error? then return @emit 'done', error, result

        # call each actions with conditional '?' in case they don't exist
        action.files? result # action.files doesn't use result...pass anyway
        action.dirs?  result # action.dirs doesn't use result...pass anyway
        action.paths? result

        results.rejected.paths   += result.rejected.paths
        results.rejected.strings += result.rejected.strings

        # now call this again if @recurse
        if @recurse then @_iterate dirArray, dirArray.options
        else @emit 'done', undefined, results

    # if the 'files' mode is active
    if 'files' in @only
      # prep stuff to do file/files stuff
      action.tempFiles = []
      results.found.files = 0

      # provide a 'file' action
      action.file = (result) =>
        if result.path.isFile()
          action.tempFiles.push result.path
          result.file = result.path
          @emit 'file', result

      # provide a 'files' action
      action.files = =>
        results.found.files += action.tempFiles.length
        @emit 'files', files:action.tempFiles
        action.tempFiles = []

    # if the 'dirs' mode is active
    if 'dirs' in @only

      action.tempDirs = []
      results.found.dirs = 0

      # provide a 'dir' action
      action.dir = (result) =>
        if result.path.isDir()
          if @recurse then dirArray.push result.path
          action.tempDirs.push result.path
          result.dir = result.path
          @emit 'dir', result

      # provide a 'dirs' action
      action.dirs = =>
        results.found.dirs += action.tempDirs.length
        @emit 'dirs', dirs:action.tempDirs
        action.tempDirs = []

    # if `recurse` is on then provide a 'dir' action, not because
    # they want each dir, but to add new dirs to traverse into
    else if @recurse
      action.dir = (result) ->
        if result.path.isDir() then dirArray.push result.path

    # if the 'paths' mode is active
    if 'paths' in @only

      results.found.paths = 0

      # provide a 'path' action (we're only emitting, so, bind it)
      action.path = @emit.bind this, 'path'

      # provide a 'paths' action
      action.paths = (result) =>
        results.found.paths += result.paths.length
        @emit 'paths', result

    return action:action, results:results, list:list # return options object


# Use three ways:
#  1. Dirator = require('dirator').Dirator
#  2. dirator = require('dirator')
#     dirator options
#  3. require('dirator')(options)
module.exports = (args...) -> new Dirator(args...).run()
module.exports.Dirator = Dirator

# Provide convenience functions prebuilt with mode:
#   dirator.files()
#   dirator.dirs()
#   dirator.paths()
for type in ['files', 'dirs', 'paths']
  do (type) ->
    module.exports[type] = (options = {}, done) ->
      options.only = [type]
      options.done = done if done?
      new Dirator(options).run()
