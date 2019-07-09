window.QuadTree = class QuadTree
  MAX_OBJECTS: 4

  nodes: null # if present: northeast, northwest, southwest, southeast

  constructor: ([@left, @bottom], [@right, @top], @depth=0) ->
    @xMidpoint = @left + (@right - @left) / 2
    @yMidpoint = @bottom + (@top - @bottom) / 2
    @objects   = []

  # Public: insert this object into this quadtree.
  insert: (object, boundingBox) ->
    [[left, bottom], [right, top]] = boundingBox
    return if right < @left or left >= @right or top < @bottom or bottom >= @top

    if (@objects.length <= @MAX_OBJECTS and not @nodes)
      @objects.push [object, boundingBox]
      return

    @subdivide() unless @nodes

    if right >= @xMidpoint
      @nodes[0].insert object, boundingBox if top >= @yMidpoint
      @nodes[3].insert object, boundingBox if bottom < @yMidpoint

    if left < @xMidpoint
      @nodes[1].insert object, boundingBox if top >= @yMidpoint
      @nodes[2].insert object, boundingBox if bottom < @yMidpoint

  # Public: find all objects intersecting the given query AABB
  intersecting: (boundingBox) ->
    [[left, bottom], [right, top]] = boundingBox
    found = []
    @walk (node) ->
      # Bail early if we don't overlap
      return false if right < node.left or left >= node.right or
        top < node.bottom or bottom >= node.top
      found.push object[0] for object in node.objects
      true
    _.uniq found

  # Public: find the objects in the tree at the given point
  atPoint: ([x, y]) ->
    found = []
    @walk (node) ->
      return false if x < node.left or x >= node.right or
        y < node.bottom or node.bottom >= y
      found.push object[0] for object in node.objects
      true
    _.uniq found

  # Prefix iterator of each node in the tree.
  walk: (callback) ->
    keepGoing = callback this
    if @nodes && keepGoing
      node.walk callback for node in @nodes

  subdivide: ->
    @nodes = [
      new QuadTree [@xMidpoint, @yMidpoint], [@right, @top], @depth + 1
      new QuadTree [@left, @yMidpoint], [@xMidpoint, @top], @depth + 1
      new QuadTree [@left, @bottom], [@xMidpoint, @yMidpoint], @depth + 1
      new QuadTree [@xMidpoint, @bottom], [@right, @yMidpoint], @depth + 1
    ]

    for child in @nodes
      for [object, bounds] in @objects
        child.insert object, bounds
    @objects = []





