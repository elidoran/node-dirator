# Dirator
[![Build Status](https://travis-ci.org/elidoran/node-dirator.svg?branch=master)](https://travis-ci.org/elidoran/node-dirator)
[![Dependency Status](https://gemnasium.com/elidoran/node-dirator.png)](https://gemnasium.com/elidoran/node-dirator)
[![npm version](https://badge.fury.io/js/dirator.svg)](http://badge.fury.io/js/dirator)

Directory iterator with filters, individual and array callbacks/listeners, and both synchronous and asynchronous execution.

```javascript
// example: get all js files
require('dirator')({
  target: 'some/dir',
  acceptPath: function(path) {
    return path.endsWith('.js')
  },
  file: function(file) {
    // do something with each file
  },
  // must have done callback for async
  done: function(error, result) {
    // check for an error
    // use result...
  }
})
```


## Install

```
npm install dirator --save
```


## Table of Contents

1. [Usage - Asynchronous via Options](#usage-asynchronousviaoptions)
2. [Usage - Asynchronous via Events](#usage-asynchronousviaevents)
3. [Usage - Synchronous](#usage-synchronous)
4. [Results](#results)
5. [Modes](#modes)
6. [Convenience methods](#usage-conveniencemethods)
7. [Examples](#examples)


## Usage: Asynchronous via Options

You must specify a `done` callback to operate asynchronously.

This example uses all other options, however, only specify the options you want and `dirator` will do less work.

```javascript
var dirator = require('dirator');

dirator({

  // the starting directory path
  target: 'some/dir',

  // although all these can be specified,
  // only specify the ones you want.
  // except `done`. that's required to signal async.

  // return true to accept the path string.
  // each false return is counted
  acceptString: function(pathString) {
    return path.length > 5;
  },

  // return true to accept the path.
  // the `path` is an fspath instance.
  // each false return is counted.
  acceptPath: function(path) {
    return !path.endsWith('.tmp');
  },

  file: function(file)  {
    file.pipe(someTransform).pipe(targetStream);
  },

  files: function(files) {
    /* files is an array of fspath's */
  },

  dir  : function(dir)   {
    /* dir is an fspath */
  },

  dirs : function(dirs)  {
    /* dirs is an array of fspath's */
  },

  path : function(path)  {
    /* path is an fspath */
  },

  paths: function(paths) {
    /* paths is an array of fspath's */
  },

  done : function(error, results) {
      if (error) {
        /* do something with error and return... */
      }

      console.log(
        'Found',result.found.files,
        'files',
        result.found.dirs,
        'dirs, and',
        result.found.paths,
        'paths.'
      );

      console.log(
        'Rejected paths based on',
        result.rejected.strings,
        'path strings and',
        result.rejected.paths,
        'Path instances.'
      );
    }
});

// OR, to repeatedly use it:
var Dirator = require('dirator').Dirator
var dirator = new Dirator({
  target: 'some/dir'
  // all the options used above
});

// then run it.
// you can do this repeatedly.
dirator.run();
```


## Usage: Asynchronous via Events

You must specify a `done` event listener to operate asynchronously.

This example uses all other options, however, only specify the options you want and `dirator` will do less work.

```javascript
var Dirator = require('dirator').Dirator
  , dirator = new Dirator({target:'some/dir'});

// called for each file
dirator.on('file',  function(file) {});

// called for each directory with an array
// of fspath instances for each file
dirator.on('files', function(files) {});

// called for each accepted dir
dirator.on('dir',   function(dir) {});

// called for each directory with an array
// of fspath instances for each
// immediate sub-directory
dirator.on('dirs',  function(dirs) {});

// called for each accepted path
dirator.on('path',  function(path) {});

// called for each directory with an array
// of fspath instances for each path (file/directory)
dirator.on('paths', function(paths) {});

// called when it's all done iterating.
dirator.on('done',  function(error, result) {
  // do something with counts...
});

// now start the work.
// can be used repeatedly.
dirator.run();
```


## Usage: Synchronous

Without a `done` callback/listener `dirator` runs synchronously and provides all results at once in returned object.

TODO: It seems appropriate to allow adding event listeners when running synchronously because they are executed synchronously.  I may include this feature in a future version. For now, don't use callbacks/listeners without a `done` listener/callback.

```javascript
var Dirator = require('dirator').Dirator
  , dirator = new Dirator({target:'some/dir'});
  , result = dirator.run();

// OR:
var result = require('dirator')({
  target: 'some/dir'
})

result = {
  paths: [ /* array of all paths */ ]
  found: {
    paths: // <number>
  },
  rejected: {
    strings: 0,
    paths: 0
  }
}
```

## Results

The result contains different content depending on the [mode](#modes) it runs in. The results are cumulative, so, the more modes you specify the more results you will receive.

The results object always contains these:

A. **found** - an object containing the number found of each mode (type) specified

  ```javascript
  // specify all modes to get all counts
  results = dirator({ only:['files', 'dirs', 'paths'] })
  results = {
    found: { // leave out a mode above and this won't contain its count
      files: /* <number> */ ,
      dirs : /* <number> */ ,
      paths: /* <number> */
    }
  }
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

```javascript
var dirator = require('dirator');

dirator({
  only: ['dirs'],
  file: function(file) {
    /* this will never be called */
  },
  done: function(error, results) {
    // this will receive `results.dirs` because of the mode
  }
});
```


## Usage: Convenience methods

For common uses there are three functions on the package's exported object. By default, these will run synchronously in their corresponding mode and return the result with all corresponding types found by recursively iterating from the current working directory down. They also accept options as described above to customize their actions.

1. `files(options)`
2. `dirs(options)`
3. `paths(options)`

```javascript
var dirator = require('dirator')

// get all the files within 'src'
var result = dirator.files({ target: 'src' })

// get all the *.js files within 'src'
result = dirator.files({
  target: 'src',

  acceptString: function(pathString) {
    return '.js' === pathString.slice(-3)
  },

  // OR: use acceptPath as the filter:
  acceptPath: function(path) {
    return path.endsWith('.js')
  }
})
```


## Examples


### Get all JS files

Imagine a directory `'some/dir'` with JS files in it and within sub-directories.

```javascript
var dirator = require('dirator')

// Asynchronous:
dirator({
  target: 'some/dir',
  acceptString: function(pathString) {
    return '.js' === pathString.slice(-3)
  },
  // OR:
  acceptPath: function(path) {
    return path.endsWith('.js')
  },
  file: function(file) {
    // this is called once for each matching file.
    // for our example,
    // do something with the file
  },
  // must have done callback for async
  done: function(error, result) {
    // check for an error
    // use result...
  }
})

// Synchronous:
var result = dirator({
  target: 'some/dir',
  acceptString: function(pathString) {
    return '.js' === pathString.slice(-3)
  },
  // OR:
  acceptPath: function(path) {
    return path.endsWith('.js')
  }
})

result = {
  found: {
    paths: 1 // counts how many files/dirs were found
  },
  rejected: {
    paths: 0, // counts rejects, acceptPath returned false
    strings: 0 // counts rejects, acceptString returned false
  },
  paths: [
    // an `fspath` Path instance per file accepted
  ]
}
```


### Get all directories

```javascript
var dirator = require('dirator')

// Asynchronous:
dirator.dirs({
  target: 'some/dir',
  dir: function(dir) {
    // this is called once for each matching directory.
  },
  // must have done callback for async
  done: function(error, result) {
    // check for an error
  }
})

// Synchronous:
var result = dirator.dirs({ target: 'some/dir' })

result = {
  found: {
    dirs: 1 // counts how many directories were found
  },
  rejected: {
    paths: 0, // counts rejects, acceptPath returned false
    strings: 0 // counts rejects, acceptString returned false
  },
  dirs: [
    // an `fspath` Path instance per directory accepted
  ]
}


// Or, get them in chunks:
dirator.dirs({
  target: 'some/dir',
  dirs: function(dirs) {
    // dirs is an array of fspath Path instances.
    // as we iterate down thru directories we call this
    // with all the directories within one of the directories.
  },
  done: function(error) { /* ... */ }
})

```



## [MIT License](LICENSE)
