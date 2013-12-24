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
        if e.keyCode is 32 # space
          v = Vec.scale @ship.orientation, 5
          p = new Particle 1,
            position: @ship.position
            velocity: Vec.add @ship.velocity, v
            size: 2
            color: "#F4A"
            fade: true
          @world.addParticle p
        @world.keydown e

      keyup: (e) =>
        @world.keyup e
      click: (e) =>
        offsetX = (window.innerWidth / scale) - @width
        offsetY = (window.innerHeight / scale) - @height
        x = e.x / scale - offsetX/2
        y = @height - (e.y / scale - offsetY/2)

        if @world.keyboard.shift
          console.log "click", [x, y]
          for body in @world.quadtree.atPoint [x, y]
            if Geometry.pointInsidePolygon [x, y], body.vertices()
              console.log "got body", body
          return

        @world.removeAllParticles()
        for body in @world.quadtree.atPoint [x, y]
          if Geometry.pointInsidePolygon [x, y], body.vertices()
            # body.toggleColor "4F4"

            aabb = body.aabb()
            size = Math.max(aabb[1][0] - aabb[0][0], aabb[1][1] - aabb[0][1]) / 8
            points = Utils.distributeRandomPoints aabb[0], aabb[1], size, [[x, y]]
            points = _.filter points, (point) => Geometry.pointInsidePolygon point, body.vertices()
            for pos in points
              p = new Particle 10,
                position: pos
                size: 2
                color: "#F00"
                fade: true
              @world.addParticle p

            sites = ({x: x, y: y} for [x, y] in points)
            voronoi = new Voronoi()
            bounds = {xl: aabb[0][0], xr: aabb[1][0], yt: aabb[0][1], yb: aabb[1][1]}
            result = voronoi.compute sites, bounds
            @world.removeBody body

            for cell in result.cells
              polygon = []
              for edge in cell.halfedges
                a = edge.getStartpoint()
                polygon.push [a.x, a.y]

              polygon = Geometry.normalizeWinding polygon
              polygon = Geometry.constrainPolygonToContainer polygon, body.vertices()
              continue unless polygon.length > 2

              shard = new Asteroid 1,
                points: polygon
                density: body.density
                color: body.color
              shard.velocity = Vec.add body.velocity, body.angularVelocityAt shard.position
              @world.addBody shard

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

    # @generateBodies()
    @generateDebug()

  generateRandomPoints: ->
    for pos in Utils.distributeRandomPoints [0, 0], [@width, @height], 1
      p = new Particle 2,
        position: pos
        size: 2
        color: "#F00"
        fade: true
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
