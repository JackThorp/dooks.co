fs = require 'fs'
path = require 'path'
markdown = (require 'markdown').markdown
jade = require 'jade'
express = require 'express'
http = require 'http'

JADE_DIR = path.join __dirname, 'jade'
MARKDOWN_DIR = path.join __dirname, 'markdown'
PUBLIC_DIR = path.join __dirname, 'public'

module.exports = tools =
  
  # readDirSync returns an array of all contents of directory. 
  # reduce is an array prototype method, takes a callback and an optional initial value.
  # The first param of the callback, here a, is the accumulator, the second is
  # the current array value. The initial value of the accumulator is either the first 
  # element or optional paramter, if given. The next accumulator value is the value 
  # returned by the callback.
  # + is the unary operator that converts its operand into an integer.
  # fs.statSync gets the stats of the file synchronously. isDirectory returns true if
  # file is directory. So files get pushed into first array, folders into second!
  getMarkdown: (cwd = MARKDOWN_DIR, targets = {} ) ->
    list = fs.readdirSync(cwd)
    [files, folders] = list.reduce\
    ( ((a,f) -> a[+fs.statSync(path.join cwd, f).isDirectory()].push f; a)
    , [[],[]])
    
    for file in files when /\.md$/.test file
      file = path.join cwd, file
      name = file.match(/([^/]+)\.[^.]+$/)[1] # [1] says select 1st captured part (in brackets) anything not a /slash followed by a . and more till file name end.
      targets[name] = fs.readFileSync file, 'utf8'
    
    for dir in folders
      targets = tools.getMarkdown path.join(cwd, dir), targets

    targets

  # own key, value avoids iterating over inherited object properties.
  # This function compiles the markdown to html.
  compileMarkdown: (targets = tools.getMarkdown()) ->
    for own target,src of targets
      targets[target] = markdown.toHTML src
    targets

  # Returns the compiled html from the Jade jfile.
  # Jade API tatkes an options onject. compile method returns a function
  # for compiling the jade file. This function is invoked with an object, here
  # targets, which contains the local variables referenced in the jade file.
  compileJade: (jfile, targets = tools.compileMarkdown()) ->
    opt = filename: jfile, pretty: true
    jCompiler = jade.compile (fs.readFileSync jfile, 'utf8'), opt
    jCompiler targets

  # Serves a jade page including all markdown. ? existential operator
  # req.params.name ?= 'home' means set params.name to 'home' if it is
  # name is an undefined or null property.
  servePage: (req, res) ->
    req.params.name ?= 'home'
    jf = path.join JADE_DIR, "#{req.params.name}.jade"
    res.send tools.compileJade jf

# If the module has no parent - this module is not being required
# then start the server
if !module.parent?
  app = express()
  app.get '/', (req, res) ->
    res.redirect '/page/home'
  app.get '/page/:name', tools.servePage
  app.use express.static PUBLIC_DIR
  app.listen (PORT = 3000), (err) ->
    if err? then console.error err
    else
     console.log "Server listening on http://localhost:#{PORT}"

