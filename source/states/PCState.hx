package states;

import objects.FlxCameraSprite;
import sys.thread.Thread;
import backend.VideoSprite;
import flixel.input.mouse.FlxMouseEvent;
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.util.FlxDestroyUtil;

class FlxSpriteMouse extends FlxSprite {
	public var selected(default, set):Bool;
	inline function set_selected(e){
		if (e != selected) animation.play(e ? 'selected' : 'idle');
		return selected = e;
	}
	public function new(X:Float = 0, Y:Float = 0) {
		super(X, Y);
		moves = false;
		antialiasing = ClientPrefs.data.antialiasing;
		frames = Paths.getSparrowAtlas('mainMenuPC/cursor');
		animation.addByPrefix('idle',		'cursor0000', 24, true);
		animation.addByPrefix('selected',	'cursor0001', 24, true);
		animation.play('idle');
		offset.x += 6;
		offset.y += 0.1;
		origin.set();
	}
	public override function update(elapsed:Float){
		if (FlxG.mouse.justPressed)			scale.x = scale.y = 0.9;
		else if(FlxG.mouse.justReleased)	scale.x = scale.y = 1;
		setPosition(FlxG.mouse.x, FlxG.mouse.y);
		super.update(elapsed);
	}
}

@:allow(states.PCState)
class PCState extends MusicBeatState {
	static var stupidInstance:PCState;

	final midSizes:Float = (FlxG.width + FlxG.height) / 2;
	final defaultZoom:Float = 1.05;
	final scaleView:Float = 1.5;
	public var isOnMonitor:Bool = true;
	public var cursor:FlxSpriteMouse;
	public var monitor:FlxSprite;
	public var desc:FlxSprite;
	public var screenStuff:FlxSpriteGroup;
	public var taskBarStuff:FlxSpriteGroup;
	public var mainCamera:FlxCamera;
	public var subStates = new Map<String, PCSubState>();
	var _cashePoint:FlxPoint;
	function new(){
		stupidInstance = this;
		super();
	}
	override function create() {
		destroySubStates = false;
		subStates.set('desktop', new DesktopSubState());

		FlxG.sound.music.fadeOut(1, 0, (_) -> FlxG.sound.music.pause());

		_cashePoint = FlxPoint.get();
		FlxG.camera.bgColor = 0xff212229;

		mainCamera = FlxG.camera;

		add(desc = createSprite(60, 510.25, FlxPoint.weak(0.8, 0.7), Paths.image('mainMenuPC/desc')));
		desc.scale.x = FlxG.width * 1.3;
		desc.scale.y *= 1.4;
		desc.updateHitbox();
		desc.screenCenter(X);

		add(createSprite(2.75, 426, FlxPoint.weak(0.8, 0.7), Paths.image('mainMenuPC/speaker')));

		final speaker = createSprite(FlxG.width - 137 - 2.75, 426, FlxPoint.weak(0.8, 0.7), Paths.image('mainMenuPC/speaker'));
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
		add(monitor = createSprite(55.5, -50, FlxPoint.weak(1.1, 1.1), Paths.getSparrowAtlas('mainMenuPC/monitor_frame')));
		for (i in monitor.animation.getAnimationList()) i.frameRate /= 2;
		screenStuff.scrollFactor.copyFrom(monitor.scrollFactor);
		taskBarStuff.scrollFactor.copyFrom(screenStuff.scrollFactor);
		justblack.scrollFactor.copyFrom(screenStuff.scrollFactor);

		// Taskbar
		taskBarStuff.add(createSprite(151.2, 530, Paths.image('mainMenuPC/taskbar')));
		var startButton = createSprite(79.2, 530, Paths.getSparrowAtlas('mainMenuPC/start_button'), false);
		startButton.animation.addByPrefix('idle', 'start_button0000', 24, true);
		startButton.animation.addByPrefix('selected', 'start_button0001', 24, true);
		startButton.animation.play('idle');
		FlxMouseEvent.add(startButton, null, (_) -> {
			FlxG.sound.play(Paths.sound('lego'), 0.2);
		}, (_) -> startButton.animation.play('selected'), (_) -> startButton.animation.play('idle'), false, true, false);
		taskBarStuff.add(startButton);
		
		var objHitbox:FlxObject;
		FlxMouseEvent.add(objHitbox = createHitbox(847, 594, 60, 25.5, FlxPoint.weak(1.1, 1.1)), (_) -> {
			isOnMonitor = !isOnMonitor;
			monitor.animation.play(isOnMonitor ? 'on' : 'off');
			screenStuff.visible = taskBarStuff.visible = isOnMonitor;
			// if (isOnMonitor) FlxG.sound.play(Paths.sound('pikmin'), 0.6);
		}, null, (_) -> cursor.selected = true, (_) -> cursor.selected = false, false, true, false);

		super.create();

		FlxG.mouse.visible = false;

		FlxG.camera.zoom = defaultZoom;
		openSubState(subStates.get('desktop'));
		
		add(cursor = new FlxSpriteMouse());
	}
	function createHitbox(x:Float, y:Float, width:Float, height:Float, ?scrollFactor:FlxPoint){
		var spr = new FlxObject(x, y, width, height);
		spr.moves = false;
		if (scrollFactor != null){
			spr.x *= scrollFactor.x;
			spr.y *= scrollFactor.y;
			scrollFactor.putWeak();
			scrollFactor.put();
		}
		add(spr);
		return spr;
	}

	function createSprite(x:Float = 0, y:Float = 0, ?scrollFactor:FlxPoint, ?graphic:flixel.system.FlxAssets.FlxGraphicAsset, ?frames:flixel.graphics.frames.FlxFramesCollection, ?autoAddAnims:Bool = true){
		final isAnimated:Bool = frames != null;
		var spr = new FlxSprite(x, y, isAnimated ? null : graphic);
		if (isAnimated){
			spr.frames = frames;
			if (spr.frames != null && autoAddAnims){
				var foundedAnims = [];
				var name = '';
				for (i in spr.frames.framesHash.keys()){
					name = i.substr(0, i.length - 4);
					if (!foundedAnims.contains(name)) foundedAnims.push(name);
				}
				if (foundedAnims.length > 0){
					for (i in foundedAnims) spr.animation.addByPrefix(i, i, 24, true);
					spr.animation.play(foundedAnims[0]);
				}else trace("No animations, damn.");
			}
		}
		spr.antialiasing = ClientPrefs.data.antialiasing;
		spr.moves = false;
		if (scrollFactor != null){
			spr.scrollFactor.copyFrom(scrollFactor);
			scrollFactor.put();
		}
		return spr;
	}

	var zoomMult:Float = 1.;
	public override function update(elapsed) {
		if (controls.BACK){
			FlxG.sound.play(Paths.sound("cancelMenu"));
			MusicBeatState.switchState(MainMenuState.new);
		}
		super.update(elapsed);
		if (mainCamera.target == null){
			_cashePoint.set(FlxMath.bound(FlxG.mouse.screenX, 0, FlxG.width), FlxMath.bound(FlxG.mouse.screenY, 0, FlxG.height));
			var lerpFactor = Math.exp(-elapsed*15);
			mainCamera.scroll.set(
				FlxMath.lerp((_cashePoint.x * mainCamera.zoom) / 29, mainCamera.scroll.x, lerpFactor),
				FlxMath.lerp((_cashePoint.y * mainCamera.zoom) / 20, mainCamera.scroll.y, lerpFactor)
			);
			mainCamera.zoom = defaultZoom - (Math.pow(Math.abs(FlxMath.remapToRange(_cashePoint.x - monitor.x, 0, monitor.width, -0.25, 0.25)), 2)
									+ Math.pow(Math.abs(FlxMath.remapToRange(_cashePoint.y - monitor.y, 0, 626.75, -0.2, 0.2)), 2)) / 2 * zoomMult;
		}
	}
	public override function destroy() {
		for (_ => i in subStates)	i.destroy();
		subStates.clear();
		_cashePoint = FlxDestroyUtil.put(_cashePoint);
		FlxG.mouse.visible = true;
		FlxG.sound.music.fadeIn(2, FlxG.sound.music.volume);
		super.destroy();
	}
}

class PCSubState extends FlxSubState{
	function new() {
		super(0x0);
	}
	override function create() {
		_parentState.persistentUpdate = true;
		super.create();
	}
	inline function createSprite(x:Float, y:Float, ?scrollFactor:FlxPoint, ?graphic:flixel.system.FlxAssets.FlxGraphicAsset, ?frames:flixel.graphics.frames.FlxFramesCollection, ?autoAddAnims:Bool = true)
		return PCState.stupidInstance.createSprite(x, y, scrollFactor, graphic, frames, autoAddAnims);
	inline function addToScreen(e)						 return PCState.stupidInstance.screenStuff.add(e);
	inline function removeToScreen(e, spl:Bool = false)	 return PCState.stupidInstance.screenStuff.remove(e, spl);
	inline function insertToScreen(index, e)			 return PCState.stupidInstance.screenStuff.insert(index, e);
}

class DesktopSubState extends PCSubState{
	var wall:FlxSprite;
	override function create() {
		addToScreen(createSprite(0, 0, Paths.image('mainMenuPC/bilss')));
		
		var funnyCam = new FlxCamera(0, 0, 930, 572);
		FlxG.cameras.add(funnyCam, false);
		funnyCam.x = 1000000; // I DON'T HAVE IDEA HOW TO HIDE, BUT ALLOW RENDERING
		var cameraSprite = new FlxCameraSprite(funnyCam);
		cameraSprite.antialiasing = ClientPrefs.data.antialiasing;
		addToScreen(cameraSprite);
		
		// FlxTween.num(0, 2000, 100, null, (i) -> funnyCam.scroll.x = i);

		var video = new VideoSprite(30, 40);
		video.autoScale = false;
		video.antialiasing = ClientPrefs.data.antialiasing;
		video.cameras = [funnyCam];
		add(video);
		Thread.create(()->{
			video.load(FlxG.random.getObject([Paths.video('Как налить чай в кружку'), 'https://cdn.discordapp.com/attachments/1063500919469252709/1224052634470842460/opening.mp4.mp4.mp4?ex=661c16d9&is=6609a1d9&hm=85aa92e8d05278d6c1ed83cea13122d5354b0a8029e61dcd59837dc16126a66a&', 'https://cdn.discordapp.com/attachments/1063500919469252709/1224030815630000138/win.mp4.mp4?ex=661c0287&is=66098d87&hm=6d543370811afa7dc964b42501e3c97659ec7681d16002436ef6ff907ea621c0&', 'https://cdn.discordapp.com/attachments/1063500919469252709/1224024590859112518/BALLS.mp4?ex=661bfcbb&is=660987bb&hm=cfccfa5be58850ec349b155f58fb91d0a3e74284b841fa3cd10a1258c49d57e3&', 'https://cdn.discordapp.com/attachments/1063500919469252709/1224026129531277412/opening.mp4_1.mp4?ex=661bfe2a&is=6609892a&hm=88c79fef4def8a9a80d19d5d1c9292b8adba5a22686eef2df49a6a79b2d90633&', 'https://cdn.discordapp.com/attachments/1063500919469252709/1224014826859270194/dubbing.mp4.mp4?ex=661bf3a3&is=66097ea3&hm=618de3917a7820cf19655a10fa35e1fa304e6675ff8f292cd124d1b863531ffa&']));
			video.play();
			video.bitmap.onFormatSetup.add(() -> {
				video.loadGraphic(video.bitmap.bitmapData);
				video.setGraphicSize(0, 572);
				video.updateHitbox();
				video.x = (923 - video.width) / 2;
			});
		});
		
		super.create();
	}
}