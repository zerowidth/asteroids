class Simulation

  # Settings:
  seed: null

  constructor: ->
    scale  = 50

    windowWidth  = window.innerWidth
    windowHeight = window.innerHeight

    @width  = Math.floor(windowWidth  / scale) - 1
    @height = Math.floor(windowHeight / scale) - 1
    $("#container").width(@width * scale).height(@height * scale)
    $("#header").width(@width * scale)

    @ctx = Sketch.create
      element: document.getElementById "display"
      container: document.getElementById "container"
      fullscreen: false
      width: @width * scale
      height: @height * scale
      # retina: true

    @display = new WrappedDisplay @ctx, [@width/2, @height/2], @width, @height, scale
    @world = new AsteroidWorld @display, @width, @height, scale

    _.extend @ctx,
      update:        => @world.update @ctx.dt
      draw:          => @world.draw()
      keydown: (e)   => @world.keydown e
      keyup: (e)     => @world.keyup e
      mousedown: (e) => @world.mousedown @ctx.mouse
      mouseup:   (e) => @world.mouseup @ctx.mouse
      click: (e)     => @world.click @ctx.mouse

    @setNewSeed() unless @seed
    @reset()

  # Public: set a new random seed and reset the simulation
  randomize: ->
    @setNewSeed()
    @reset()

  # Public: reset the simulation, start over
  reset: ->
    Utils.srand @seed
    # @world.paused = true
    @world.reset()

  setNewSeed: ->
    @seed = Math.floor(Math.random() * 10000000)

window.go = -> window.simulation = new Simulation
