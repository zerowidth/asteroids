stats = new Stats()
stats.setMode(0) # 0: fps, 1: ms
stats.domElement.style.position = 'absolute'
stats.domElement.style.right = '0px'
stats.domElement.style.top = '0px'
document.body.appendChild( stats.domElement )

ctx = Sketch.create()
ctx.draw = ->
    ctx.beginPath()
    ctx.arc( random( ctx.width ), random( ctx.height ), 20, 0, TWO_PI )
    ctx.fill()
    stats.update()
