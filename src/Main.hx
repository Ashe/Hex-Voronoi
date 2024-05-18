import haxe.io.Bytes;
import seedyrng.Random;
import h3d.scene.CameraController;
import Hexgrid;

// Base class for a Heaps application.
// This class contains code to set up a typical Heaps app, including 3D and 2D scene, input, update and loops.
// It's designed to be a base class for an application entry point, and provides several methods for overriding,
// in which we can plug custom code. See API documentation for more information.
class Main extends hxd.App {

	// The map of hexagons
	var map : h3d.scene.Mesh;

	// Map data ///////////////////////////////

	var radius : Int = 5;
	var tileSize : Float = 4.;
	var tilePadding : Float = 0.0;
	var tileHeightMultiplier : Float = 1.5;
	var minHeight : Int = 1;
	var maxHeight : Int = 5;
	var colour : Int = 0;
	var shouldVoronoi : Bool = true;
	var smoothen : Bool = true;
	var smoothRange : Int = 2;
	var seed : haxe.Int64;

	///////////////////////////////////////////

	// Shadowmap for the world
	var shadow : h3d.pass.DefaultShadowMap;

	// Automatic layout system
	var tl_corner : h2d.Flow;
	var bl_corner : h2d.Flow;
	var tr_corner : h2d.Flow;

	// Root widget
	var root : ContainerComp;

	// Reference to CSS styling
	var style = null;

	// Text for amount of draw calls
	var drawCalls : h2d.Text;

	// Camera controller that responds to player input
	var cameraController : h3d.scene.CameraController;

	// Whether the camera should orbit around the map
	var shouldOrbit : Bool = true;

	// Initialise app after assets are loaded
	override function init() {

		/////////////////
		// WORLD SETUP //
		/////////////////

		// Initialise random seed
		var tempRandom = new Random();
		seed = tempRandom.seed;

		// Generate initial map colour
		colour = Std.random(0xFFFFFF);

		// Generate an initial map
		regenerateMap();

		// Create a directional light which refers to our 3D scene
		new h3d.scene.fwd.DirLight(new h3d.Vector( 0.3, -0.4, -0.4), s3d);

		// @TODO: Why is the s3d light system forward-rendered?
		cast(s3d.lightSystem, h3d.scene.fwd.LightSystem).ambientLight.setColor(0x909090);

		// Save reference to shadow map
		shadow = s3d.renderer.getPass(h3d.pass.DefaultShadowMap);

		// Configure shadows
		shadow.size = 2048;
		shadow.power = 200;
		shadow.blur.radius = 0;
		shadow.bias *= 0.1;
		shadow.color.set(0.7, 0.7, 0.7);

		// Create a new particle system and attach to the scene
		var particles = new h3d.parts.GpuParticles(s3d);

		// Add a group to the particle system
		// Alternate syntax: particles.addGroup(g);
		var g = particles.addGroup();

		// Customise the particle group
		g.size = 0.2;
		g.gravity = 1;
		g.life = 10;
		g.nparts = 10000;
		g.emitMode = CameraBounds;
		particles.volumeBounds = h3d.col.Bounds.fromValues( -20, -20, 15, 40, 40, 40);

		// Set the initial position and target of the 3D camera
		s3d.camera.pos.set(80, 130, 80);
		s3d.camera.target.set(0, 0, 0);
		s3d.camera.zNear = 1;
		s3d.camera.zFar = 100;

		// Creates a new camera controller for manipulating the camera of the 3D scene
		cameraController = new h3d.scene.CameraController(s3d);
		cameraController.loadFromCamera();

		////////////////////
		// USER INTERFACE //
		////////////////////

		// TOP LEFT UI

		// Create top-left UI with h2d
		tl_corner = new h2d.Flow(s2d);
		tl_corner.layout = Vertical;
		tl_corner.padding = 10;
		tl_corner.verticalSpacing = 10;

		// Add text for showing FPS
		drawCalls = new h2d.Text(hxd.res.DefaultFont.get(), tl_corner);

		{
			var get = function() { return radius; };
			var set = function(f : Float) {
				final temp = Math.round(f);
				if (radius != temp) { radius = temp; regenerateMap(); }
			};
			addSlider("Map radius", get, set, 1, 19, tl_corner);
		}

		{
			var get = function() { return tileSize; };
			var set = function(f : Float) {
				if (tileSize != f) { tileSize = f; regenerateMap(); }
			};
			addSlider("Tile radius", get, set, 0.1, 50, false, tl_corner);
		}

		{
			var get = function() { return tilePadding; };
			var set = function(f : Float) {
				if (tilePadding != f) { tilePadding = f; regenerateMap(); }
			};
			addSlider("Tile padding", get, set, 0, 2., false, tl_corner);
		}

		{
			var get = function() { return tileHeightMultiplier; };
			var set = function(f : Float) {
				if (tileHeightMultiplier != f) { tileHeightMultiplier = f; regenerateMap(); }
			};
			addSlider("Height mult.", get, set, 0.1, 10., false, tl_corner);
		}

		{
			var get = function() { return minHeight; };
			var set = function(f : Float) {
				final temp = Math.round(f);
				if (minHeight != temp) { minHeight = temp; regenerateMap(); }
			};
			addSlider("Min height", get, set, 0, 100, tl_corner);
		}

		{
			var get = function() { return maxHeight; };
			var set = function(f : Float) {
				final temp = Math.round(f);
				if (maxHeight != temp) { maxHeight = temp; regenerateMap(); }
			};
			addSlider("Max height", get, set, 0, 100, tl_corner);
		}

		var smoothenSlider = {
			var get = function() { return smoothRange; };
			var set = function(f : Float) {
				final temp = Math.round(f);
				if (smoothRange != temp) { smoothRange = temp; regenerateMap(); }
			};
			addSlider("Smooth range", get, set, 0, 10, tl_corner);
		}
		smoothenSlider.visible = smoothen;

		{
			var get = function() { return shouldVoronoi; };
			var set = function(b : Bool) { shouldVoronoi = b; regenerateMap(); };
			addCheck("Voronoi?", get, set, tl_corner);
		}

		{
			var get = function() { return smoothen; };
			var set = function(b : Bool) {
				smoothen = b;
				smoothenSlider.visible = smoothen;
				regenerateMap();
			};
			addCheck("Smoothen?", get, set, tl_corner);
		}

		// BOTTOM LEFT UI

		// Create top-left UI with h2d
		bl_corner = new h2d.Flow(s2d);
		bl_corner.layout = Vertical;
		bl_corner.padding = 10;
		bl_corner.verticalSpacing = 10;
		bl_corner.horizontalAlign = Left;
		bl_corner.verticalAlign = Bottom;

		// Add text credits
		final credits = new h2d.Text(hxd.res.DefaultFont.get(), bl_corner);
		credits.text = "Made by Ashley Rose - https://aas.sh/";

		// TOP RIGHT UI

		// Create top-right UI with domkit
		tr_corner = new h2d.Flow(s2d);
		tr_corner.layout = Vertical;
		tr_corner.padding = 10;
		tr_corner.verticalSpacing = 5;
		tr_corner.horizontalAlign = Right;
		tr_corner.verticalAlign = Top;

		// Update position with screensize
		onResize();

		// Create a custom container
		root = new ContainerComp(Left, tr_corner);

		// When clicked, begin orbiting
		root.orbit.onClick = function() {
			shouldOrbit = !shouldOrbit;
			refreshUI();
		}

		// When clicked, change map colour
		root.colour.onClick = function() {
			colour = Std.random(0xFFFFFF);
			refreshUI();
			regenerateMap();
		}

		// When clicked, refresh map
		root.regenerate.onClick = function() {
			var tempRandom = new Random();
			seed = tempRandom.seed;
			refreshUI();
			regenerateMap();
		}

		// When clicked, reset settings and map
		root.reset.onClick = function() {
			radius = 5;
			tileSize = 4;
			tilePadding = 0.0;
			tileHeightMultiplier = 1.5;
			minHeight = 1;
			maxHeight = 5;
			shouldVoronoi = true;
			smoothen = true;
			smoothRange = 2;
			shouldOrbit = true;
			refreshUI();
			regenerateMap();
		}

		// Initialise style variable and load CSS file from resources
		style = new h2d.domkit.Style();
		style.load(hxd.Res.style);

		// Add the 'root' layout to the loaded style
		style.addObject(root);

		// Enable debugging via middle-clicking elements
		style.allowInspect = true;

		// Update information on UI
		refreshUI();
	}

	function regenerateMap() {

		// Delete the map if it currently exists
		if (map != null) {
			map.remove();
		}

		var random = new Random();
		random.seed = seed;

		// Create the hexagonal grid
		var hexgrid = new HexGrid(
			Math.floor(Math.max(0, radius)),
			tileSize, tilePadding, tileHeightMultiplier,
			Math.floor(Math.max(0, minHeight)),
			Math.floor(Math.max(minHeight, maxHeight)),
			shouldVoronoi, smoothen, smoothRange,
			random);
		hexgrid.unindex();
		hexgrid.addNormals();
		hexgrid.addUVs();

		// Create a material to place on the hex grid
		var mat = h3d.mat.Material.create();
		map = new h3d.scene.Mesh(hexgrid, mat, s3d);

		// Randomise soil texture colour to differenciate chunks
		final c = Math.round(Math.max(0, Math.min(0xFFFFFF, colour)));
		map.material.texture = h3d.mat.Texture.fromColor(c);

		// Allow casting of shadows
		map.material.shadows = true;
	}

	function refreshUI() {
		root.orbit.label.text =
			'Orbiting ${shouldOrbit ? "enabled" : "disabled"}';
		root.colour.label.text = "#" + StringTools.hex(colour);
		root.regenerate.label.text = 'Regenerate map';
		root.reset.label.text = 'Reset';
	}

	override function onResize() {
		// Reposition centre of screen 
		tr_corner.minWidth = tr_corner.maxWidth = s2d.width;
		tr_corner.minHeight = tr_corner.maxHeight = s2d.height;

		bl_corner.setPosition(0, s2d.height - 35);
	}

	// Update application before rendering
	override function update(dt:Float) {

		// If using the orbiting camera
		if (shouldOrbit) {
			var angle = cameraController.theta;
			angle -= dt * 0.5;
			cameraController.set(
				cameraController.distance,
				angle,
				cameraController.phi,
				cameraController.target,
				cameraController.fovY
			);
		}

		// Update contents of text field
		drawCalls.text = "Number of draw calls: " + engine.drawCalls;

		// Update UI
		root.view.details.text =
			'Camera position: ${s3d.camera.pos.toString()}';

		// Update UI elements each frame
		style.sync();
	}

	// Free function acting as entry point to program
	static function main() {

		// Initialise a resource loaded before trying to access resources
		// There are 3 types of file systems
		// - EmbedFileSystem allows us to see resources embedded with code
		// - LocalFileSystem allows us to see resources in asset directory using hard drive access
		// - hxd.fmt.pak.FileSystem allows reading resources from a .pak binary file
		#if hl
		hxd.res.Resource.LIVE_UPDATE = true;
		hxd.Res.initLocal();
		#else
		hxd.Res.initEmbed();
		#end

		// Create and initialise the application
		new Main();
	}
}

// Define a container UI widget to store buttons
@:uiComp("container")
class ContainerComp extends h2d.Flow implements h2d.domkit.Object {

	// Define what this component looks like in terms of widgets
	static var SRC = <container>
		<view(align) public id="view"/>
		<button public id="orbit"/>
		<button public id="colour"/>
		<button public id="regenerate"/>
		<button public id="reset"/>
	</container>;

	// Override constructor
	public function new(align:h2d.Flow.FlowAlign, ?parent) {

		// Initialise component as usual
		super(parent);
		initComponent();
	}
}

// Declare a component that's just a bit of text
// Naming scheme of component classes can be customized with domkit.Macros.registerComponentsPath();
@:uiComp("view")
class ViewComp extends h2d.Flow implements h2d.domkit.Object {

	static var SRC =
	<view class="mybox" min-width="300" content-halign={align}>
		<text public id="details" text={"Details:\n"}/>
	</view>;

	public function new(align:h2d.Flow.FlowAlign, ?parent) {
		super(parent);
		initComponent();
	}
}

// Create a component called 'button' that allows for callbacks when pressed
@:uiComp("button")
class ButtonComp extends h2d.Flow implements h2d.domkit.Object {

	// Buttons contain a simple label
	static var SRC = <button>
		<text public id="label" />
	</button>

	// Override constructor
	public function new( ?parent ) {

		// Initialise component as usual
		super(parent);
		initComponent();

		// Allow the button to be clickable etc
		enableInteractive = true;

		// When clicked, call the 'onClick' function below. By default nothing happens, but it can be rebound
		interactive.onClick = function(_) onClick();

		// When hovered, activate any CSS functionality from CSS
		interactive.onOver = function(_) {
			dom.hover = true;
		};

		// Show that the button is actively pressed when clicked
		interactive.onPush = function(_) {
			dom.active = true;
		};

		// Show that the button is no longer actively pressed when released
		interactive.onRelease = function(_) {
			dom.active = false;
		};

		// When no longer hovered undo things
		interactive.onOut = function(_) {
			dom.hover = false;
		};
	}

	// Dynamic functions are rebindable - by default, onClick calls the onClick function below
	public dynamic function onClick() {
	}
}

function getFont() {
	return hxd.res.DefaultFont.get();
}

function addSlider( label : String, get : Void -> Float, set : Float -> Void, min : Float = 0., max : Float = 1., round : Bool = true, parent : h2d.Object = null) {
		var f = new h2d.Flow(parent);

		f.horizontalSpacing = 5;

		var tf = new h2d.Text(getFont(), f);
		tf.text = label;
		tf.maxWidth = 82;
		tf.textAlign = Right;

		var sli = new h2d.Slider(100, 10, f);
		sli.minValue = min;
		sli.maxValue = max;
		sli.value = get();

		var tf = new h2d.TextInput(getFont(), f);
		tf.text = "" + hxd.Math.fmt(sli.value);
		sli.onChange = function() {
			set(sli.value);
			final v = round ? Math.round(sli.value) : sli.value;
			tf.text = "" + hxd.Math.fmt(v);
			f.needReflow = true;
		};
		tf.onChange = function() {
			var v = Std.parseFloat(tf.text);
			if( Math.isNaN(v) ) return;
			sli.value = v;
			set(v);
		};
		return f;
}

function addCheck( label : String, get : Void -> Bool, set : Bool -> Void, parent : h2d.Object ) {
	var f = new h2d.Flow(parent);

	f.horizontalSpacing = 5;

	var tf = new h2d.Text(getFont(), f);
	tf.text = label;
	tf.maxWidth = 82;
	tf.textAlign = Right;

	var size = 10;
	var b = new h2d.Graphics(f);
	function redraw() {
		b.clear();
		b.beginFill(0x808080);
		b.drawRect(0, 0, size, size);
		b.beginFill(0);
		b.drawRect(1, 1, size-2, size-2);
		if( get() ) {
			b.beginFill(0xC0C0C0);
			b.drawRect(2, 2, size-4, size-4);
		}
	}
	var i = new h2d.Interactive(size, size, b);
	i.onClick = function(_) {
		set(!get());
		redraw();
	};
	redraw();
	return i;
}