class KeyboardControls
  thrust: false
  left: false
  right: false
  keyup: (e) =>
    switch e.keyCode
      when 37 # left
        @left = false
      when 39 # right
        @right = false
      when 38 # up
        @up = false
  keydown: (e) =>
    switch e.keyCode
      when 37 # left
        @left = true
      when 39 # right
        @right = true
      when 38 # up
        @up = true

Utils =
  drawStats: () ->
    stats = new Stats()
    stats.setMode(0) # 0: fps, 1: ms
    stats.domElement.style.position = 'absolute'
    stats.domElement.style.right = '0px'
    stats.domElement.style.top = '0px'
    document.body.appendChild( stats.domElement )
    stats

  drawWrapped: (ctx, [xEdge,yEdge], drawFn) ->
    drawFn()

    if xEdge isnt 0
      ctx.translate xEdge * ctx.width, 0
      drawFn()
      ctx.translate -xEdge * ctx.width, 0

    if yEdge isnt 0
      ctx.translate 0, yEdge * ctx.height
      drawFn()
      ctx.translate 0, -yEdge * ctx.height

class Grid
  constructor: (@size, @color) ->
  draw: (ctx) =>
    ctx.strokeStyle = @color

    for x in [1..(ctx.width / @size)]
      ctx.beginPath()
      ctx.moveTo x * @size, 0
      ctx.lineTo x * @size, ctx.height
      ctx.stroke()

    for y in [1..(ctx.height / @size)]
      ctx.beginPath()
      ctx.moveTo 0, y * @size
      ctx.lineTo ctx.width, y * @size
      ctx.stroke()


window.KeyboardControls = KeyboardControls
window.Utils = Utils
window.Grid = Grid
