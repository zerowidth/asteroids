class Simulation

  # Settings:
  seed: 12345

  constructor: ->
    @world = new World "display",
      scale: 50
      # paused: true

    @initializeGUI()

    @randomize()

  # Public: set a new random seed and reset the simulation
  randomize: ->
    @seed = Math.floor(Math.random() * 10000000)
    @reset()

  # Public: reset the simulation, start over
  reset: ->
    # @world.paused = true
    @world.removeAllBodies()

    Utils.srand @seed

    for controller in @gui.__controllers
      controller.updateDisplay()

    @generateAsteroids()

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
    avgDistance = 6
    deltaDistance = 2
    avgSize = 1.5
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
        position: position
        velocity: Vec.scale direction, Utils.random() * 3
        angularVelocity: (Math.PI * 2 * Utils.random() - Math.PI)
        density: 5 + 20 * density
        color: "rgba(#{color},#{color},#{color},1)"

    @world.addBody a for a in @asteroids

    window.a = @asteroids[0]
    window.b = @asteroids[1]

window.go = -> window.simulation = new Simulation
