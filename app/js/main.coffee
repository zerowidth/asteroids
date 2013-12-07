class Simulation

  # Settings:
  seed: null

  constructor: ->
    @world = new WrappedWorld "display", 16, 10,
      scale: 50
      # paused: true

    @setNewSeed() unless @seed
    @initializeGUI()

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

    for controller in @gui.__controllers
      controller.updateDisplay()

    # @generateBodies()
    @generateAsteroids()

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

  generateAsteroids: ->
    @asteroids = []

    numAsteroids = 20
    avgDistance = 4
    deltaDistance = 3
    avgSize = 1.2
    sizeDelta = 1

    for theta in [0...numAsteroids]
      angle = theta * Math.PI * 2 / numAsteroids
      radius = avgDistance + Utils.random() * deltaDistance - deltaDistance / 2

      position = Vec.polarToVector angle, radius
      direction = Vec.normalize Vec.sub([0,0], position)

      s = avgSize + Utils.random() * sizeDelta - sizeDelta/2

      density = Utils.random()
      color = Math.floor(192 - density * 128)

      @asteroids.push new Asteroid s,
        position: Vec.add @world.center(), position
        # velocity: Vec.scale direction, Utils.random() * 3
        velocity: [Utils.random() * 0.5 - 0.25, Utils.random() * 0.5 - 0.25]
        angularVelocity: (Math.PI * 2 * Utils.random() - Math.PI) * 0.5
        density: 5 + 20 * density
        color: "rgba(#{color},#{color},#{color},1)"

    @world.addBody a for a in @asteroids

  generateBodies: ->
    @asteroids = []

    @asteroids.push new Asteroid 1,
      position: [1, 9.6]
      velocity: [0, 0]
      density: 5

    @asteroids.push new Asteroid 1,
      position: [1, 1]
      velocity: [0, -1]
      density: 5

    @asteroids.push new Asteroid 1,
      position: [4.5, 0.1]
      velocity: [1, 0]
      density: 5

    @asteroids.push new Asteroid 1,
      position: [5.4, 9.9]
      velocity: [-1, 0]
      density: 5

    [window.a, window.b, window.c, window.d] = @asteroids

    # @world.addBody a for a in @asteroids
    @world.addBody a
    @world.addBody b


window.go = -> window.simulation = new Simulation
