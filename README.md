# Dirator

Directory iterator with filters, each and array callbacks/listeners, and both synchronous and asynchronous execution.

## Install

```
npm install dirator --save
```

## Usage: Asynchronous via Options

You must specify a `done` callback to operate asynchronously.

This example uses all other options, however, only specify the options you want and `dirator` will do less work.

```coffeescript
dirator = require 'dirator'

dirator
  target: 'some/dir'
  # although all these can be specified, you should only specify the ones you want
  acceptString: (pathString) -> path.length > 5 # each false return is counted
  accept: (path) -> not path.endsWith '.tmp'    # each false return is counted
  file  : (result) -> result.file.pipe(someTransform).pipe(targetStream)
  files : (result) -> # result.files
  dir   : (result) -> # result.dir
  dirs  : (result) -> # result.dirs
  path  : (result) -> # result.path
  paths : (result) -> # result.paths
  done  : (error, results) ->
    if error? then # do something with error and return...
    console.log "Found #{result.found.files} files,
      #{result.found.dirs} dirs, and #{result.found.paths} paths."
    console.log "Rejected paths based on #{result.rejected.strings} path strings
      and #{result.rejected.paths} Path instances."

# OR:
{Dirator} = require 'dirator' # JS: Dirator = require('dirator').Dirator
dirator = new Dirator
  target: 'some/dir'
  # all the options used above
dirator.run()
```


## Usage: Asynchronous via Events

You must specify a `done` event listener to operate asynchronously.

This example uses all other options, however, only specify the options you want and `dirator` will do less work.

```coffeescript
Dirator = require 'dirator'

dirator = new Dirator target:'some/dir'

dirator.on 'file',  (result) -> # result.file : each file listed in current dir
dirator.on 'files', (result) -> # result.files: files listed in current dir
dirator.on 'dir',   (result) -> # result.dir  : each accepted dir in current dir
dirator.on 'dirs',  (result) -> # result.dirs : directories listed in current dir
dirator.on 'path',  (result) -> # result.path : each accepted path in current dir
dirator.on 'paths', (result) -> # result.paths: all accepted paths from current dir
dirator.on 'done',  (error, result) -> # do something with counts...

dirator.run()
```


## Usage: Synchronous

Without a `done` callback/listener dirator runs synchronously and provides all results at once in returned object.

TODO: It seems appropriate to allow adding event listeners when running synchronously because they are executed synchronously.  I may include this feature in a future version. For now, don't use callbacks/listeners without a `done` listener/callback.

```coffeescript
Dirator = require 'dirator'

dirator = new Dirator target:'some/dir'

result = dirator.run()

# result =
#   paths: array of all paths
#   found:
#     paths: <number>
#   rejected:
#     strings: 0
#     paths: 0
```

## Results

The result contains different content depending on the [mode](#modes) it runs in. The results are cumulative, so, the more modes you specify the more results you will receive.

The results object always contains these:

A. **found** - an object containing the number found of each mode (type) specified

  ```coffeescript
  # specify all modes to get all counts
  results = dirator only:['files','dirs','paths']
  # results =
  #   found: # leave out a mode above and this won't contain its count
  #     files: <number>
  #     dirs : <number>
  #     paths: <number>
  ```

B. **rejected** - an object containing two numbers:
  1. **strings** - the number of paths rejected by the acceptString filter
  2. **paths** - the number of paths rejected by the acceptPath filter



The results object only contains these when its corresponding mode is specified:

1. **result.paths** - available when the `paths` mode is specified (the default mode)
2. **result.files** - available when the `files` mode is specified (using `dirator.files()` sets this mode)
3. **result.dirs** - available when the `dirs` mode is specified (using `dirator.dirs()` sets this mode)

## Modes

Dirator performs differently depending on which *modes* it runs with.

It operates in `paths` mode by default.

There are three modes:

A. **paths**
  1. only provides paths in results object: `result.paths`
  2. only calls the `path` and `paths` callbacks/listeners.
  3. will iterate through directories to find all paths

B. **files**
  1. only provides files in results object: `result.files`
  2. only calls the `file` and `files` callbacks/listeners.
  3. will iterate through directories to find all files

C. **dirs**
  1. only provides dirs in results object: `result.dirs`
  2. only calls the `dir` and `dirs` callbacks/listeners.
  3. will iterate through directories to find all directories

The mode can be affected in three ways:

1. set the `only` property of options to an array containing one or more of: paths, files, or dirs.
2. specify callbacks/listeners and their corresponding mode will be added. For example, the `file` and `files` options/listeners will add the `files` mode.
3. specify a single mode by using a direct function for the mode: `dirator.files()`, `dirator.dirs()`, and the default does the *paths* mode: `dirator()`.

Note: If you specify *both* the modes to use and a callback/listener which is *not* part of those modes, then they will *not* be called. For example:

```coffeescript
dirator = require 'dirator'
dirator
  only: ['dirs']
  file: (result) -> # this will never be called
  done: (error, results) -> # this will receive `results.dirs` because of the mode
```  

### MIT License
