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

    @originalColor = @color

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

  toggleColor: (color) ->
    if color is @color
      @color = @originalColor
    else
      @color = color

  # shatter this asteroid into smaller asteroids, including a given location
  shatter: (location) ->
    aabb = @aabb()
    size = Math.max(aabb[1][0] - aabb[0][0], aabb[1][1] - aabb[0][1]) / 8
    points = Utils.distributeRandomPoints aabb[0], aabb[1], size, [location]
    points = _.filter points, (point) => Geometry.pointInsidePolygon point, @vertices()

    sites = ({x: x, y: y} for [x, y] in points)
    voronoi = new Voronoi()
    bounds = {xl: aabb[0][0], xr: aabb[1][0], yt: aabb[0][1], yb: aabb[1][1]}
    result = voronoi.compute sites, bounds

    shards = []
    for cell in result.cells
      polygon = []
      for edge in cell.halfedges
        a = edge.getStartpoint()
        polygon.push [a.x, a.y]

      polygon = Geometry.normalizeWinding polygon
      polygon = Geometry.constrainPolygonToContainer polygon, @vertices()
      continue unless polygon.length > 2

      shard = new Asteroid null,
        points: polygon
        density: @density
        color: @color
      shard.velocity = Vec.add @velocity, @angularVelocityAt shard.position
      shards.push shard

    shards

window.Ship = class Ship extends PolygonalBody
  renderWith: 'custom'

  # Maneuvering capabilities as a multiplier of mass.
  # Used to calculate accelerations from keyboard input.
  thrust: 1
  turn: 1

  # How much of the flame is visible (drawing)
  flameLevel: 0

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

    super opts

    @recalculateCentroid()

  # Internal: Based on the calculated centroid, adjust the position and point
  # offsets so they match up.
  recalculateCentroid: ->

  vertices: -> @cachedVertices ?= @transform @shapeOffsets, @size
  verticesForPhysics: -> @shapeOffsets

  # the vertex at the front of the ship
  tip: -> @vertices()[1]

  integrate: (dt, keyboard) ->
    if keyboard.up
      @flameLevel = @flameLevel + (1 - @flameLevel) * 0.75
    else
      @flameLevel = @flameLevel - @flameLevel * 0.25
      @flameLevel = 0 if @flameLevel < 0.05

    if keyboard.up
      @acceleration = Vec.scale @orientation, @thrust
    else
      @acceleration = [0, 0]

    if keyboard.left
      @angularAccel = @turn
    else if keyboard.right
      @angularAccel = -@turn
    else
      @angularAccel = 0

    super dt, keyboard

  draw: (display) ->
    if @flameLevel > 0
      # tip of flame is from -1.5 to 0.25, map it onto that scale
      x = - @flameLevel * 1.75 - 0.25

      offsets = [ [-0.25, 0], [-0.375, 0.25], [x, 0], [-0.375, -0.25] ]
      flame = @transform offsets, @size

      display.drawPolygons [flame], "#FB0", 0.25 + @flameLevel * 0.5

    display.drawPolygons [@transform(@drawOffsets, @size)], @color
