window.Display = class Display
  # ctx    - the canvas context
  # center - [x, y] (world) center of display
  # scale  - pixels per unit (world)
  constructor: (@ctx, @center, @scale) ->

  transform: (points) ->
    dx = @ctx.width/2
    dy = @ctx.height/2
    for [x, y] in points
      # TODO constrain to integers? | 0, etc.?
      [
        (x - @center[0]) * @scale + dx
        (-y + @center[1]) * @scale + dy
      ]

  drawPolygon: (vertices, color, alpha = 0.5) ->
    vertices = @transform vertices...

    @ctx.save()
    @ctx.beginPath()

    @ctx.moveTo vertices[0]...
    for point in vertices[1..]
      @ctx.lineTo point...
    @ctx.lineTo vertices[0]...

    @ctx.globalAlpha = alpha
    @ctx.fillStyle = color
    @ctx.fill()

    @ctx.globalAlpha = 1
    @ctx.strokeStyle = color
    @ctx.stroke()

    @ctx.restore()

  drawCircle: (center, radius, color, alpha = 1) ->
    center = @transform([ center ])[0]
    @ctx.globalAlpha = alpha
    @ctx.fillStyle = color
    @ctx.beginPath()
    @ctx.arc center[0], center[1], radius, 0, Math.PI * 2
    @ctx.fill()

  drawLine: (from, to, width, color, alpha=1) ->
    @ctx.save()

    from = @transform([ from ])[0]
    to = @transform([ to ])[0]

    @ctx.strokeStyle = color
    @ctx.lineWidth = width

    @ctx.globalAlpha = alpha if alpha < 1

    @ctx.beginPath()
    @ctx.moveTo from...
    @ctx.lineTo to...
    @ctx.stroke()

    @ctx.restore()

window.WrappedDisplay = class WrappedDisplay extends Display
  # ctx    - the canvas context
  # center - [x, y] (world) center of display
  # sizeX  - size of display (world, not pixels)
  # sizeY  - size of display (world, not pixels)
  # scale  - pixels per meter
  constructor: (@ctx, @center, @sizeX, @sizeY, @scale) ->

  # TODO constrain to integers? | 0, etc.?
  transform: (points, offset = [0, 0]) ->
    dx = @ctx.width/2
    dy = @ctx.height/2
    for [x, y] in points
      [ ( x - @center[0] + offset[0] * @sizeX) * @scale + dx
        (-y + @center[1] + offset[1] * @sizeY) * @scale + dy ]

  drawPolygons: (polygons, color, lineColor, alpha = 1) ->
    @ctx.beginPath()

    for vertices in polygons
      xOffsets = [0]
      yOffsets = [0]
      # TODO replace with AABB checks (pass in bodies, not vertices)
      xOffsets.push  1 if _.some(vertices, (v) => v[0] < 0)
      xOffsets.push -1 if _.some(vertices, (v) => v[0] > @sizeX)
      yOffsets.push  1 if _.some(vertices, (v) => v[1] > @sizeY)
      yOffsets.push -1 if _.some(vertices, (v) => v[1] < 0)
      for x in xOffsets
        for y in yOffsets
          transformed = @transform vertices, [x, y]
          @ctx.moveTo transformed[0]...
          @ctx.lineTo point... for point in transformed[1..]
          @ctx.lineTo transformed[0]...

    @ctx.globalAlpha = alpha
    @ctx.fillStyle = color
    @ctx.strokeStyle = lineColor
    @ctx.lineWidth = 1
    @ctx.stroke()
    @ctx.fill()

  drawCircles: (centers, radius, color, alpha = 1) ->
    @ctx.globalAlpha = alpha
    @ctx.fillStyle = color
    @ctx.beginPath()

    for center in centers
      center = @transform([ center ])[0]
      @ctx.moveTo center...
      @ctx.arc center[0], center[1], radius, 0, Math.PI * 2

    @ctx.fill()

  bounds: ->
    @transform [ [0,0], [@sizeX, 0], [@sizeX, @sizeY], [0, @sizeY], [0,0] ]

  drawClipped: (fn) ->
    @ctx.save()

    points = @bounds()
    @ctx.beginPath()
    @ctx.moveTo points[0]...
    @ctx.lineTo points[i]... for i in [1..4]
    @ctx.clip()

    fn()

    @ctx.restore()

  # Public: draw the bounds of this display for debugging
  drawBounds: (color="#333") ->
    @ctx.save()

    points = @bounds()

    @ctx.globalAlpha = 1
    @ctx.lineWidth = 1
    @ctx.strokeStyle = color
    @ctx.beginPath()
    @ctx.moveTo points[0]...
    @ctx.lineTo points[i]... for i in [1..4]
    @ctx.stroke()
    @ctx.restore()
