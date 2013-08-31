class Controls
  thrust: false
  left: false
  right: false

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


window.Controls = Controls
window.Utils = Utils
