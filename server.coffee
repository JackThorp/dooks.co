fs = require 'fs'
markdown = (require 'markdown').markdown
path = require 'path'
jade = require 'jade'
express = require 'express'

HTML_FILE = path.join __dirname, 'index.html'
LAYOUT_FILE = path.join __dirname, 'layout.jade'
JADE_DIR = path.join __dirname, 'jade'
MARKDOWN_DIR = path.join __dirname, 'markdown'

module.exports = tools =

  # When called with no arguments, will load markdown file source
  # against the name of the file. Ie, ./markdown/about.md will load
  # their contents into target.about = <SRC>.
  getMarkdown: (cwd = MARKDOWN_DIR, targets = {}) ->
    [files, folders] = fs.readdirSync(cwd)
      .reduce\
      ( ((a,f) -> a[+fs.statSync(path.join cwd, f).isDirectory()].push f; a)
      , [[],[]] )
    for file in files when /\.md$/.test file
      file = path.join cwd, file
      name = file.match(/([^/]+)\.[^.]+$/)[1]
      targets[name] = fs.readFileSync file, 'utf8'
    getMarkdown path.join(cwd, dir) for dir in folders
    targets

  # Given targets of target[name] = <SRC>, where <SRC> is markdown
  # source, will compile the markdown and save into targets.
  compileMarkdown: (targets = tools.getMarkdown()) ->
    for own target,src of targets
      targets[target] = markdown.toHTML src
    targets

  # Returns the compiled Jade from jfile path.
  compileJade: (jfile, targets = tools.compileMarkdown()) ->
    opt = filename: jfile
    comp = jade.compile (fs.readFileSync jfile, 'utf8'), opt
    comp targets

  # Loads and compiles the markdown pages, then writes the output to
  # the HTML_OUT file.
  compileToFile: (jfile, out) ->
    html = tools.compileJade jfile
    process.stdout.write "Writing html to #{out}...  "
    fs.writeFile out, html, 'utf8', (err) ->
      if not err? then console.log 'DONE!'
      else throw err

  # Serves a jade page, including all markdown
  servePage: (req, res) ->
    req.params.name ?= 'home'
    jf = path.join JADE_DIR, "#{req.params.name}.jade"
    res.send tools.compileJade jf

# If being required, then don't start server
if !module.parent?
  app = express()
  app.get '/', (req, res) ->
    res.redirect '/page/home'
  app.get '/page/:name', tools.servePage
  app.listen (PORT = 3000), (err) ->
    if err? then console.error err
    else
      console.log "Server listening on http://localhost:#{PORT}"



