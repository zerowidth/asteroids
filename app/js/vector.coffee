Vec =
  HALF_PI: Math.PI / 2
  TWO_PI: Math.PI * 2

  add: ([x1, y1], [x2, y2]) ->
    [x1 + x2, y1 + y2]
  sub: ([x1, y1], [x2, y2]) ->
    [x1 - x2, y1 - y2]
  scale: ([x, y], c) ->
    [x * c, y * c]
  invert: (vec) ->
    @scale vec, -1
  polarToVector: (theta, length) ->
    [ cos(theta) * length, sin(theta) * length ]
  normalizeAngle: (theta) ->
    while theta > @TWO_PI
      theta -= @TWO_PI
    while theta < -@TWO_PI
      theta += @TWO_PI
    theta

  # cross product in 2d is a scalar:
  crossProduct: ([x0, y0], [x1, y1]) ->
    x0*y1 - y0*x1

  # "cross product" yields a non-normalized perpendicular vector
  perpendicular: ([x, y]) ->
    [-y, x]
  perpendicularNormal: ([x,y]) ->
    @normalize [-y, x]

  normalize: ([x,y]) ->
    scale = @magnitude [x,y]
    if scale is 0
      [0, 0]
    else
      [x/scale, y/scale]

  dotProduct: ([x1, y1], [x2, y2]) ->
    x1*x2 + y1*y2

  magnitude: ([x,y]) ->
    Math.sqrt(x*x + y*y)

  # | a b c |   | x |   | ax + by + c |
  # | e f g | * | y | = | ex + fy + g |
  #             | 1 |
  #
  # translation is [dx, dy]
  # orientation is [cos(theta), sin(theta)]
  #
  # using this rotation / translation matrix:
  # | cos(theta) -sin(theta) dx |
  # | sin(theta)  cos(theta) dy |
  transform: (vec, translation, orientation, scale=1) ->
    [x, y]   = vec
    x = x * scale
    y = y * scale
    [dx, dy] = translation
    [r, i]   = orientation
    [r*x - i*y + dx, i*x + r*y + dy]

window.Vec = Vec
