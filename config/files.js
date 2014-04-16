/* Exports a function which returns an object that overrides the default &
 *   plugin file patterns (used widely through the app configuration)
 *
 * To see the default definitions for Lineman's file paths and globs, see:
 *
 *   - https://github.com/linemanjs/lineman/blob/master/config/files.coffee
 */
module.exports = function(lineman) {
  //Override file patterns here
  return {
    coffee: {
      app: [
        "app/js/vector.coffee",
        "app/js/utils.coffee",
        "app/js/quadtree.coffee",
        "app/js/display.coffee",
        "app/js/world.coffee",
        "app/js/geometry.coffee",
        "app/js/contact.coffee",
        "app/js/polygonal_body.coffee",
        "app/js/bodies.coffee",
        "app/js/particle.coffee",
        "app/js/main.coffee"
      ]
    }

    // As an example, to override the file patterns for
    // the order in which to load third party JS libs:
    //
    // js: {
    //   vendor: [
    //     "vendor/js/underscore.js",
    //     "vendor/js/**/*.js"
    //   ]
    // }
  };
};
