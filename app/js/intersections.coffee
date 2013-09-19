window.intersections = ->

  window.stats = Utils.drawStats()
  window.ctx = Sketch.create
    element: document.getElementById('intersections')
    retina: true

  window.polys = [
    new Square([290, 190], 50, "#800"),
    new Square([500, 200], 100, "#008"),
    new Triangle([200, 200], [0,0], [0,200], [100,0], "#080")
  ]

  window.grid = new Grid 100, "#056"

  window.dragTarget = {
    target: null
    offset: [0,0]
  }

  _.extend ctx,
    draw: ->
      grid.draw ctx
      for poly in polys
        poly.draw ctx
      stats.update()
    mousedown: (e) ->
      where = [@mouse.x, @mouse.y]
      hit = _.find polys, (poly) -> poly.hitTest where
      if hit
        dragTarget.target = hit
        dragTarget.offset = Vec.sub hit.pos, where
      else
        dragTarget.target = null
    mousemove: (e) ->
      if @dragging and dragTarget.target
        where = [@mouse.x, @mouse.y]
        dragTarget.target.pos = Vec.add where, dragTarget.offset

        (poly.hit = false for poly in polys)
        for i in [0..(polys.length-1)]
          poly = polys[i]
          for other in polys.slice(i+1)
            translate = poly.intersects other
            if translate
              who = poly
              if poly is dragTarget.target
                who = other
                translate = Vec.invert translate
              who.pos = Vec.add who.pos, translate
              poly.hit = true
              other.hit = true

class Polygon
  hit: false
  axisAlignedBoundingBox: =>

  draw: (ctx) =>
    points = @points()
    ctx.save()
    ctx.beginPath()

    ctx.moveTo points[points.length - 1]...

    for point in points
      ctx.lineTo point...

    ctx.globalAlpha = 0.3 unless @hit
    ctx.fillStyle = @color
    ctx.fill()
    ctx.globalAlpha = 1

    ctx.strokeStyle = @color
    ctx.stroke()
    ctx.restore()

  hitTest: ( [mouseX,mouseY] ) ->
    points = @points()
    [minX, maxX, minY, maxY] = Utils.axisAlignedBoundingBox points

    # check axis-aligned bounding box first:
    if mouseX < minX or mouseY < minY or mouseX > maxX or mouseY > maxY
      return false

    # then do ray cast (poly/line intersection)
    testLine = [[mouseX, mouseY], [maxX + 1, mouseY]]
    count = 0
    for segment in Utils.pairs points
      count += 1 if Utils.linesIntersect testLine, segment

    count % 2 is 1 # odd number of line crossings is inside the polygon

  # Separating Axis Theorem, from http://www.codezealot.org/archives/55
  intersects: (other) ->
    minAxis = null
    minOverlap = 1000000 # big enough, right?

    for axis in @normalAxes().concat other.normalAxes()
      us = @projectionInterval axis
      them = other.projectionInterval axis
      overlap = Utils.intervalOverlap us, them
      return false unless overlap > 0
      if overlap < minOverlap
        minUs = us
        minThem = them
        minOverlap = overlap
        minAxis = axis

    # overlap is always positive. if we're to the left of the other polygon on
    # the axis of overlap, then invert the direction.
    multiplier = if minUs[0] < minThem[0] then -1 else 1

    # minimum translation vector
    return Vec.mul minAxis, minOverlap * multiplier

  projectionInterval: (axis) ->
    Utils.projectionInterval @points(), axis

  normalAxes: ->
    for pair in Utils.pairs @points()
      Vec.vectorNormal Vec.sub pair[1], pair[0]

class Square extends Polygon
  constructor: (@pos, @size, @color) ->
  points: =>
    for offset in [ [0, 0], [0, 1], [1, 1], [1, 0] ]
      Vec.add @pos, Vec.mul(offset, @size)

class Triangle extends Polygon
  constructor: (@pos, @p1, @p2, @p3, @color) ->
  points: =>
    ( Vec.add(@pos, p) for p in [@p1, @p2, @p3] )
