package backend;

#if VIDEOS_ALLOWED
#if hxCodec
/**
 * This class will play the video in the form of a FlxSprite, which you can control.
 */
class VideoSprite extends flixel.FlxSprite
{
	public var readyCallback:()->Void;
	public var finishCallback:()->Void;
	public var isPlaying(get, never):Bool;

	public var autoScale:Bool;
	var video:VideoHandler;

	public function new(videoWidth:Float = 320, videoHeight:Float = 240, autoScale:Bool = true)
	{
		super();
		visible = false;
		
		video = new VideoHandler(videoWidth, videoHeight, this.autoScale = autoScale);
		video.visible = false;

		video.readyCallback = () ->
		{
			visible = true;
			loadGraphic(video.bitmapData);
			FlxG.cameras.cameraResized.add(cameraResized);
			adjustSize();

			if (readyCallback != null)
				readyCallback();
		}

		video.finishCallback = () ->
		{
			if (finishCallback != null)
				finishCallback();

			FlxG.cameras.cameraResized.remove(cameraResized);
			destroy();
		};
		scrollFactor.set();
	}

	function cameraResized(camera:FlxCamera)
	{
		if (camera == this.camera)
			adjustSize();
	}

	function adjustSize()
	{
		if (autoScale)
		{
			setGraphicSize(camera.width / camera.scaleX, camera.height / camera.scaleY);
			updateHitbox();
			screenCenter();
		}
	}

	override public function destroy()
	{
		readyCallback = null;
		finishCallback = null;
		// video.finishVideo();
		video = null;
		super.destroy();
	}

	/**
	 * Native video support for Flixel & OpenFL
	 * @param path Example: `your/video/here.mp4`
	 * @param repeat Repeat the video.
	 * @param pauseMusic Pause music until done video.
	 */
	inline public function playVideo(path:String, ?repeat:Bool = false, pauseMusic:Bool = false)
	{
		video.playVideo(path, repeat, pauseMusic);
	}

	inline public function pause()
	{
		video.pause();
	}

	inline public function resume()
	{
		video.resume();
	}

	@:noCompletion inline function get_isPlaying():Bool
	{
		return video?.isPlaying;
	}
}
#else
import sys.FileSystem;

class VideoSprite extends flixel.FlxSprite
{
	/**
	 * Whether the video should automatically be paused when focus is lost or not.
	 *
	 * WARNING: Must be set before loading a video.
	 */
	public var autoPause:Bool = FlxG.autoPause;

	/**
	 * Whether flixel should automatically change the volume according to the flixel sound system current volume.
	 */
	public var autoVolumeHandle:Bool = true;
 
	/**
	 * The video bitmap.
	 */
	public var bitmap(default, null):VideoHandler;

	public var autoScale = true;
 
	/**
	 * Creates a `FlxVideoSprite` at a specified position.
	 *
	 * @param x The initial X position of the sprite.
	 * @param y The initial Y position of the sprite.
	 */
	public function new(x = 0, y = 0):Void
	{
		super(x, y);

		makeGraphic(1, 1, FlxColor.TRANSPARENT);

		bitmap = new VideoHandler(antialiasing);
		bitmap.onOpening.add(() -> bitmap.role = hxvlc.externs.Types.LibVLC_Media_Player_Role_T.LibVLC_Role_Game);
		bitmap.onFormatSetup.add(() -> { loadGraphic(bitmap.bitmapData); adjustSize(); });
		// bitmap.visible = false;
		bitmap.alpha = 0;

		FlxG.game.addChild(bitmap);
		FlxG.cameras.cameraResized.add(cameraResized);
	}

	/**
	 * Call this function to load a video.
	 *
	 * @param location The local filesystem path or the media location url or the id of a open file descriptor or the bitstream input.
	 * @param options The additional options you can add to the LibVLC Media.
	 *
	 * @return `true` if the video loaded successfully or `false` if there's an error.
	 */
	public function load(location:hxvlc.util.OneOfThree<String, Int, haxe.io.Bytes>, ?options:Array<String>):Bool
	{
		if (bitmap == null)
			return false;

		if (autoPause)
		{
			if (!FlxG.signals.focusGained.has(resume))
				FlxG.signals.focusGained.add(resume);

			if (!FlxG.signals.focusLost.has(pause))
				FlxG.signals.focusLost.add(pause);
		}

		if (location is String)
		{
			final absolute = FileSystem.absolutePath(location);
			if (FileSystem.exists(absolute))
				return bitmap.load(absolute, options);
		}

		return bitmap.load(location, options);
	}

	/**
	 * Call this function to play a video.
	 *
	 * @return `true` if the video started playing or `false` if there's an error.
	 */
	public function play():Bool
	{
		return bitmap == null ? false : bitmap.play();
	}

	/**
	 * Call this function to stop the video.
	 */
	public function stop():Void
	{
		if (bitmap != null)
			bitmap.stop();
	}

	/**
	 * Call this function to pause the video.
	 */
	public function pause():Void
	{
		if (bitmap != null)
			bitmap.pause();
	}

	/**
	 * Call this function to resume the video.
	 */
	public function resume():Void
	{
		if (bitmap != null)
			bitmap.resume();
	}

	/**
	 * Call this function to toggle the pause of the video.
	 */
	public function togglePaused():Void
	{
		if (bitmap != null)
			bitmap.togglePaused();
	}

	// Overrides
	public override function destroy():Void
	{
		if (FlxG.signals.focusGained.has(resume))
			FlxG.signals.focusGained.remove(resume);

		if (FlxG.signals.focusLost.has(pause))
			FlxG.signals.focusLost.remove(pause);

		FlxG.cameras.cameraResized.remove(cameraResized);

		super.destroy();

		if (bitmap != null)
		{
			bitmap.dispose();

			if (FlxG.game.contains(bitmap))
				FlxG.game.removeChild(bitmap);

			bitmap = null;
		}
	}

	public override function kill():Void
	{
		pause();
		super.kill();
	}

	public override function revive():Void
	{
		super.revive();
		resume();
	}

	public override function update(elapsed:Float):Void
	{
		#if FLX_SOUND_SYSTEM
		if (autoVolumeHandle)
		{
			final curVolume:Int = Math.floor((FlxG.sound.muted || FlxG.sound.volume == 0) ? 0 : FlxG.sound.volume * 100 + 40);

			if (bitmap.volume != curVolume)
				bitmap.volume = curVolume;
		}
		#end

		super.update(elapsed);
	}

	@:noCompletion function cameraResized(camera:FlxCamera)
	{
		if (camera == this.camera)
			adjustSize();
	}

	@:noCompletion function adjustSize()
	{
		if (autoScale)
		{
			setGraphicSize(camera.width / camera.scaleX, camera.height / camera.scaleY);
			updateHitbox();
			screenCenter();
		}
	}

	@:noCompletion override function set_antialiasing(value:Bool):Bool
	{
		if (bitmap != null)
			bitmap.smoothing = value;

		return antialiasing = value;
	}
}
#end
#end
