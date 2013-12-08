class Simulation

  # Settings:
  seed: null

  constructor: ->
    scale  = 50
    @width  = Math.floor(window.innerWidth / scale) - 1
    @height = Math.floor(window.innerHeight / scale) - 1

    @ctx = Sketch.create
      element: document.getElementById "display"
      retina: true

    @display = new WrappedDisplay @ctx, [@width/2, @height/2], @width, @height, scale

    @world = new WrappedWorld @display, @width, @height,
      # paused: true

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
        @generateRandomPoints()

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

    @generateBodies()

  generateRandomPoints: ->
    for n in [0...100]
      x = Utils.random @width
      y = Utils.random @height
      direction = Rotation.fromAngle Utils.random Math.PI * 2
      v = Vec.scale direction, Utils.random 5
      p = new Particle 1,
        position: [x,y]
        velocity: v
        size: 2
        color: "#F00"
        fade: true
        damping: 0.05
      @world.addParticle p

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

    dat.GUI.toggleHide()

  generateBodies: ->
    @asteroids = []

    numAsteroids = 20
    avgDistance = 3
    deltaDistance = 3
    avgSize = 1.2
    sizeDelta = 1
    deltaVelocity = 2
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

    @ship = new Ship 0.3,
      color: "#8CF"
      position: @world.center()
      angle: Math.PI/2
      density: 5
      thrust: 6
      turn: 5

    @world.addBody @ship
    @world.track @ship

window.go = -> window.simulation = new Simulation
