import seedyrng.Random;
import h3d.col.Point as Vec3;

class Axial {
    public final q : Int = 0;
    public final r : Int = 0;
    public function new (q : Int, r : Int) {
        this.q = q;
        this.r = r;
    }

    public function toString() : String {
        return '{q: $q, r: $r}';
    }

    public static function add (a : Axial, b : Axial) : Axial {
        return new Axial(a.q + b.q, a.r + b.r);
    }

    public static function sub (a : Axial, b : Axial) : Axial {
        return new Axial(a.q - b.q, a.r - b.r);
    }

    public static function equals (a : Axial, b : Axial) : Bool {
        return a.q == b.q && a.r == b.r;
    }
}

// Polygon made up of hexagonal tiles
class HexGrid extends h3d.prim.Polygon {

	public final radius : Int;
	public final tileSize : Float;
	public final tilePadding : Float;
	public final tileHeightMultiplier : Float;
    public final tiles : Array<Tile>;

    // Construct a new HexGrid
	public function new(
        radius : Int, 
        tileSize : Float, 
        tilePadding : Float, 
        tileHeightMultiplier : Float, 
        minHeight : Int = 1,
        maxHeight : Int = 2,
        voronoi : Bool = true,
        smoothen : Bool = false,
        smoothRange : Int = 0,
        random : Random = null) {

        // Record radius and size
		this.radius = radius;
        this.tileSize = tileSize;
        this.tilePadding = tilePadding;
        this.tileHeightMultiplier = tileHeightMultiplier;

        // Prepare a random number generator
        if (random == null) {
            random = new Random();
        }

        // Prepare to generate vertices and indices
		var vertices = [];
		var indices = new hxd.IndexBuffer();
        tiles = new Array<Tile>();

        // First pass: generate tiles
        for (r in -radius ... radius + 1) {
            for (q in -radius ... radius + 1) {

                // Make sure tiles adhere to axial laws to form large hexagon
                if (q + r >= -radius && q + r <= radius) {

                    // Generate tile at axial 
                    final pos = new Axial(q, r);
                    final height = random.randomInt(minHeight, maxHeight);
                    final tile = new Tile(
                        pos, 
                        height, 
                        tileSize, 
                        tilePadding, 
                        tileHeightMultiplier,
                        random);
                    tiles.push(tile);
                }
            }
        }

        // Second pass: Use neighbour data to extrude into voronoi pattern
        for (tile in tiles) {

            // Hard code directions for iterating around the tile
            final dirs = [
                new Axial( 1, 0),
                new Axial( 0, 1),
                new Axial(-1, 1),
                new Axial(-1, 0),
                new Axial( 0,-1),
                new Axial( 1,-1)
            ];

            // Iterate for each corner and direction
            for (i in 0 ... 6) {

                // Prepare to reposition corner
                final prevDir = dirs[i > 0 ? i - 1: 5];
                final nextDir = dirs[i];
                final prevTile = getTileAt(Axial.add(tile.pos, prevDir));
                final nextTile = getTileAt(Axial.add(tile.pos, nextDir));

                // Determine if we need to reposition corner for feature points 
                if (voronoi || smoothen) {

                    // // Separate variable for smoothing Z value based on height
                    var smoothedZ = tile.corners[i].z;

                    // Find midpoint between adjacent neighbours
                    var midpoint = if (prevTile != null) {

                        // Both tiles valid - 3 way midpoint
                        if (nextTile != null) {

                            // Extra smoothing logic
                            if (smoothen) {

                                // Always include current tile
                                var count = 1;
                                smoothedZ = tile.height;

                                // Include previous tile in smoothing if applicable
                                if (Math.abs(prevTile.height - tile.height) <= smoothRange) {
                                    smoothedZ += prevTile.height;
                                    count += 1;
                                }

                                // Include next tile in smoothing if applicable
                                if (Math.abs(nextTile.height - tile.height) <= smoothRange) {
                                    smoothedZ += nextTile.height;
                                    count += 1;
                                }

                                // Average all applicable tile heights
                                smoothedZ /= count;
                                smoothedZ *= tileHeightMultiplier;
                            }


                            // Find XY midpoint of all 3 feature points
                            tile.featurePoint
                                .add(prevTile.featurePoint)
                                .add(nextTile.featurePoint)
                                .multiply(1. / 3.);
                        }
                        // Just previous tile valid - 2 way midpoint
                        else {

                            // Only smooth if prev height within parameters
                            if (smoothen && Math.abs(prevTile.height - tile.height) <= smoothRange) {
                                smoothedZ = (tile.height + prevTile.height) * 
                                    tileHeightMultiplier * 0.5;
                            }

                            // Find XY midpoint of tile and previous tile
                            tile.featurePoint
                                .add(prevTile.featurePoint)
                                .multiply(0.5);
                        }
                    }
                    else {
                        // Just next tile valid - 2 way midpoint
                        if (nextTile != null) {

                            // // Only smooth if next height within parameters
                            if (smoothen && Math.abs(nextTile.height - tile.height) <= smoothRange) {
                                smoothedZ = (tile.height + nextTile.height) *
                                    tileHeightMultiplier * 0.5;
                            }

                            // Find XY midpoint of tile and next tile
                            tile.featurePoint
                                .add(nextTile.featurePoint)
                                .multiply(0.5);
                        }
                        // No neighbours - do whatever
                        else {
                            final result = tile.featurePoint
                                .add(tile.corners[i])
                                .multiply(0.5);
                            smoothedZ = result.z;
                            result;
                        }
                    }

                    // Apply voronoi if requested
                    if (voronoi) {

                        // If tiles have padding, shift midpoint to tile center
                        if (tilePadding > 0) {
                            final z = midpoint.z;
                            var toCenter = tile.center.sub(midpoint);
                            toCenter.normalize();
                            toCenter = toCenter.multiply(tilePadding);
                            midpoint = midpoint.add(toCenter);
                            midpoint.z = z;
                        }

                        // Adjust corner to midpoint of neighbouring tiles
                        tile.corners[i].x = midpoint.x;
                        tile.corners[i].y = midpoint.y;
                    }

                    // Apply smoothing if requested
                    if (smoothen) {
                        tile.corners[i].z = smoothedZ;
                    }
                }
            }

            // Adjust feature point height to average corners
            var average = 0.0;
            for (p in tile.corners) {
                average += p.z;
            }
            average /= tile.corners.length;
            tile.featurePoint.z = average;
        }

        // Third pass: Push vertices and indices
        for (tile in tiles) {

            // Record the index of the initial addition to indices
            var startingIndex = vertices.length;

            // Push featured point
            vertices.push(tile.featurePoint.add(new Vec3(0, 0, 0.2)));

            // Push vertices for tile top corners
            for (p in tile.corners) {
                vertices.push(p);
            }

            // Push vertices for tile bottom corners
            for (p in tile.corners) {
                vertices.push(new Vec3(p.x, p.y, 0));
            }

            // Push tile indices
            for (i in 0 ... 6) {

                // Top wedge
                indices.push(startingIndex);
                indices.push(startingIndex + i + 1);
                indices.push(startingIndex + (i < 5 ? i + 2 : 1));

                // Side first half
                indices.push(startingIndex + i + 1);
                indices.push(startingIndex + i + 1 + 6);
                indices.push(startingIndex + (i < 5 ? i + 2 : 1) + 6);

                // Side second half
                indices.push(startingIndex + (i < 5 ? i + 2 : 1) + 6);
                indices.push(startingIndex + (i < 5 ? i + 2 : 1));
                indices.push(startingIndex + i + 1);
            }
        }

        // Send data to buffers
		super(vertices, indices);
	}

    // Retrieve a tile found at any given axial coordinates
    public function getTileAt(coords : Axial) : Tile {
        // @TODO: IMPROVE THIS
        for (tile in tiles) {
            if (Axial.equals(tile.pos, coords)) {
                return tile;
            }
        }

        return null;
    }
}

@:allow(HexGrid)
class Tile {
    public final pos : Axial;
	public final center : Vec3;
	public final featurePoint : Vec3;
    public final size : Float;
    public final padding : Float;
    public final height : Int;
    public final heightMultiplier : Float;
	public final corners : Array<Vec3>;

    public function new (
        pos : Axial, 
        height : Int, 
        size : Float, 
        padding : Float,
        heightMultiplier : Float,
        random : Random) {

        // Record variables for convenience
        this.pos = pos;
        this.height = height;
        this.size = size;
        this.padding = padding;
        this.heightMultiplier = heightMultiplier;

        // Calculate perfect center of hexagon
        final width = Math.sqrt(3) * (size + padding);
        center = new Vec3(
            (pos.q * width ) + (pos.r * width * 0.5), 
            (pos.r * (size + padding) * (3 / 2)), 
            height * heightMultiplier);

        // Generate corners of a regular hexagon
        corners = [for (i in 0...6) {
            final angleDeg = 60 * i - 30;
            final angleRad = Math.PI / 180.0 * angleDeg;
            new Vec3(center.x + size * Math.cos(angleRad),
                     center.y + size * Math.sin(angleRad), 
                     height * heightMultiplier);
        }];

        // Split the hexagon into 3 rhombi and choose one
        final selectedCorner = random.randomInt(0, 2) * 2;
        final corner = corners[selectedCorner];
        final nextCorner = corners[selectedCorner + 1];
        var toCenter = center.sub(corner);
        toCenter.normalize();
        var toNext = nextCorner.sub(corner);
        toNext.normalize();

        // Randomly select a feature point within the rhombus (and hexagon)
        final i = toCenter.multiply(random.random() * size);
        final j = toNext.multiply(random.random() * size);
        featurePoint = corner.add(i).add(j);
    }
}
