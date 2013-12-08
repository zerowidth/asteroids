window.QuadTree = class QuadTree
  object: null
  nodes: null # if present: northeast, northwest, southwest, southeast

  constructor: ([@left, @bottom], [@right, @top]) ->
    @xMidpoint = @left + (@right - @left) / 2
    @yMidpoint = @bottom + (@top - @bottom) / 2

  # Public: insert this object into this quadtree.
  insert: (object) ->
    [[left, bottom], [right, top]] = object.aabb()
    return if right < @left or left >= @right or top < @bottom or bottom >= @top

    # Node is empty, add this object.
    if not @object and not @nodes
      @object = object
      return

    @subdivide() unless @nodes

    if right >= @xMidpoint
      @nodes[0].insert object if top >= @yMidpoint
      @nodes[3].insert object if bottom < @yMidpoint

    if left < @xMidpoint
      @nodes[1].insert object if top >= @yMidpoint
      @nodes[2].insert object if bottom < @yMidpoint

  # Prefix iterator of each node in the tree.
  walk: (callback) ->
    callback this
    if @nodes
      node.walk callback for node in @nodes

  subdivide: ->
    @nodes = [
      new QuadTree [@xMidpoint, @yMidpoint], [@right, @top]
      new QuadTree [@left, @yMidpoint], [@xMidpoint, @top]
      new QuadTree [@left, @bottom], [@xMidpoint, @yMidpoint]
      new QuadTree [@xMidpoint, @bottom], [@right, @yMidpoint]
    ]

    for child in @nodes
      child.insert @object

    @object = null # now it's stored deeper!





