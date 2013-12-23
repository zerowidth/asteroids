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
    @points = opts.points or @generatePoints(size/2)
    super opts
    @originalColor = @color

    # Update position and offsets to match the calculated centroid, unless both
    # the position and vertices have been explicitly set.
    @recalculateCentroid() unless opts.position and opts.vertices

  # Internal: Based on the calculated centroid, adjust the position and point
  # offsets so they match up.
  recalculateCentroid: ->
    offset = Vec.transform @centroidOffset, [0, 0], @orientation
    @points = (Vec.sub point, offset for point in @points)
    @centroidOffset = [0, 0]

  vertices: -> @cachedVertices ?= @transform @points

  # Internal: generate a somewhat randomized asteroid shape.
  generatePoints: (radius) ->
    n = Utils.randomInt 7, 13
    wedgeSize = 2 * Math.PI / n

    points = for i in [0...n]
      r = radius - (Utils.random() * radius/2)
      theta = i * wedgeSize + (Utils.random() * wedgeSize/1.5 - wedgeSize/3)
      [ r * Math.cos(theta), r * Math.sin(theta) ]

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

  drawDebug: (display) ->
    super
    display.drawCircle @position, 2, "#444"

  toggleColor: (color) ->
    if color is @color
      @color = @originalColor
    else
      @color = color

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
    offset = Vec.transform @centroidOffset, [0, 0], @orientation
    @drawOffsets = (Vec.sub point, offset for point in @drawOffsets)
    @shapeOffsets = (Vec.sub point, offset for point in @shapeOffsets)
    @centroidOffset = [0, 0]

  vertices: -> @cachedVertices ?= @transform @shapeOffsets, @size

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
