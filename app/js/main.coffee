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
      update: =>
        @world.update @ctx.dt
      draw: =>
        @world.draw()
      keydown: (e) =>
        @world.keydown e

      keyup: (e) =>
        @world.keyup e
      mousedown: (e) =>
        @world.mousedown e
      click: (e) =>
        @world.click e

    @setNewSeed() unless @seed

    @reset()

  # Public: set a new random seed and reset the simulation
  randomize: ->
    @setNewSeed()
    @reset()

  # Public: reset the simulation, start over
  reset: ->
    # @world.paused = true
    @world.removeAllBodies()

    Utils.srand @seed

    @generateBodies()

  setNewSeed: ->
    @seed = Math.floor(Math.random() * 10000000)

  generateBodies: ->
    @asteroids = []

    avgSize = sizeDelta = 3
    deltaVelocity = 3
    deltaTheta = Math.PI

    searchRadius = avgSize - sizeDelta / 2.5
    for pos, i in Utils.distributeRandomPoints [0, 0], [@width, @height], searchRadius, [@world.center()]
      continue if i is 0
      size = avgSize + Utils.random(sizeDelta) - sizeDelta/2

      density = Utils.randomInt(0,4)
      lineColor = Math.floor(192 - density * 32)
      color = Math.floor(96 - density * 16)

      @asteroids.push new Asteroid size,
        position: pos
        velocity: [
          Utils.random(deltaVelocity) - deltaVelocity / 2,
          Utils.random(deltaVelocity) - deltaVelocity / 2
        ]
        angularVelocity: Utils.random(deltaTheta) - deltaTheta / 2
        density: 10 + 5 * density
        color: "rgba(#{color},#{color},#{color},1)"
        lineColor: "rgba(#{lineColor},#{lineColor},#{lineColor},1)"

    @world.addBody a for a in @asteroids
    @ship = new Ship 0.3,
      position: @world.center()
      angle: Math.PI/2
      density: 5
      thrust: 6
      turn: 5

    # make the ship more resistant to spinning (helps with bounces)
    @ship.inverseMoment = @ship.inverseMoment / 4

    @world.addBody @ship
    @world.ship = @ship
    @world.track @ship

window.go = -> window.simulation = new Simulation
