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
	public var selected(default, set):Bool;

	public function new(x = 0., y = 0.)
	{
		super(x, y);
		moves = false;
		antialiasing = ClientPrefs.data.antialiasing;
		frames = Paths.getSparrowAtlas("mainMenuPC/cursor");
		animation.addByPrefix("idle",		"cursor0000", 24, true);
		animation.addByPrefix("selected",	"cursor0001", 24, true);
		animation.play("idle");
		offset.x += 6;
		offset.y += 0.1;
		origin.set();
	}

	public override function update(elapsed:Float)
	{
		if (FlxG.mouse.justPressed)
			scale.x = scale.y = 0.9;
		else if (FlxG.mouse.justReleased)
			scale.x = scale.y = 1;

		setPosition(FlxG.mouse.x, FlxG.mouse.y);
		super.update(elapsed);
	}

	inline function set_selected(e)
	{
		if (e != selected)
			animation.play((selected = e) ? "selected" : "idle");
		return e;
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

	static function createSprite(x = 0., y = 0., ?scrollFactor:FlxPoint, ?data:EitherType<FlxGraphicAsset, FlxFramesCollection>, ?autoAddAnims = true)
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
		taskBarStuff.add(createSprite(151.2, 530, Paths.image("mainMenuPC/taskbar")));
		var startButton = createSprite(79.2, 530, Paths.getSparrowAtlas("mainMenuPC/start_button"), false);
		startButton.animation.addByPrefix("idle", "start_button0000", 0, true);
		startButton.animation.addByPrefix("selected", "start_button0001", 0, true);
		startButton.animation.play("idle");
		FlxMouseEvent.add(startButton, null,
			(_) -> FlxG.sound.play(Paths.sound("lego"), 0.2),
			(_) -> startButton.animation.play("selected"),
			(_) -> startButton.animation.play("idle"), false, true, false);
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
	/*static final funnies = [
		Paths.video("Как налить чай в кружку"),
		"https://cdn.discordapp.com/attachments/1063500919469252709/1224052634470842460/opening.mp4.mp4.mp4?ex=661c16d9&is=6609a1d9&hm=85aa92e8d05278d6c1ed83cea13122d5354b0a8029e61dcd59837dc16126a66a&",
		"https://cdn.discordapp.com/attachments/1063500919469252709/1224030815630000138/win.mp4.mp4?ex=661c0287&is=66098d87&hm=6d543370811afa7dc964b42501e3c97659ec7681d16002436ef6ff907ea621c0&",
		"https://cdn.discordapp.com/attachments/1063500919469252709/1224024590859112518/BALLS.mp4?ex=661bfcbb&is=660987bb&hm=cfccfa5be58850ec349b155f58fb91d0a3e74284b841fa3cd10a1258c49d57e3&",
		"https://cdn.discordapp.com/attachments/1063500919469252709/1224026129531277412/opening.mp4_1.mp4?ex=661bfe2a&is=6609892a&hm=88c79fef4def8a9a80d19d5d1c9292b8adba5a22686eef2df49a6a79b2d90633&",
		"https://cdn.discordapp.com/attachments/1063500919469252709/1224014826859270194/dubbing.mp4.mp4?ex=661bf3a3&is=66097ea3&hm=618de3917a7820cf19655a10fa35e1fa304e6675ff8f292cd124d1b863531ffa&",
		"https://cdn.discordapp.com/attachments/1063500919469252709/1224057863501254837/This_is_probably_the_worst_dub_Ive_ever_made.mp4.mp4?ex=661c1bb8&is=6609a6b8&hm=c0155b4aa4ef6412212b4983ee3e3a87c84a49dac149806f08ec439b34c2cd77&",
		"https://cdn.discordapp.com/attachments/1063500919469252709/1224066052564975766/HopKa_-_5rubles_choki_choki_animation_meme_in_fnf_bezdari_fridaynightfunkin_fnfmod_fnf_Mat.mp4?ex=661c2358&is=6609ae58&hm=268e6897d460640ca6e4e9cf7784337ba31a480ac00b0eb826f5426c9d9d4e4f&",
		"https://cdn.discordapp.com/attachments/791373867897192459/1214602136122429521/video0.mov?ex=661564e3&is=6602efe3&hm=d08c39cd1482d5ca6999b933e190ec9cc341925dbff8a42bdf30e217f4f0835e&"
	];*/

	var wall:FlxSprite;
	override function create()
	{
		addToScreen(PCState.createSprite(Paths.image("mainMenuPC/bilss")));
		
		var funnyCam = new FlxCamera(0, 0, 930, 572);
		FlxG.cameras.add(funnyCam, false);
		funnyCam.x = 1000000; // I DON'T HAVE IDEA HOW TO HIDE, BUT ALLOW RENDERING
		var cameraSprite = new FlxCameraSprite(funnyCam);
		cameraSprite.antialiasing = ClientPrefs.data.antialiasing;
		addToScreen(cameraSprite);
		
		// FlxTween.num(0, 2000, 100, null, (i) -> funnyCam.scroll.x = i);

		var video:VideoSprite;
		Thread.create(()->
		{
			video = new VideoSprite(30, 40);
			video.autoScale = false;
			video.camera = funnyCam;
			video.bitmap.onFormatSetup.add(() ->
			{
				// video.loadGraphic(video.bitmap.bitmapData);
				video.setGraphicSize(0, 572);
				video.updateHitbox();
				video.x = (923 - video.width) * 0.5;
			});
			video.bitmap.onEndReached.add(Thread.create.bind(() ->
			{
				Sys.sleep(1);
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