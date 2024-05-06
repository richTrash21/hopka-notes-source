package states;

import flixel.FlxBasic;
import flixel.util.FlxSpriteUtil;
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
	extern inline static final _overlapAnimPrefix = "_overlaped";
	public var pressed(default, set):Bool;
	public var selected(default, set):Bool;

	public function new(x = 0., y = 0.)
	{
		super(x, y);
		moves = false;
		antialiasing = ClientPrefs.data.antialiasing;
		frames = Paths.getSparrowAtlas("mainMenuPC/cursor");
		animation.addByPrefix("idle",							"cursor0000", 0, true);
		animation.addByPrefix('idle$_overlapAnimPrefix',		"cursor0001", 0, true);
		animation.addByPrefix("selected",						"cursor0002", 0, true);
		animation.addByPrefix('selected$_overlapAnimPrefix',	"cursor0003", 0, true);
		animation.play("idle");
		offset.x += 6;
		offset.y += 0.1;
		origin.set();
	}

	public override function update(elapsed:Float)
	{
		if (FlxG.mouse.justPressed)
			pressed = true;
		else if (FlxG.mouse.justReleased)
			pressed = false;

		setPosition(FlxG.mouse.x, FlxG.mouse.y);
		super.update(elapsed);
	}

	inline function set_selected(bool:Bool):Bool
	{
		if (bool != selected)
		{
			selected = bool;
			updateAnim();
		}
		return bool;
	}

	inline function set_pressed(bool:Bool):Bool
	{
		if (bool != pressed)
		{
			pressed = bool;
			updateAnim();
		}
		return bool;
	}

	extern inline function updateAnim()
	{
		var anim = selected ? "selected" : "idle";
		if (pressed)
			anim += _overlapAnimPrefix;
		animation.play(anim);
	}
}

@:allow(states.PCState)
class PCState extends MusicBeatState
{
	public static var stupidInstance:PCState;
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
		FlxG.camera.bgColor = 0xff212229;

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
			FlxG.switchState(MainMenuState.new);
		}

		super.update(elapsed);

		if (FlxG.camera.target == null)
		{
			final pointX = FlxMath.bound(FlxG.mouse.screenX, 0, FlxG.width);
			final pointY = FlxMath.bound(FlxG.mouse.screenY, 0, FlxG.height);
			final lerpFactor = Math.exp(-elapsed * 15);
			FlxG.camera.scroll.set(
				FlxMath.lerp((pointX * FlxG.camera.zoom) * 0.034482758620689655, FlxG.camera.scroll.x, lerpFactor), // / 29
				FlxMath.lerp((pointY * FlxG.camera.zoom) * 0.05, FlxG.camera.scroll.y, lerpFactor) // / 20
			);
			FlxG.camera.zoom = defaultZoom - (Math.pow(Math.abs(FlxMath.remapToRange(pointX - monitor.x, 0, monitor.width, -0.25, 0.25)), 2)
									+ Math.pow(Math.abs(FlxMath.remapToRange(pointY - monitor.y, 0, 626.75, -0.2, 0.2)), 2)) * 0.5 * zoomMult;
		}
	}

	override public function destroy()
	{
		for (_ => i in subStates)
			i.destroy();

		subStates.clear();
		subStates = null;

		FlxG.mouse.visible = true;
		FlxG.sound.music.fadeIn(2, FlxG.sound.music.volume);
		super.destroy();
	}
}

class PCSubState extends FlxSubState
{
	var renderer:FlxCameraSprite;
	function new()
	{
		super(0);
	}

	override function create()
	{
		_parentState.persistentUpdate = true;
		super.create();
	}
	override function update(elapsed:Float)
	{
		if (renderer != null)
		@:bypassAccessor
		{
			renderer.thisCamera.x = (renderer.x - renderer.offset.x - FlxG.camera.scroll.x) * renderer.scrollFactor.x;
			renderer.thisCamera.y = (renderer.y - renderer.offset.y - FlxG.camera.scroll.y) * renderer.scrollFactor.y;
		}
		super.update(elapsed);
	}


	function createRenderer(x = 0.0, y = 0.0, w = 1280, h = 720)
	{
		if (renderer == null)
		{
			final leCamera = new FlxInvisibleCamera(0, 0, w, h);
			FlxG.cameras.add(leCamera, false);
			cameras = [leCamera];
			renderer = new FlxCameraSprite(x, y, leCamera);
			renderer.antialiasing = ClientPrefs.data.antialiasing;
			addToScreen(renderer);
		}
		return renderer;
	}

	/*inline function createSprite(x = 0., y = 0., ?scrollFactor:FlxPoint, ?data:EitherType<FlxGraphicAsset, FlxFramesCollection>, ?autoAddAnims = true)
	{
		return PCState.createSprite(x, y, scrollFactor, data, autoAddAnims);
	}*/

	inline function addToScreen(e)					return PCState.stupidInstance.screenStuff.add(e);
	inline function removeToScreen(e, spl = false)	return PCState.stupidInstance.screenStuff.remove(e, spl);
	inline function insertToScreen(index, e)		return PCState.stupidInstance.screenStuff.insert(index, e);
}

class DesktopSubState extends PCSubState
{
	static var iconPos:FlxPoint;
	var tgLookalike:FlxSprite;
	var moveIcon = false;
	override function create()
	{		
		// FlxTween.num(0, 2000, 100, null, (i) -> renderCamera.scroll.x = i);
		createRenderer(35, 40, 930, 572);

		final bg = PCState.createSprite(Paths.image("mainMenuPC/bilss"));
		add(bg.cameraCenter(renderer.thisCamera));

		final logo = PCState.createSprite(Paths.image("mainMenuPC/logo"));
		logo.cameraCenter(renderer.thisCamera).y -= 160;
		add(logo);

		tgLookalike = PCState.createSprite(Paths.getSparrowAtlas("mainMenuPC/fnfgram_icon", false));
		tgLookalike.animation.curAnim.looped = false;
		tgLookalike.animation.curAnim.frameRate = 0;
		add(tgLookalike);

		FlxMouseEvent.add(tgLookalike,
			(s) -> // мышка нажатие
			{
				s.animation.curAnim.curFrame = 2;
				moveIcon = true;
			},
			(s) -> // мышка отжатие
			{
				s.animation.curAnim.curFrame = 1;
				moveIcon = false;
			},
			(s) -> // мышка наведение
			{
				s.animation.curAnim.curFrame = 1;
				moveIcon = false;
			}, 
			(s) -> // мышка убирание
			{
				s.animation.curAnim.curFrame = 0;
				moveIcon = false;
			},
			false, true, false);
		// мышка дабл клик
		FlxMouseEvent.setMouseDoubleClickCallback(tgLookalike, (s) ->
		{
			trace('fnfgram opened event [TBA] $s');
			FlxG.sound.play(Paths.sound("tinky_winky_scream"));
		});
		// мышка передвижение
		FlxMouseEvent.setMouseMoveCallback(tgLookalike, (s) ->
			if (moveIcon)
			{
				s.x += FlxG.mouse.deltaScreenX;
				s.y += FlxG.mouse.deltaScreenY;
				FlxSpriteUtil.cameraBound(s);
				iconPos.set(s.x, s.y);
			});

		if (iconPos == null)
		{
			tgLookalike.cameraCenter(renderer.thisCamera);
			iconPos = FlxPoint.get(tgLookalike.x, tgLookalike.y);
		}
		else // use last icon position
			tgLookalike.setPosition(iconPos.x, iconPos.y);

		var video:VideoSprite;
		Thread.create(()->
		{
			video = new VideoSprite();
			video.autoScale = false;
			video.bitmap.onFormatSetup.add(() ->
			{
				video.setGraphicSize(0, renderer.thisCamera.height * 0.3);
				video.updateHitbox();
				video.setPosition(renderer.thisCamera.width - video.width - 35, renderer.thisCamera.height - video.height - 70);
			});
			video.bitmap.onEndReached.add(Thread.create.bind(() ->
			{
				Sys.sleep(0.1);
				video.load(FlxG.random.getObject(TestVideoState.videos));
				video.play();
			}));
			video.load(FlxG.random.getObject(TestVideoState.videos));
			video.play();
			video.volume = 0.5;
			add(video);
		});
		
		super.create();
	}
}