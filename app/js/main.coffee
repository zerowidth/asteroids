window.go = ->

  window.world = new World "display"

  window.rect = new Rectangle 5, 0.5,
    position: [0, 0]
    inverseMass: 1/10
    color: "#F00"

  window.rect2 = new Rectangle 1, 1,
    position: [0, 1]
    inverseMass: 1/1
    velocity: [1, -2]
    color: "#08F"

  window.rect3 = new Rectangle 1, 1,
    position: [0,-1]
    inverseMass: 1/1
    velocity: [-1, 2]
    color: "#0AF"

  window.rect4 = new Rectangle 1, 1,
    position: [2.5,-5]
    inverseMass: 1/5
    velocity: [0, 3.5]
    color: "#0CF"

  world.addBody rect
  world.addBody rect2
  world.addBody rect3
  world.addBody rect4

window.debug = (msgs...) ->
  # console.log msgs...

