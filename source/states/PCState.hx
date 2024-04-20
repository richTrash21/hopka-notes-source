package states;

import haxe.extern.EitherType;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.graphics.frames.FlxFramesCollection;
import objects.FlxCameraSprite;
import sys.thread.Thread;
import backend.VideoSprite;
import flixel.input.mouse.FlxMouseEvent;
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.util.FlxDestroyUtil;

class FlxSpriteMouse extends FlxSprite
{
	public var pressed(default, set):Bool;
	public var selected(default, set):Bool;
	extern inline static final _overlapAnimPrefix = "_overlaped";

	public function new(x = 0., y = 0.)
	{
		super(x, y);
		moves = false;
		antialiasing = ClientPrefs.data.antialiasing;
		frames = Paths.getSparrowAtlas("mainMenuPC/cursor");
		animation.addByPrefix("idle",							"cursor0000", 0, true);
		animation.addByPrefix("idle" + _overlapAnimPrefix,		"cursor0001", 0, true);
		animation.addByPrefix("selected",						"cursor0002", 0, true);
		animation.addByPrefix("selected" + _overlapAnimPrefix,	"cursor0003", 0, true);
		animation.play("idle");
		offset.x += 6;
		offset.y += 0.1;
		origin.set();
	}

	public override function update(elapsed:Float)
	{
		if (FlxG.mouse.justPressed)			pressed = true;
		else if (FlxG.mouse.justReleased)	pressed = false;

		setPosition(FlxG.mouse.x, FlxG.mouse.y);
		super.update(elapsed);
	}

	inline function set_selected(e)
	{
		if (e != selected){
			selected = e;
			updateAnim();
		}
		return e;
	}

	inline function set_pressed(e)
	{
		if (e != pressed){
			pressed = e;
			updateAnim();
		}
		return e;
	}

	extern inline function updateAnim() {
		var anim = selected ? "selected" : "idle";
		if (pressed) anim += _overlapAnimPrefix;
		animation.play(anim);
	}
}

@:allow(states.PCState)
class PCState extends MusicBeatState
{
	public static var stupidInstance:PCState;
	static final _cashePoint:FlxPoint = new FlxPoint();
	static final defaultZoom:Float = 1.05;
	static final scaleView:Float = 1.5;
	static var midSizes = -1.;

	static function createHitbox(x:Float, y:Float, width:Float, height:Float, ?scrollFactor:FlxPoint)
	{
		final obj = new FlxObject(x, y, width, height);
		obj.moves = false;
		if (scrollFactor != null)
			obj.scrollFactor.copyFrom(scrollFactor);

		return obj;
	}

	static function createSprite(x = 0., y = 0., ?scrollFactor:FlxPoint, ?data:EitherType<FlxGraphicAsset, FlxFramesCollection>, autoAddAnims = true)
	{
		final isAnimated = (data is FlxFramesCollection);
		final spr = new FlxSprite(x, y, isAnimated ? null : data);
		if (isAnimated)
		{
			spr.frames = data;
			if (autoAddAnims)
				spr.autoAnimations(0);
		}
		spr.antialiasing = ClientPrefs.data.antialiasing;
		spr.moves = false;
		if (scrollFactor != null)
			spr.scrollFactor.copyFrom(scrollFactor);

		return spr;
	}

	public var isOnMonitor:Bool = true;
	public var cursor:FlxSpriteMouse;
	public var monitor:FlxSprite;
	public var desc:FlxSprite;
	public var screenStuff:FlxSpriteGroup;
	public var taskBarStuff:FlxSpriteGroup;
	public var mainCamera:FlxCamera;
	public var subStates = new Map<String, PCSubState>();
	public var zoomMult = 1.;

	function new()
	{
		if (midSizes == -1)
			midSizes = (FlxG.width + FlxG.height) * 0.5;
		stupidInstance = this;
		super();
	}

	override function create()
	{
		destroySubStates = false;
		subStates.set("desktop", new DesktopSubState());

		FlxG.sound.music.fadeOut(1, 0, (_) -> FlxG.sound.music.pause());

		// _cashePoint = FlxPoint.get();
		FlxG.camera.bgColor = 0xff212229;

		mainCamera = FlxG.camera;

		add(desc = createSprite(60, 510.25, FlxPoint.weak(0.8, 0.7), Paths.image("mainMenuPC/desc")));
		desc.scale.x = FlxG.width * 1.3;
		desc.scale.y *= 1.4;
		desc.updateHitbox();
		desc.screenCenter(X);

		add(createSprite(2.75, 426, FlxPoint.weak(0.8, 0.7), Paths.image("mainMenuPC/speaker")));

		final speaker = createSprite(FlxG.width - 137 - 2.75, 426, FlxPoint.weak(0.8, 0.7), Paths.image("mainMenuPC/speaker"));
		speaker.flipX = true;
		add(speaker);
		
		// Monitor, screen
		var justblack = new FlxSprite(180, 95);
		justblack.frame = FlxG.bitmap.whitePixel;
		justblack.color = 0xff000000;
		justblack.setGraphicSize(923, 572);
		justblack.updateHitbox();
		add(justblack);
		
		add(screenStuff = new FlxSpriteGroup(150, 55));
		add(taskBarStuff = new FlxSpriteGroup(150, 55));
		add(monitor = createSprite(55.5, -50, FlxPoint.weak(1.1, 1.1), Paths.getSparrowAtlas("mainMenuPC/monitor_frame")));
		for (anim in monitor.animation.getAnimationList())
			anim.frameRate *= 0.5;

		justblack.scrollFactor.copyFrom(taskBarStuff.scrollFactor.copyFrom(screenStuff.scrollFactor.copyFrom(monitor.scrollFactor)));

		// Taskbar
		taskBarStuff.add(createSprite(151.2, 531, Paths.image("mainMenuPC/taskbar")));
		var startButton = createSprite(79.2, 531, Paths.getSparrowAtlas("mainMenuPC/start_button"), false);
		startButton.animation.addByPrefix("idle", "start_button", 0, true);
		// startButton.animation.addByPrefix("selected", "start_button0001", 0, true);
		startButton.animation.play("idle");
		FlxMouseEvent.add(startButton, null,
			(_) -> FlxG.sound.play(Paths.sound("lego"), 0.2),
			(_) -> startButton.animation.curAnim.curFrame = 1, // startButton.animation.play("selected")
			(_) -> startButton.animation.curAnim.curFrame = 0, false, true, false); // startButton.animation.play("idle")
		taskBarStuff.add(startButton);
		
		var objHitbox = createHitbox(932.5, 655, 60, 25.5, monitor.scrollFactor);
		add(objHitbox);
		FlxMouseEvent.add(objHitbox, (_) ->
		{
			isOnMonitor = !isOnMonitor;
			monitor.animation.play(isOnMonitor ? "on" : "off");
			screenStuff.visible = taskBarStuff.visible = isOnMonitor;
			// if (isOnMonitor)
			//	FlxG.sound.play(Paths.sound("pikmin"), 0.6);
		}, null, (_) -> cursor.selected = true, (_) -> cursor.selected = false, false, true, false);

		super.create();

		FlxG.mouse.visible = false;

		FlxG.camera.zoom = defaultZoom;
		openSubState(subStates.get("desktop"));
		
		add(cursor = new FlxSpriteMouse());
	}

	public override function update(elapsed)
	{
		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound("cancelMenu"));
			MusicBeatState.switchState(MainMenuState.new);
		}

		super.update(elapsed);

		if (mainCamera.target == null)
		{
			_cashePoint.set(FlxMath.bound(FlxG.mouse.screenX, 0, FlxG.width), FlxMath.bound(FlxG.mouse.screenY, 0, FlxG.height));
			var lerpFactor = Math.exp(-elapsed * 15);
			mainCamera.scroll.set(
				FlxMath.lerp((_cashePoint.x * mainCamera.zoom) * 0.034482758620689655, mainCamera.scroll.x, lerpFactor), // / 29
				FlxMath.lerp((_cashePoint.y * mainCamera.zoom) * 0.05, mainCamera.scroll.y, lerpFactor) // / 20
			);
			mainCamera.zoom = defaultZoom - (Math.pow(Math.abs(FlxMath.remapToRange(_cashePoint.x - monitor.x, 0, monitor.width, -0.25, 0.25)), 2)
									+ Math.pow(Math.abs(FlxMath.remapToRange(_cashePoint.y - monitor.y, 0, 626.75, -0.2, 0.2)), 2)) * 0.5 * zoomMult;
		}
	}

	public override function destroy()
	{
		for (_ => i in subStates)
			i.destroy();

		subStates.clear();
		subStates = null;

		// _cashePoint = FlxDestroyUtil.put(_cashePoint);
		FlxG.mouse.visible = true;
		FlxG.sound.music.fadeIn(2, FlxG.sound.music.volume);
		super.destroy();
	}
}

class PCSubState extends FlxSubState
{
	function new()
	{
		super(0);
	}

	override function create()
	{
		_parentState.persistentUpdate = true;
		super.create();
	}

	/*inline function createSprite(x = 0., y = 0., ?scrollFactor:FlxPoint, ?data:EitherType<FlxGraphicAsset, FlxFramesCollection>, ?autoAddAnims = true)
	{
		return PCState.createSprite(x, y, scrollFactor, data, autoAddAnims);
	}*/

	inline function addToScreen(e)						 return PCState.stupidInstance.screenStuff.add(e);
	inline function removeToScreen(e, spl:Bool = false)	 return PCState.stupidInstance.screenStuff.remove(e, spl);
	inline function insertToScreen(index, e)			 return PCState.stupidInstance.screenStuff.insert(index, e);
}

class DesktopSubState extends PCSubState
{
	var wall:FlxSprite;
	override function create()
	{
		addToScreen(PCState.createSprite(Paths.image("mainMenuPC/bilss")));
		
		var funnyCam = new FlxCamera(0, 0, 930, 572);
		FlxG.cameras.add(funnyCam, false);
		funnyCam.x = 1000000; // I DON'T HAVE IDEA HOW TO HIDE, BUT ALLOW RENDERING
		var cameraSprite = new FlxCameraSprite(35, 40, funnyCam);
		cameraSprite.antialiasing = ClientPrefs.data.antialiasing;
		addToScreen(cameraSprite);
		
		// FlxTween.num(0, 2000, 100, null, (i) -> funnyCam.scroll.x = i);

		var video:VideoSprite;
		Thread.create(()->
		{
			video = new VideoSprite();
			video.autoScale = false;
			video.camera = funnyCam;
			video.bitmap.onFormatSetup.add(() ->
			{
				// video.loadGraphic(video.bitmap.bitmapData);
				video.setGraphicSize(0, 572);
				video.updateHitbox();
				video.x = (funnyCam.width - video.width) * 0.5;
			});
			video.bitmap.onEndReached.add(Thread.create.bind(() ->
			{
				Sys.sleep(0.1);
				video.load(FlxG.random.getObject(TestVideoState.videos));
				video.play();
			}));
			video.load(FlxG.random.getObject(TestVideoState.videos));
			video.play();
			add(video);
		});
		
		super.create();
	}
}