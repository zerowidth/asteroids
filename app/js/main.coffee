window.asteroids = ->
  window.stats = Utils.drawStats()
  window.ctx = Sketch.create
    element: document.getElementById('asteroids')
    retina: true
  window.ship = new Ship(ctx.width/2, ctx.height/2)
  controls = new KeyboardControls

  _.extend ctx,
    update: ->
      ship.update ctx.dt / 1000, controls
    draw: ->
      Utils.drawWrapped ctx, ship.nearEdges(ctx), -> ship.draw(ctx)
      stats.update()
    keyup: controls.keyup
    keydown: controls.keydown

window.intersections = ->

  window.stats = Utils.drawStats()
  window.ctx = Sketch.create
    element: document.getElementById('intersections')
    retina: true

  window.polys = [
    new Square([200, 200], 100, "#800"),
    new Square([500, 200], 100, "#008"),
    new Triangle([700, 200], [0,0], [0,200], [100,0], "#080")
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
    mouseup: (e) ->
      (poly.hit = false for poly in polys)
    mousemove: (e) ->
      if @dragging and dragTarget.target
        where = [@mouse.x, @mouse.y]
        dragTarget.target.pos = Vec.add where, dragTarget.offset
    keydown: (e) ->
      if e.keyCode is 32 # space
        triangle = polys[2]
        square = polys[1]
        console.log triangle.intersects square


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
      @hit = false
      return false

    # then do ray cast (poly/line intersection)
    testLine = [[mouseX, mouseY], [maxX + 1, mouseY]]
    count = 0
    for segment in Utils.pairs points
      count += 1 if Utils.linesIntersect testLine, segment

    if count % 2 is 1 # odd number of line crossings is inside the polygon
      @hit = true
    else
      @hit = false
    @hit

  intersects: (other) ->
    for axis in @normalAxes().concat other.normalAxes()
      us = @projectionInterval axis
      them = other.projectionInterval axis
      return false unless Utils.intervalsOverlap us, them
    return true

  projectionInterval: (axis) ->
    Utils.projectionInterval @points(), axis

  normalAxes: ->
    for pair in Utils.pairs @points()
      Vec.vectorNormal Vec.sub pair[1], pair[0]

class Square extends Polygon
  constructor: (@pos, @size, @color) ->
  points: =>
    for offset in [ [0, 0], [1, 0], [1, 1], [0, 1] ]
      Vec.add @pos, Vec.mul(offset, @size)

class Triangle extends Polygon
  constructor: (@pos, @p1, @p2, @p3, @color) ->
  points: =>
    ( Vec.add(@pos, p) for p in [@p1, @p2, @p3] )
