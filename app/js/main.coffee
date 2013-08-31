window.stats = Utils.drawStats()
window.ctx = Sketch.create element: document.getElementById('asteroids')

window.ship = new Ship(ctx.width/2, ctx.height/2)
controls = new Controls

_.extend ctx,
  update: ->
    ship.update ctx.dt / 1000, controls
  draw: ->
    Utils.drawWrapped ctx, ship.nearEdges(ctx), -> ship.draw(ctx)
    stats.update()
  keyup: (e) ->
    switch e.keyCode
      when 37 # left
        controls.left = false
      when 39 # right
        controls.right = false
      when 38 # up
        controls.up = false
  keydown: (e) ->
    switch e.keyCode
      when 37 # left
        controls.left = true
      when 39 # right
        controls.right = true
      when 38 # up
        controls.up = true
