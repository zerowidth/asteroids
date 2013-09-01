
Vec =
  HALF_PI: Math.PI / 2
  TWO_PI: Math.PI * 2

  add: ([x1, y1], [x2, y2]) ->
    [x1 + x2, y1 + y2]
  sub: ([x1, y1], [x2, y2]) ->
    [x1 - x2, y1 - y2]
  mul: ([x, y], c) ->
    [x * c, y * c]
  invert: (vec) ->
    @mul vec, -1
  polarToVector: (theta, length) ->
    [ cos(theta) * length, sin(theta) * length ]
  normalizeAngle: (theta) ->
    while theta > @TWO_PI
      theta -= @TWO_PI
    while theta < -@TWO_PI
      theta += @TWO_PI
    theta

  vectorNormal: ([x,y]) ->
    @normalize [-y, x]

  normalize: ([x,y]) ->
    scale = Math.sqrt(x*x + y*y)
    if scale is 0
      [0, 0]
    else
      [x/scale, y/scale]

  dotProduct: ([x1, y1], [x2, y2]) ->
    x1*x2 + y1*y2

window.Vec = Vec
