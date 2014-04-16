window.Rectangle = class Rectangle extends PolygonalBody
  constructor: (sizeX, sizeY, opts = {}) ->
    @offsets = [[ sizeX/2,  sizeY/2],
               [-sizeX/2,  sizeY/2],
               [-sizeX/2, -sizeY/2],
               [ sizeX/2, -sizeY/2]]

    super opts

  vertices: -> @cachedVertices ?= @transform @offsets

  # the regular polygonal version works, but this is easier:
  calculateInverseMoment: (b, h) ->
    if @inverseMass is 0
      0
    else
      (1/@inverseMass)*(b*b + h*h)/12

window.Asteroid = class Asteroid extends PolygonalBody
  # Public: Create a new Asteroid.
  #
  # size - how big the asteroid is (give or take)
  # opts - a dictionary containing, the standard PolygonalBody options and:
  #        position - [x,y] position of the centroid. Updated to match the
  #                   calculated centroid if points are not also specified.
  #        points   - [ [x,y] ...] vertices, relative to specified position.
  #
  constructor: (size, opts = {}) ->
    if opts.points
      opts.orientation = [1, 0]
      opts.position = [0,0]
      @points = opts.points
    else
      center = opts.position or [0, 0]
      opts.position = [0, 0]
      @points = @generatePoints center, size/2

    super opts

    # Update position and offsets to match the calculated centroid, unless both
    # the position and vertices have been explicitly set.
    @recalculateCentroid()

  # Internal: Based on the calculated centroid, adjust the position and point
  # offsets so they match up.
  # The centroid offset assumes vertices with only translation (the position)
  # involved, not orientation.
  recalculateCentroid: ->
    offset = Vec.sub @centroid, @position
    @points = (Vec.sub point, offset for point in @points)
    @position = @centroid

  vertices: -> @cachedVertices ?= @transform @points
  verticesForPhysics: -> @points

  # Internal: generate a somewhat randomized asteroid shape around a specific
  # point in world coordinates
  generatePoints: (center, radius) ->
    n = Utils.randomInt 7, 13
    wedgeSize = 2 * Math.PI / n

    points = for i in [0...n]
      r = radius - (Utils.random() * radius/2)
      theta = i * wedgeSize + (Utils.random() * wedgeSize/1.5 - wedgeSize/3)
      [ center[0] + r * Math.cos(theta), center[1] + r * Math.sin(theta) ]

    @convexify points

  # Internal: remove concave points until the polygon is convex.
  convexify: (points) ->
    n = points.length

    loop
      points = _.filter points, (point, i) ->
        a = points[(n + i - 1) % n]
        b = points[(n + i + 1) % n]

        normal = Vec.perpendicular Vec.sub(b, a)
        test   = Vec.sub a, point
        dot    = Vec.dotProduct test, normal
        dot >= 0

      break if points.length == n
      n = points.length

    points

  # shatter this asteroid into smaller asteroids, including a given location
  shatter: (location, reference = null) ->
    reference = reference or this
    shards = []
    for polygon in @shards location
      shard = new Asteroid null,
        points: polygon
        density: @density
        color: @color
        lineColor: @lineColor
      shard.velocity = Vec.add @velocity, reference.angularVelocityAt shard.position
      shards.push shard
    shards

window.Ship = class Ship extends PolygonalBody
  renderWith: 'custom'

  # Maneuvering capabilities as a multiplier of mass.
  # Used to calculate accelerations from control input.
  thrust: 1
  turn: 1

  # How much of the flame is visible (drawing)
  flameLevel: 0
  flameOffsets: ->
    # tip of flame is from -1.5 to 0.25, map it onto that scale
    x = - @flameLevel * 1.75 - 0.25
    [ [-0.25, 0], [-0.375, 0.25], [x, 0], [-0.375, -0.25] ]

  # How much of the thruster is visible
  thrusterLevel: 0
  thrusterOffsets: ->
    # tip of thrust is from +/-0.8 to +/- 0.2, give or take
    side = if @thrusterLevel > 0 then 1 else -1
    # y coords come from line equation of side of ship, y = -0.2857x + 0.357
    y = 0.185 * side + 0.8 * @thrusterLevel
    [ [0.8, 0.128 * side], [0.6, y], [0.4, 0.242 * side] ]

  # Draw targeting line?
  targeting: false

  # Is this a ship?
  ship: true

  # Is the ship invincible?
  invincible: false

  # Colors:
  colors:     [ "#246", "#468" ] # normal, invincible
  lineColors: [ "#8CF", "#AEF" ]
  color: "#246"
  lineColor: "#8CF"

  # Public: Create a new Ship.
  #
  # size - how big the ship is (give or take)
  # opts - a dictionary containing, the standard PolygonalBody options and:
  #        thrust: how much force the engine has as multiplier of mass
  #        turn: how much torque the thrusters have as a multiplier of moment
  constructor: (@size, opts = {}) ->
    @thrust = opts.thrust if opts.thrust
    @turn = opts.turn if opts.turn

    # drawn shape is convex, so handle the physics shape separately
    @drawOffsets = [ [0.9, -0.1], [1, 0], [0.9, 0.1], [-0.5, 0.5], [-0.25, 0], [-0.5, -0.5] ]
    @shapeOffsets = [ [0.9, -0.1], [1, 0], [0.9, 0.1], [-0.5, 0.5], [-0.5, -0.5] ]
    @drawOffsets = (Vec.scale offset, @size for offset in @drawOffsets)
    @shapeOffsets = (Vec.scale offset, @size for offset in @shapeOffsets)

    @controls = new ShipControls

    super opts

    @recalculateCentroid()

  # Internal: Based on the calculated centroid, adjust the position and point
  # offsets so they match up.
  recalculateCentroid: ->

  vertices: -> @cachedVertices ?= @transform @shapeOffsets
  verticesForPhysics: -> @shapeOffsets

  # the vertex at the front of the ship
  tip: -> @vertices()[1]

  update: (dt) ->
    if @controls.thrust
      @flameLevel = @flameLevel + (1 - @flameLevel) * 0.75
      @acceleration = Vec.scale @orientation, @thrust
    else
      @flameLevel = @flameLevel - @flameLevel * 0.25
      @flameLevel = 0 if @flameLevel < 0.05
      @acceleration = [0, 0]

    if @controls.left
      @angularAccel = @turn
      @thrusterLevel = -1
    else if @controls.right
      @angularAccel = -@turn
      @thrusterLevel = 1
    else
      @angularAccel = 0
      @thrusterLevel = @thrusterLevel - @thrusterLevel * 0.25
      @thrusterLevel = 0 if Math.abs(@thrusterLevel) < 0.05

    @targeting = @controls.targeting

  draw: (display) ->
    if @flameLevel > 0
      flame = @transform @flameOffsets(), @size
      display.drawPolygons [flame], "#FB0", "#FB0", 0.25 + @flameLevel * 0.5

    if @thrusterLevel isnt 0
      thruster = @transform @thrusterOffsets(), @size
      alpha = 0.25 + Math.abs(@thrusterLevel) * 0.5
      alpha = 1
      display.drawPolygons [thruster], "#CCF", "#CCF", alpha

    if @targeting
      to = Vec.add @position, Vec.scale @orientation, 125
      display.drawLine @position, to, 1, "#F33", 1
      for segment in [0..9]
        from = Vec.add @position, Vec.scale @orientation, 125 + (segment / 10) * 125
        to   = Vec.add @position, Vec.scale @orientation, 125 + ((segment + 1) / 10) * 125
        alpha = 1 - segment / 10
        display.drawLine from, to, 1, "#F33", alpha

    display.drawPolygons [@transform(@drawOffsets)], @color, @lineColor

  toggleInvincibility: ->
    @invincible = not @invincible
    index = if @invincible then 1 else 0
    @color = @colors[index]
    @lineColor = @lineColors[index]
