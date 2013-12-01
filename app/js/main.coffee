window.go = ->

  window.world = new World "display", 50, "paused"

  window.asteroids = []

  numAsteroids = 20
  avgDistance = 4
  deltaDistance = 2
  avgSize = 1.5
  sizeDelta = 1

  for theta in [0...numAsteroids]
    angle = theta * Math.PI * 2 / numAsteroids
    radius = avgDistance + Utils.random() * deltaDistance - deltaDistance / 2

    position = Vec.polarToVector angle, radius
    direction = Vec.normalize Vec.sub([0,0], position)

    s = avgSize + Utils.random() * sizeDelta - sizeDelta/2

    asteroids.push new Asteroid s,
      position: position
      velocity: Vec.scale direction, Math.random() * 5
      angularVelocity: (Math.PI * 2 * Utils.random() - Math.PI) * 4
      density: 10

  world.addBody a for a in asteroids
