window.go = ->

  window.world = new World "display", 200

  window.asteroid = new Asteroid 1,
    position: [0, 0]
    density: 5

  world.addBody asteroid
