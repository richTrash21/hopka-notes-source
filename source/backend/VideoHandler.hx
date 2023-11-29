package backend;

import openfl.events.Event;

/**
 * Play a video using cpp.
 * Use bitmap to connect to a graphic or use `MP4Sprite`.
 * 
 * Stupid edit by @richTrash21
 */
class VideoHandler extends vlc.bitmap.VlcBitmap
{
	public var readyCallback:()->Void;
	public var finishCallback:()->Void;

	var pauseMusic:Bool;

	var controls(get, never):Controls;
	@:noCompletion inline function get_controls():Controls return Controls.instance;

	public function new(width:Float = 320, height:Float = 240, autoScale:Bool = true)
	{
		super(width, height, autoScale);

		onVideoReady = onVLCVideoReady;
		onComplete = finishVideo;
		onError = onVLCError;

		FlxG.addChildBelowMouse(this);

		FlxG.stage.addEventListener(Event.ENTER_FRAME, update);

		if (FlxG.autoPause)
		{
			FlxG.signals.focusGained.add(resume);
			FlxG.signals.focusLost.add(pause);
		}
	}

	function update(e:Event)
	{
		if ((controls.ACCEPT || controls.PAUSE) && isPlaying)
			finishVideo();

		volume = (FlxG.sound.muted || FlxG.sound.volume <= 0 ? 0 : FlxG.sound.volume + 0.4);
	}

	#if sys
	inline static function checkFile(fileName:String):String
	{
		#if !android
		var pDir = "";
		var appDir = "file:///" + Sys.getCwd() + "/";

		if (fileName.indexOf(":") == -1) // Not a path
			pDir = appDir;
		else if (fileName.indexOf("file://") == -1 || fileName.indexOf("http") == -1) // C:, D: etc? ..missing "file:///" ?
			pDir = "file:///";

		return pDir + fileName;
		#else
		return "file://" + fileName;
		#end
	}
	#end

	function onVLCVideoReady()
	{
		trace("Video loaded!");

		if (readyCallback != null)
			readyCallback();
	}

	function onVLCError()
	{
		// TODO: Catch the error
		throw "VLC caught an error!";
	}

	public function finishVideo()
	{
		if (FlxG.sound.music != null && pauseMusic)
			FlxG.sound.music.resume();

		FlxG.stage.removeEventListener(Event.ENTER_FRAME, update);

		dispose();

		if (FlxG.game.contains(this))
		{
			FlxG.game.removeChild(this);

			if (finishCallback != null)
				finishCallback();
		}
	}

	/**
	 * Native video support for Flixel & OpenFL
	 * @param path Example: `your/video/here.mp4`
	 * @param repeat Repeat the video.
	 * @param pauseMusic Pause music until done video.
	 */
	public function playVideo(path:String, ?repeat:Bool = false, pauseMusic:Bool = false)
	{
		this.pauseMusic = pauseMusic;

		if (FlxG.sound.music != null && pauseMusic)
			FlxG.sound.music.pause();

		#if sys
		play(checkFile(path));

		this.repeat = repeat ? -1 : 0;
		#else
		throw "Doesn't support sys";
		#end
	}
}
