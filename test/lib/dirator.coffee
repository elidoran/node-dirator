assert  = require 'assert'
dirator = require '../../lib'

dirPaths  = require '../helpers/dir-paths.coffee'
filePaths = require '../helpers/file-paths.coffee'

checkSingle = (test, path) ->
  assert path, 'should have a single result'
  assert.equal test.paths[path.path], true, 'test shouldnt have ' + path.path

checkArray = (test, array, count) ->
  assert array, 'should have an array result'
  for thing in array
    assert.equal test.paths[thing.path], true, 'test shouldnt have ' + thing.path
  if count? then assert.equal array.length, count, 'array result should have ' + count

allPaths  = {}
allPaths[key] = value for key,value of dirPaths
allPaths[key] = value for key,value of filePaths

console.log 'dirPaths:',dirPaths
console.log 'filePaths:',filePaths
console.log 'allPaths:',allPaths

describe 'test dirator', ->
  tests =
    file: {count:Object.keys(filePaths).length, paths:filePaths, mode:'files'}
    dir:  {count:Object.keys(dirPaths).length, paths:dirPaths, mode:'dirs'}
    path: {count:Object.keys(allPaths).length, paths:allPaths, mode:'paths'}


  for type, test of tests
    do (type, test) ->

      describe "in #{type}-only mode", ->

        describe 'for array result', ->

          describe 'with option style', ->

            options = target:'test', only:[test.mode]

            describe 'in async mode', ->

              it "should provide array with #{test.count} #{test.mode}", (done) ->

                options[test.mode] = (result) ->
                  for thing in result
                    assert.equal test.paths[thing], true, "result shouldnt have #{type}: " + thing

                dirator options, (error, results) ->
                  if error? then return done error
                  assert.equal results?.found?[test.mode], test.count
                  assert.equal results.rejected.strings, 0, 'results shouldn\'t have rejected any strings'
                  assert.equal results.rejected.paths, 0, 'results shouldn\'t have rejected any paths'
                  done()

            describe 'in sync mode', ->

              it "should return array with #{test.count} #{test.mode}", ->

                results = dirator options
                checkArray test, results[test.mode]
                assert.equal results?[test.mode]?.length, test.count, "array should have #{test.count} results"
                assert.equal results?.found[test.mode], test.count, "array should have found #{test.count} results"
                assert.equal results.rejected.strings, 0, 'results shouldn\'t have rejected any strings'
                assert.equal results.rejected.paths, 0, 'results shouldn\'t have rejected any paths'


          describe "with #{test.mode}() style", ->

            describe 'in async mode', ->

              it "should provide array with #{test.count} #{test.mode}", (done) ->

                dirator[test.mode] target:'test', (error, results) ->
                  if error? then return done error
                  checkArray test, results[test.mode]
                done()

            describe 'in sync mode', ->

              it "should return array with #{test.count} #{test.mode}", ->
                options = target:'test'
                results = dirator[test.mode] options
                checkArray test, results[test.mode], test.count

                #  TODO: checkFound test, results.found[test.mode]
                assert.equal results?.found?[test.mode], test.count,
                  "should find #{test.count} results"

        describe "for per-#{type} result", ->

          describe 'with option style', ->

            it "should call callback #{test.count} times", (done) ->

              options = target:'test'
              options[type] = (result) -> checkSingle test, result

              dirator options, (error, results) ->
                if error? then return done error
                assert.equal results.found[test.mode], test.count
                done()

  describe 'with all options specified', ->

    it 'should gather all', (done) ->
      test = paths:allPaths
      options =
        target: 'test'
        acceptString: (path) -> true
        acceptPath  : (path) -> true
        file  : (file) -> checkSingle test, file
        dir   : (dir) -> checkSingle test, dir
        path  : (path) -> checkSingle test, path
        files : (files) -> checkArray test, files
        dirs  : (dirs) -> checkArray test, dirs
        paths : (paths) -> checkArray test, paths
        done: (error, results) ->
          if error? then return done error
          assert.equal results.rejected.strings, 0, 'should have rejected zero strings'
          assert.equal results.rejected.paths, 0, 'should have rejected zero paths'
          assert.equal results.found.files, tests.file.count
          assert.equal results.found.dirs,  tests.dir.count
          assert.equal results.found.paths, tests.path.count
          done()

      dirator options
