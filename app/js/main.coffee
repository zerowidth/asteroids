window.asteroids = ->
  window.stats = Utils.drawStats()
  window.ctx = Sketch.create element: document.getElementById('asteroids')
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

