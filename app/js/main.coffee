class Simulation

  # Settings:
  seed: null

  constructor: ->
    # @world = new WrappedWorld "display", 24, 15,
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

    @generateAsteroids()
    @createShip()

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

  generateAsteroids: ->
    @asteroids = []

    numAsteroids = 20
    avgDistance = 3
    deltaDistance = 3
    avgSize = 1.2
    sizeDelta = 1
    deltaVelocity = 5
    deltaTheta = Math.PI

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
        velocity: [
          Utils.random() * deltaVelocity - deltaVelocity / 2,
          Utils.random() * deltaVelocity - deltaVelocity / 2
        ]
        angularVelocity: deltaTheta * Utils.random() - deltaTheta / 2
        density: 5 + 20 * density
        color: "rgba(#{color},#{color},#{color},1)"

    @world.addBody a for a in @asteroids

  createShip: ->
    @ship = new Ship 0.3,
      color: "#8CF"
      position: @world.center()
      angle: Math.PI/2
      density: 5

    @world.addBody @ship
    @world.track @ship

window.go = -> window.simulation = new Simulation

  # window.rect = new Rectangle 5, 0.5,
  #   position: [0, 0]
  #   density: 4
  #   color: "#F00"

  # window.rect2 = new Rectangle 1, 1,
  #   position: [0, 1]
  #   velocity: [1, -2]
  #   density: 1
  #   color: "#08F"

  # window.rect3 = new Rectangle 1, 1,
  #   position: [0,-1]
  #   velocity: [-1, 2]
  #   density: 1
  #   color: "#0AF"

  # window.rect4 = new Rectangle 1, 1,
  #   position: [2.5,-5]
  #   velocity: [0, 3.5]
  #   density: 5
  #   color: "#0CF"
  # world.addBody rect
  # world.addBody rect2
  # world.addBody rect3
  # world.addBody rect4
