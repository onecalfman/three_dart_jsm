part of jsm_utils;

class GeometryUtils {
  /// Generates 2D-Coordinates in a very fast way.
  ///
  /// Based on work by:
  /// @link http://www.openprocessing.org/sketch/15493
  ///
  /// @param center     Center of Hilbert curve.
  /// @param size       Total width of Hilbert curve.
  /// @param iterations Number of subdivisions.
  /// @param v0         Corner index -X, -Z.
  /// @param v1         Corner index -X, +Z.
  /// @param v2         Corner index +X, +Z.
  /// @param v3         Corner index +X, -Z.
  static hilbert2D(center, size, iterations, v0, v1, v2, v3) {
    // Default Vars
    center = center ?? Vector3(0, 0, 0);
    size = size ?? 10;

    var half = size / 2;
    iterations = iterations ?? 1;
    v0 = v0 ?? 0;
    v1 = v1 ?? 1;
    v2 = v2 ?? 2;
    v3 = v3 ?? 3;

    var vecS = [
      Vector3(center.x - half, center.y, center.z - half),
      Vector3(center.x - half, center.y, center.z + half),
      Vector3(center.x + half, center.y, center.z + half),
      Vector3(center.x + half, center.y, center.z - half)
    ];

    var vec = [vecS[v0], vecS[v1], vecS[v2], vecS[v3]];

    // Recurse iterations
    if (0 <= --iterations) {
      var tmp = [];

      tmp.addAll(GeometryUtils.hilbert2D(vec[0], half, iterations, v0, v3, v2, v1));

      tmp.addAll(GeometryUtils.hilbert2D(vec[1], half, iterations, v0, v1, v2, v3));
      tmp.addAll(GeometryUtils.hilbert2D(vec[2], half, iterations, v0, v1, v2, v3));
      tmp.addAll(GeometryUtils.hilbert2D(vec[3], half, iterations, v2, v1, v0, v3));

      // Return recursive call
      return tmp;
    }

    // Return complete Hilbert Curve.
    return vec;
  }

  /// Generates 3D-Coordinates in a very fast way.
  ///
  /// Based on work by:
  /// @link http://www.openprocessing.org/visuals/?visualID=15599
  ///
  /// @param center     Center of Hilbert curve.
  /// @param size       Total width of Hilbert curve.
  /// @param iterations Number of subdivisions.
  /// @param v0         Corner index -X, +Y, -Z.
  /// @param v1         Corner index -X, +Y, +Z.
  /// @param v2         Corner index -X, -Y, +Z.
  /// @param v3         Corner index -X, -Y, -Z.
  /// @param v4         Corner index +X, -Y, -Z.
  /// @param v5         Corner index +X, -Y, +Z.
  /// @param v6         Corner index +X, +Y, +Z.
  /// @param v7         Corner index +X, +Y, -Z.
  static hilbert3D(center, size, iterations, v0, v1, v2, v3, v4, v5, v6, v7) {
    // Default Vars
    center = center ?? Vector3(0, 0, 0);
    size = size ?? 10;

    var half = size / 2;
    iterations = iterations ?? 1;
    v0 = v0 ?? 0;
    v1 = v1 ?? 1;
    v2 = v2 ?? 2;
    v3 = v3 ?? 3;
    v4 = v4 ?? 4;
    v5 = v5 ?? 5;
    v6 = v6 ?? 6;
    v7 = v7 ?? 7;

    var vecS = [
      Vector3(center.x - half, center.y + half, center.z - half),
      Vector3(center.x - half, center.y + half, center.z + half),
      Vector3(center.x - half, center.y - half, center.z + half),
      Vector3(center.x - half, center.y - half, center.z - half),
      Vector3(center.x + half, center.y - half, center.z - half),
      Vector3(center.x + half, center.y - half, center.z + half),
      Vector3(center.x + half, center.y + half, center.z + half),
      Vector3(center.x + half, center.y + half, center.z - half)
    ];

    var vec = [vecS[v0], vecS[v1], vecS[v2], vecS[v3], vecS[v4], vecS[v5], vecS[v6], vecS[v7]];

    // Recurse iterations
    if (--iterations >= 0) {
      var tmp = [];

      tmp.addAll(GeometryUtils.hilbert3D(vec[0], half, iterations, v0, v3, v4, v7, v6, v5, v2, v1));
      tmp.addAll(GeometryUtils.hilbert3D(vec[1], half, iterations, v0, v7, v6, v1, v2, v5, v4, v3));
      tmp.addAll(GeometryUtils.hilbert3D(vec[2], half, iterations, v0, v7, v6, v1, v2, v5, v4, v3));
      tmp.addAll(GeometryUtils.hilbert3D(vec[3], half, iterations, v2, v3, v0, v1, v6, v7, v4, v5));
      tmp.addAll(GeometryUtils.hilbert3D(vec[4], half, iterations, v2, v3, v0, v1, v6, v7, v4, v5));
      tmp.addAll(GeometryUtils.hilbert3D(vec[5], half, iterations, v4, v3, v2, v5, v6, v1, v0, v7));
      tmp.addAll(GeometryUtils.hilbert3D(vec[6], half, iterations, v4, v3, v2, v5, v6, v1, v0, v7));
      tmp.addAll(GeometryUtils.hilbert3D(vec[7], half, iterations, v6, v5, v2, v1, v0, v3, v4, v7));

      // Return recursive call
      return tmp;
    }

    // Return complete Hilbert Curve.
    return vec;
  }

  /// Generates a Gosper curve (lying in the XY plane)
  ///
  /// https://gist.github.com/nitaku/6521802
  ///
  /// @param size The size of a single gosper island.
  static gosper(size) {
    size = (size != null) ? size : 1;

    fractalize(config) {
      var output;
      var input = config["axiom"];

      for (var i = 0, il = config["steps"]; 0 <= il ? i < il : i > il; 0 <= il ? i++ : i--) {
        output = '';

        for (var j = 0, jl = input.length; j < jl; j++) {
          var char = input[j];

          if (config["rules"].keys.indexOf(char) >= 0) {
            output += config["rules"][char];
          } else {
            output += char;
          }
        }

        input = output;
      }

      return output;
    }

    toPoints(Map<String, dynamic> config) {
      num currX = 0, currY = 0;
      num angle = 0;
      List<num> path = [0, 0, 0];
      var fractal = config["fractal"];

      for (var i = 0, l = fractal.length; i < l; i++) {
        var char = fractal[i];

        if (char == '+') {
          angle += config["angle"];
        } else if (char == '-') {
          angle -= config["angle"];
        } else if (char == 'F') {
          currX += config["size"] * Math.cos(angle);
          currY += -config["size"] * Math.sin(angle);
          path.addAll([currX, currY, 0]);
        }
      }

      return path;
    }

    var gosper = fractalize({
      "axiom": 'A',
      "steps": 4,
      "rules": {"A": 'A+BF++BF-FA--FAFA-BF+', "B": '-FA+BFBF++BF+FA--FA-B'}
    });

    var points = toPoints({
      "fractal": gosper,
      "size": size,
      "angle": Math.pi / 3 // 60 degrees
    });

    return points;
  }
}
