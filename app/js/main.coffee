class Simulation

  # Settings:
  seed: null

  constructor: ->
    scale  = 50
    @width  = Math.floor(window.innerWidth / scale) - 1
    @height = Math.floor(window.innerHeight / scale) - 1
    @width = Math.min(@width, @height)
    @height = Math.min(@width, @height)

    @ctx = Sketch.create
      element: document.getElementById "display"
      # retina: true

    @display = new WrappedDisplay @ctx, [@width/2, @height/2], @width, @height, scale

    @world = new AsteroidWorld @display, @width, @height


    _.extend @ctx,
      update: =>
        @world.update @ctx.dt
      draw: =>
        @world.draw()
      keydown: (e) =>
        @world.keydown e

      keyup: (e) =>
        @world.keyup e
      click: (e) =>
        offsetX = (window.innerWidth / scale) - @width
        offsetY = (window.innerHeight / scale) - @height
        x = e.x / scale - offsetX/2
        y = @height - (e.y / scale - offsetY/2)

        console.log "click", [x, y]
        for body in @world.quadtree.atPoint [x, y]
          if Geometry.pointInsidePolygon [x, y], body.vertices()
            console.log "got body", body

    @setNewSeed() unless @seed
    # @initializeGUI()

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

    # for controller in @gui.__controllers
    #   controller.updateDisplay()

    @generateBodies()
    # @generateDebug()

  setNewSeed: ->
    @seed = Math.floor(Math.random() * 10000000)

  # Internal: set up a GUI controller for the simulation
  initializeGUI: ->
    @gui = new dat.GUI()
    seed = @gui.add(this, "seed")
    @gui.add this, "randomize"
    @gui.add this, "reset"

    # @gui.add(@world, "paused").listen()
    @gui.add @world, "speedFactor", 0.1, 10

    debug = @gui.addFolder "debug"
    debug.add @world, "pauseEveryStep"
    debug.add @world, "pauseOnContact"
    debug.add @world.debugSettings, "drawMinAxis"
    debug.add @world.debugSettings, "drawAABB"
    debug.add @world.debugSettings, "drawSAT"
    debug.add @world.debugSettings, "drawContacts"
    debug.add @world.debugSettings, "drawCamera"
    debug.add @world.debugSettings, "drawQuadtree"

  generateBodies: ->
    @asteroids = []

    avgSize = sizeDelta = 1.5
    deltaVelocity = 2
    deltaTheta = Math.PI

    searchRadius = avgSize - sizeDelta / 4
    for pos in Utils.distributeRandomPoints [0, 0], [@width, @height], searchRadius
      size = avgSize + Utils.random(sizeDelta) - sizeDelta/2

      density = Utils.randomInt(0,4)
      color = Math.floor(192 - density * 32)

      @asteroids.push new Asteroid size,
        position: pos
        velocity: [
          Utils.random(deltaVelocity) - deltaVelocity / 2,
          Utils.random(deltaVelocity) - deltaVelocity / 2
        ]
        angularVelocity: Utils.random(deltaTheta) - deltaTheta / 2
        density: 10 + 5 * density
        color: "rgba(#{color},#{color},#{color},1)"

    for a, i in @asteroids
      a.index = i
      @world.addBody a

    @ship = new Ship 0.3,
      color: "#8CF"
      position: @world.center()
      angle: Math.PI/2
      density: 5
      thrust: 6
      turn: 5

    @ship.ship = true

    # make the ship more resistant to spinning (helps with bounces)
    @ship.inverseMoment = @ship.inverseMoment / 4

    @world.addBody @ship
    @world.ship = @ship
    @world.track @ship

  generateDebug: ->
    @asteroids = []
    @asteroids.push new Asteroid @width/2,
      position: [@width / 2, @height / 2]
      # velocity: [0, 1]
      angularVelocity: Math.PI
      density: 10
      color: "#CCC"
    @world.addBody a for a in @asteroids

window.go = -> window.simulation = new Simulation

window.body = (i) -> simulation.world.bodies[i] # for debugging
