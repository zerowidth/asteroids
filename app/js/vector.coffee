
Vec =
  HALF_PI: Math.PI / 2
  TWO_PI: Math.PI * 2

  add: ([x1, y1], [x2, y2]) ->
    [x1 + x2, y1 + y2]
  sub: ([x1, y1], [x2, y2]) ->
    [x1 - x2, y1 - y2]
  mul: ([x, y], c) ->
    [x * c, y * c]
  polarToVector: (theta, length) ->
    [ cos(theta) * length, sin(theta) * length ]
  normalizeAngle: (theta) ->
    while theta > @TWO_PI
      theta -= @TWO_PI
    while theta < -@TWO_PI
      theta += @TWO_PI
    theta

window.Vec = Vec
