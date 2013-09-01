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
    new Triangle([700, 200], [0,0], [100,0], [0,200], "#080")

  ]

  window.grid = new Grid 20, "#056"

  _.extend ctx,
    draw: ->
      grid.draw ctx
      for poly in polys
        poly.draw ctx
      stats.update()
    mousedown: (e) ->
      where = [@mouse.x, @mouse.y]
      poly.hitTest where for poly in polys
    mouseup: (e) ->
      (poly.hit = false for poly in polys)

class Polygon
  hit: false
  draw: (ctx) =>
    points = @points()
    ctx.save()
    ctx.lineWidth = 2
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

  hitTest: ( [mouseX,mouseY] ) =>
    points = @points()

    maxX = Utils.maxOnAxis points, 0
    maxY = Utils.maxOnAxis points, 1
    minX = Utils.minOnAxis points, 0
    minY = Utils.minOnAxis points, 1

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

class Square extends Polygon
  constructor: (@pos, @size, @color) ->
  points: =>
    for offset in [ [0, 0], [1, 0], [1, 1], [0, 1] ]
      Vec.add @pos, Vec.mul(offset, @size)

class Triangle extends Polygon
  constructor: (@pos, @p1, @p2, @p3, @color) ->
  points: =>
    ( Vec.add(@pos, p) for p in [@p1, @p2, @p3] )
