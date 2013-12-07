window.Rectangle = class Rectangle extends PolygonalBody
  constructor: (sizeX, sizeY, opts = {}) ->
    @offsets = [[ sizeX/2,  sizeY/2],
               [-sizeX/2,  sizeY/2],
               [-sizeX/2, -sizeY/2],
               [ sizeX/2, -sizeY/2]]

    super opts

  vertices: ->
    (Vec.transform offset, @position, @orientation for offset in @offsets)

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

    # Update position and offsets to match the calculated centroid, unless both
    # the position and vertices have been explicitly set.
    @recalculateCentroid() unless opts.position and opts.vertices

  vertices: ->
    (Vec.transform point, @position, @orientation for point in @points)

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

window.Ship = class Ship extends PolygonalBody

  # Maneuvering capabilities as a multiplier of mass.
  # Used to calculate accelerations from keyboard input.
  thrust: 3
  turn: 6

  # Public: Create a new Ship.
  #
  # size - how big the ship is (give or take)
  # opts - a dictionary containing, the standard PolygonalBody options and:
  #        thrust: how much force the engine has as multiplier of mass
  #        turn: how much torque the thrusters have as a multiplier of moment
  constructor: (size, opts = {}) ->
    @thrust = opts.thrust if opts.thrust
    @turn = opts.turn if opts.turn

    offsets = [ [1, 0], [-0.5, 0.5], [-0.25, 0], [-0.5, -0.5] ]
    @points = (Vec.scale offset, size for offset in offsets)

    super opts

    @recalculateCentroid()

  vertices: ->
    (Vec.transform point, @position, @orientation for point in @points)

  integrate: (dt, keyboard) ->

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
