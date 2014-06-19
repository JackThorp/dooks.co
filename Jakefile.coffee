#!/usr/bin/env coffee
# vi: set foldmethod=marker
fs        = require 'fs'
path      = require 'path'
sSplitter = require 'stream-splitter'
$q        = require 'q'
coffee    = require 'coffee-script'
spawn     = (require 'child_process').spawn

# Log Styles ###########################################
 
(styles = {# {{{
  # Styles
  bold: [1, 22],        italic: [3, 23]
  underline: [4, 24],   inverse: [7, 27]

  # Grayscale
  white: ['01;38;5;271', 0],    grey: ['01;38;5;251', 0]
  black: ['01;38;5;232', 0]

  # Colors
  blue: ['00;38;5;14', 0],      purple: ['00;38;5;98', 0]
  green: ['01;38;5;118', 0],    orange: ['00;38;5;208', 0]
  red: ['01;38;5;196', 0],      pink: ['01;38;5;198', 0]

})

# Configures for colors and styles
stylize = (str, style) ->
  [p,s] = styles[style]
  `'\033'`+"[#{p}m#{str}"+`'\033'`+"[#{s}m"

# Hack String to hook into our styles
(Object.keys styles).map (style) ->
  String::__defineGetter__(style, -> stylize @, style)# }}}

# Build Helpers ########################################

# Takes a prefix and a writeable stream _w. Returns a stream that when# {{{
# written too, will pipe input to _w, prefixed with pre on every newline.
pipePrefix = (pre, _w) ->
  sstream = sSplitter('\n')
  sstream.encoding = 'utf8'
  sstream.on 'token', (token) ->
    _w.write pre+token+'\n'
  return sstream

# Run the given commands sequentially, returning a promise for
# command resolution.
chain = (cmds..., opt) ->
  run = (cmd, cmds...) ->
    [exe, args, fmsg, check, wd] = cmd
    check ?= (err) -> err == 0
    wd ?= __dirname
    prompt "#{exe} #{args.join ' '}"
    prog = spawn exe, args, cwd: wd || __dirname
    prog.stdout.pipe pOut
    prog.stderr.pipe pErr
    prog.on 'exit', (err) ->
      do newline if cmds.length is 0
      if !check err
        def.reject err, fmsg
      else if cmds.length != 0 then run cmds...
      else
        do def.resolve

  def = $q.defer()
  promise = def.promise

  # Process last argument
  if opt instanceof Array
    if opt.length == 1
      [smsg] = opt
      promise.then ->
        succeed smsg
      promise.catch (err, fmsg) ->
        fail "[#{err}] #{fmsg}"
      opt = null
  cmds.push opt if opt?

  # Run commands
  do newline
  run cmds... if cmds.length > 0
  def.promise

# Recursively list files/folders
lsRecursive = (dir) ->
  [files, folders] = fs.readdirSync(dir).reduce ((a,c) ->
    target = "#{dir}/#{c}"
    isDir = fs.statSync(target).isDirectory()
    a[+(isDir)].push target; a), [[],[]]
  files.concat [].concat (folders.map (dir) -> lsRecursive dir)...# }}}

# Logging Aliases ######################################

# Prints message as a white title# {{{
title = (msg) ->
  console.log "\n> #{msg}".white

# Standard logged output
log = (msg) ->
  console.log msg.split(/\r\n/).map((l) -> "  #{l}").join ''

# Alias for empty console.log
newline = console.log

# Print green success message, partner to initial log
succeed = (msg) ->
  console.log "+ #{msg}\n".green

# Halts build chain
fail = (msg) ->
  console.error "! #{msg}\n".red
  throw new Error msg

# Prints command as if from prompt
prompt = (cmd) ->
  console.log "$ #{cmd}"
pOut = pipePrefix '  ', process.stdout
pErr = pipePrefix '  ', process.stderr# }}}

# Dev Tasks ############################################

desc 'By default, start the dev server'
task 'default', ['start-dev']

desc 'Start dev node server'
task 'start-dev', [], async: true, ->
  title 'Starting nodemon dev server'# {{{
  server = spawn\
  ( 'nodemon'
  , ['server.coffee', '-w', 'server.coffee']
  , stdio: ['ignore', 'pipe', 'pipe'] )
  do newline
  server.stderr.pipe process.stderr
  stdout = pipePrefix '  ', process.stdout
  server.stdout.pipe stdout# }}}

# Deploy Tasks #########################################

# Temporary path for deployment
DEPLOY_DIR = path.join __dirname, 'deploy'
JADE_DIR = path.join __dirname, 'jade'
CSS_DIR = path.join __dirname, 'css'
IMG_DIR = path.join __dirname, 'imgs'

# Load compilation function
compileTools = require './server'

#"AAHhbQ9D8d0BAKmQokl0ZCg3dQzotngG6iEQ9ALbP7XKYsKx3dNA4zzpiVZBBNTItDcTiUI5JXTBNdu1i6sFHJ1X5Hu2JOXeoLt3uwWka5RAykFSkPTY8PALiaxZCZBjDbsaVUvvah0JVVQadfQNtzF467IfdFZBG0D8FMdz3ZAkeN92twZAoGrPprcRtKjqVoZD" Sets process environment to allow for git operations out of tree
setGitDir = (dir) ->
  process.env.GIT_WORK_TREE = GIT_WORK_TREE = dir
  process.env.GIT_DIR = GIT_DIR = path.join GIT_WORK_TREE, '.git'

# Get all jade files inside JADE_DIR
jadeFiles = lsRecursive JADE_DIR
  .filter (jf) -> !/layout\.jade$/.test(jf) and /\.jade$/.test(jf)

# Get all css files inside CSS_DIR
cssFiles = lsRecursive CSS_DIR
  .filter (cf) -> /\.css$/.test(cf)

imgFiles = lsRecursive IMG_DIR
  .filter (imf) -> /\.jpg$/.test(imf) 

desc 'Creates new CNAME file in deploy repo'
file './deploy/CNAME', ['create-deploy-dir'], async: true, ->
  title 'Creating CNAME alias'# {{{
  fs.writeFile './deploy/CNAME', 'dooks.co', 'utf8', (err) ->
    if err? then fail 'Failed to create CNAME'
    else succeed 'Successfully created CNAME file'# }}}

desc 'Creates temporary deploy directory'
task 'create-deploy-dir', [], async: true, ->
  title 'Creating ./deploy directory and repo'# {{{
  setGitDir DEPLOY_DIR
  chain\
  ( [ 'rm', ['-rf', './deploy']]
    [ 'mkdir', ['./deploy']
    , 'Failed to create deploy directory' ]
    [ 'git', ['init']
    , 'Failed to init git repo in ./deploy' ]
    [ 'mkdir', ['./deploy/pages', './deploy/css', './deploy/imgs', './deploy/js']
    , 'Failed to create subfolders for build' ]
    # Success output
    [ 'Successfully created deploy git' ]
  ).finally complete # }}}

desc 'Sets up choice of homepage'
file './deploy/index.html', ['compile-jade'], async: true, ->
  title 'Copying homepage to ./deploy/index.html'# {{{
  chain\
  ( [ 'cp', ['./deploy/pages/home.html', './deploy/index.html']
    , 'Failed to copy ./deploy/pages/home.html to ./deploy/index.html' ]
    # Success output
    [ 'Successfully copied ./deploy/pages/home.html to ./deploy/index.html' ]
  )# }}}

desc 'Compiles jade pages into deploy/pages'
task 'compile-jade', ['create-deploy-dir'], ->
  title 'Compiling jade files from ./jade to ./deploy/pages'# {{{
  targets = compileTools.compileMarkdown()
  for jf in jadeFiles
    htmlFile = "#{jf.match(/([^/]+)\.jade$/)[1]}.html"
    htmlPath = path.join DEPLOY_DIR, 'pages', htmlFile
    htmlContent = compileTools.compileJade jf, targets
    process.stdout.write "  Compiling #{htmlFile}... "
    try fs.writeFileSync\
    ( htmlPath
    , htmlContent
    , 'utf8' )
    catch err
      fail "\nFailed to write to #{htmlPath}"
    log "done!"
  succeed 'Successfully compiled all Jade targets'# }}}

desc 'Copies all css files into deploy/css'
task 'copy-css', ['create-deploy-dir'], ->
  title 'Copying css files from ./css to ./deploy/css'# {{{
  for cf in cssFiles
    cssFile = "#{cf.match(/([^/]+)\.css$/)[1]}.css"
    cssPath = path.join DEPLOY_DIR, 'css', cssFile
    console.log(cssPath)
    fs.createReadStream(cf).pipe(fs.createWriteStream(cssPath))
  succeed 'Successfully copied ./css to ./deploy/css' # }}}  


desc 'Copies all img files into deploy/imgs'
task 'copy-imgs', ['create-deploy-dir'], ->
  title 'Copying img files from ./imgs to ./deploy/imgs'# {{{
  for imf in imgFiles
    imgFile = "#{imf.match(/([^/]+)\.jpg$/)[1]}.jpg"
    imgPath = path.join DEPLOY_DIR, 'imgs', imgFile
    console.log(imgPath)
    fs.createReadStream(imf).pipe(fs.createWriteStream(imgPath))
  succeed 'Successfully copied ./imgs to ./deploy/imgs' # }}}  

desc 'Pushes site to production'
task 'deploy', [
  './deploy/CNAME'
  './deploy/index.html'
  'compile-jade'
  'copy-css'
  'copy-imgs'
  'create-deploy-dir'
], async: true, ->
  title 'Deploying to github'# {{{
  setGitDir DEPLOY_DIR
  chain\
  ( [ 'git', ['add', '-A', ':/']
    , 'Failed to add files to deploy repo' ]
    [ 'git', ['commit', '-am', '"Deploy commit"']
    , 'Failed to commit files into deploy history' ]
    [ 'git'
      [ '--git-dir', './deploy/.git', 'push', '--force'
      , 'https://github.com/JackThorp/dooks.co.git', 'master:gh-pages' ]
    , 'Failed to push to gh-pages branch of git repo' ]
    [ 'rm', ['-rf', DEPLOY_DIR]
    , 'Failed to remove deploy directory' ]
    # Success output
    [ 'Successfully deployed to gh-pages of git repo' ]
  ).finally complete# }}}
  

