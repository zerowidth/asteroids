class Simulation

  # Settings:
  seed: null

  constructor: ->
    windowWidth  = window.innerWidth
    windowHeight = window.innerHeight

    # header is 31 high, plus 10 padding on sides
    @width  = windowWidth - 20
    @height = windowHeight - 41
    # @width = Math.min(@width, @height)
    # @height = Math.min(@width, @height)

    $("#container").width(@width).height(@height)
    $("#header").width(@width)

    @ctx = Sketch.create
      element: document.getElementById "display"
      container: document.getElementById "container"
      fullscreen: false
      width: @width
      height: @height
      # retina: true

    @display = new WrappedDisplay @ctx, [@width/2, @height/2], @width, @height
    @world = new AsteroidWorld @display, @width, @height, 1

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
