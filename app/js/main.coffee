class Simulation

  # Settings:
  seed: Math.floor(Math.random() * 100000)

  constructor: ->
    @world = new World "display",
      scale: 50
      # paused: true

    @reset()

  # Public: reset the simulation, start over
  reset: ->
    # @world.paused = true
    @world.removeAllBodies()

    Utils.seed = @seed

    @generateAsteroids()

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

window.go = ->
  window.simulation = new Simulation

  window.gui = new dat.GUI()
  gui.add simulation, "seed"
  gui.add simulation, "reset"

  # gui.add(simulation.world, "paused").listen()
  gui.add simulation.world, "speedFactor", 0.1, 10

  debug = gui.addFolder "debug"
  debug.add simulation.world, "pauseEveryStep"
  debug.add simulation.world, "pauseOnContact"
  debug.add simulation.world.debugSettings, "drawMinAxis"
  debug.add simulation.world.debugSettings, "drawAABB"
  debug.add simulation.world.debugSettings, "drawSAT"
  debug.add simulation.world.debugSettings, "drawContacts"
