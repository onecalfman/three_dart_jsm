part of jsm_modifiers;

// Original src: https://github.com/zz85/threejs-path-flow
var channels = 4;
int textureWidth = 1024;
int textureHeight = 4;

/// Make a new DataTexture to store the descriptions of the curves.
///
/// @param { number } numberOfCurves the number of curves needed to be described by this texture.
initSplineTexture({int numberOfCurves = 1}) {
  var dataArray = Float32Array((textureWidth * textureHeight * numberOfCurves * channels).toInt());
  var dataTexture = DataTexture(dataArray, textureWidth, textureHeight * numberOfCurves, RGBAFormat, FloatType, null,
      null, null, null, null, null, null);

  dataTexture.wrapS = RepeatWrapping;
  // dataTexture.wrapY = RepeatWrapping;
  dataTexture.magFilter = NearestFilter;
  dataTexture.needsUpdate = true;

  return dataTexture;
}

/// Write the curve description to the data texture
///
/// @param { DataTexture } texture The DataTexture to write to
/// @param { Curve } splineCurve The curve to describe
/// @param { number } offset Which curve slot to write to
updateSplineTexture(texture, splineCurve, {offset = 0}) {
  var numberOfPoints = Math.floor(textureWidth * (textureHeight / 4));
  splineCurve.arcLengthDivisions = numberOfPoints / 2;
  splineCurve.updateArcLengths();
  var points = splineCurve.getSpacedPoints(numberOfPoints);
  var frenetFrames = splineCurve.computeFrenetFrames(numberOfPoints, true);

  for (var i = 0; i < numberOfPoints; i++) {
    var rowOffset = Math.floor(i / textureWidth);
    var rowIndex = i % textureWidth;

    var pt = points[i];
    setTextureValue(texture, rowIndex, pt.x, pt.y, pt.z, 0 + rowOffset + (textureHeight * offset));
    pt = frenetFrames.tangents[i];
    setTextureValue(texture, rowIndex, pt.x, pt.y, pt.z, 1 + rowOffset + (textureHeight * offset));
    pt = frenetFrames.normals[i];
    setTextureValue(texture, rowIndex, pt.x, pt.y, pt.z, 2 + rowOffset + (textureHeight * offset));
    pt = frenetFrames.binormals[i];
    setTextureValue(texture, rowIndex, pt.x, pt.y, pt.z, 3 + rowOffset + (textureHeight * offset));
  }

  texture.needsUpdate = true;
}

setTextureValue(texture, index, x, y, z, o) {
  var image = texture.image;
  var data = image.data;
  var i = channels * textureWidth * o; // Row Offset
  data[index * channels + i + 0] = x;
  data[index * channels + i + 1] = y;
  data[index * channels + i + 2] = z;
  data[index * channels + i + 3] = 1;
}

/// Create a new set of uniforms for describing the curve modifier
///
/// @param { DataTexture } Texture which holds the curve description
getUniforms(splineTexture) {
  var uniforms = {
    "spineTexture": {"value": splineTexture},
    "pathOffset": {"type": 'f', "value": 0}, // time of path curve
    "pathSegment": {"type": 'f', "value": 1}, // fractional length of path
    "spineOffset": {"type": 'f', "value": 161},
    "spineLength": {"type": 'f', "value": 400},
    "flow": {"type": 'i', "value": 1},
  };
  return uniforms;
}

modifyShader(material, uniforms, {numberOfCurves = 1}) {
  if (material.extra["__ok"] != null) return;
  material.extra["__ok"] = true;

  material.onBeforeCompile = (shader) {
    if (shader.__modified == null) {
      return;
    }

    shader.__modified = true;

    // Object.assign( shader.uniforms, uniforms );
    shader.uniforms.addAll(uniforms);

    var mainReplace = """
void main() {
#include <beginnormal_vertex>

vec4 worldPos = modelMatrix * vec4(position, 1.);

bool bend = flow > 0;
float xWeight = bend ? 0. : 1.;

#ifdef USE_INSTANCING
float pathOffsetFromInstanceMatrix = instanceMatrix[3][2];
float spineLengthFromInstanceMatrix = instanceMatrix[3][0];
float spinePortion = bend ? (worldPos.x + spineOffset) / spineLengthFromInstanceMatrix : 0.;
float mt = (spinePortion * pathSegment + pathOffset + pathOffsetFromInstanceMatrix)*textureStacks;
#else
float spinePortion = bend ? (worldPos.x + spineOffset) / spineLength : 0.;
float mt = (spinePortion * pathSegment + pathOffset)*textureStacks;
#endif

mt = mod(mt, textureStacks);
float rowOffset = floor(mt);

#ifdef USE_INSTANCING
rowOffset += instanceMatrix[3][1] * $textureHeight.;
#endif

vec3 spinePos = texture2D(spineTexture, vec2(mt, (0. + rowOffset + 0.5) / textureLayers)).xyz;
vec3 a =        texture2D(spineTexture, vec2(mt, (1. + rowOffset + 0.5) / textureLayers)).xyz;
vec3 b =        texture2D(spineTexture, vec2(mt, (2. + rowOffset + 0.5) / textureLayers)).xyz;
vec3 c =        texture2D(spineTexture, vec2(mt, (3. + rowOffset + 0.5) / textureLayers)).xyz;
mat3 basis = mat3(a, b, c);

vec3 transformed = basis
	* vec3(worldPos.x * xWeight, worldPos.y * 1., worldPos.z * 1.)
	+ spinePos;

vec3 transformedNormal = normalMatrix * (basis * objectNormal);
			""";

    var vertexShader = """
		uniform sampler2D spineTexture;
		uniform float pathOffset;
		uniform float pathSegment;
		uniform float spineOffset;
		uniform float spineLength;
		uniform int flow;

		float textureLayers = ${textureHeight * numberOfCurves}.;
		float textureStacks = ${textureHeight / 4}.;

		${shader.vertexShader}
		"""
        // chunk import moved in front of modified shader below
        .replaceAll('#include <beginnormal_vertex>', '')

        // vec3 transformedNormal declaration overriden below
        .replaceAll('#include <defaultnormal_vertex>', '')

        // vec3 transformed declaration overriden below
        .replaceAll('#include <begin_vertex>', '')

        // shader override
        .replaceFirst(RegExp("void\\s*main\\s*\\(\\)\\s*\\{"), mainReplace)
        .replaceFirst('#include <project_vertex>', """
        vec4 mvPosition = modelViewMatrix * vec4( transformed, 1.0 );
				gl_Position = projectionMatrix * mvPosition;
        """);

    shader.vertexShader = vertexShader;
  };
}

/// A helper class for making meshes bend aroudn curves
class Flow {
  late List curveArray;
  late List curveLengthArray;
  late Mesh object3D;
  late DataTexture splineTexure;
  late Map<String, dynamic> uniforms;

  /// @param {Mesh} mesh The mesh to clone and modify to bend around the curve
  /// @param {number} numberOfCurves The amount of space that should preallocated for additional curves
  Flow(mesh, {numberOfCurves = 1}) {
    var obj3D = mesh.clone();
    var splineTexure = initSplineTexture(numberOfCurves: numberOfCurves);
    var uniforms = getUniforms(splineTexure);
    obj3D.traverse((child) {
      if (child is Mesh || child is InstancedMesh) {
        child.material = child.material.clone();
        modifyShader(child.material, uniforms, numberOfCurves: numberOfCurves);
      }
    });

    curveArray = List.filled(numberOfCurves, null);
    curveLengthArray = List.filled(numberOfCurves, null);

    object3D = obj3D;
    this.splineTexure = splineTexure;
    this.uniforms = uniforms;
  }

  updateCurve(index, curve) {
    if (index >= curveArray.length) throw ('Index out of range for Flow');
    var curveLength = curve.getLength();
    uniforms["spineLength"]["value"] = curveLength;
    curveLengthArray[index] = curveLength;
    curveArray[index] = curve;
    updateSplineTexture(splineTexure, curve, offset: index);
  }

  moveAlongCurve(amount) {
    uniforms["pathOffset"]["value"] += amount;
  }
}

var matrix = Matrix4();

/// A helper class for creating instanced versions of flow, where the instances are placed on the curve.
class InstancedFlow extends Flow {
  late List<int> offsets;
  late List<int> whichCurve;

  InstancedFlow.create(mesh, curveCount) : super(mesh, numberOfCurves: curveCount);

  ///
  /// @param {number} count The number of instanced elements
  /// @param {number} curveCount The number of curves to preallocate for
  /// @param {Geometry} geometry The geometry to use for the instanced mesh
  /// @param {Material} material The material to use for the instanced mesh
  factory InstancedFlow(count, curveCount, geometry, material) {
    var mesh = InstancedMesh(geometry, material, count);
    mesh.instanceMatrix!.setUsage(DynamicDrawUsage);
    var instancedFlow = InstancedFlow.create(mesh, curveCount);

    instancedFlow.offsets = List.filled(count, 0);
    instancedFlow.whichCurve = List.filled(count, 0);

    return instancedFlow;
  }

  /// The extra information about which curve and curve position is stored in the translation components of the matrix for the instanced objects
  /// This writes that information to the matrix and marks it as needing update.
  ///
  /// @param {number} index of the instanced element to update
  writeChanges(index) {
    matrix.makeTranslation(curveLengthArray[whichCurve[index]], whichCurve[index], offsets[index]);

    var obj = object3D as InstancedMesh;

    obj.setMatrixAt(index, matrix);
    obj.instanceMatrix?.needsUpdate = true;
  }

  /// Move an individual element along the curve by a specific amount
  ///
  /// @param {number} index Which element to update
  /// @param {number} offset Move by how much
  moveIndividualAlongCurve(index, int offset) {
    offsets[index] += offset;
    writeChanges(index);
  }

  /// Select which curve to use for an element
  ///
  /// @param {number} index the index of the instanced element to update
  /// @param {number} curveNo the index of the curve it should use
  setCurve(index, curveNo) {
    if (curveNo == null) throw ('curve index being set is Not a Number (NaN)');
    whichCurve[index] = curveNo;
    writeChanges(index);
  }
}
