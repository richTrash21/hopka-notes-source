package backend;

#if VIDEOS_ALLOWED
#if hxCodec

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

	public function new(width:Float = 320, height:Float = 240, autoScale:Bool = true)
	{
		super(width, height, autoScale);

		onVideoReady = onVLCVideoReady;
		onComplete = finishVideo;
		onError = onVLCError;

		FlxG.addChildBelowMouse(this);
		FlxG.signals.preUpdate.add(update);

		if (FlxG.autoPause)
		{
			FlxG.signals.focusGained.add(resume);
			FlxG.signals.focusLost.add(pause);
		}
	}

	function update()
	{
		if ((Controls.instance.ACCEPT || Controls.instance.PAUSE) && isPlaying)
			finishVideo();

		volume = (FlxG.sound.muted || FlxG.sound.volume <= 0 ? 0 : FlxG.sound.volume + 0.4);
	}

	#if sys
	inline static function checkFile(fileName:String):String
	{
		#if !android
		var pDir = "";
		if (fileName.indexOf(":") == -1) // Not a path
			pDir = "file:///" + Sys.getCwd() + "/";
		else if (fileName.indexOf("file://") == -1 || fileName.indexOf("http") == -1) // C:, D: etc? ..missing "file:///" ?
			pDir = "file:///";

		return pDir + fileName;
		#else
		return 'file://$fileName';
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

		FlxG.signals.preUpdate.remove(update);
		if (FlxG.autoPause)
		{
			FlxG.signals.focusGained.remove(resume);
			FlxG.signals.focusLost.remove(pause);
		}

		dispose();

		if (FlxG.game.contains(this))
		{
			FlxG.game.removeChild(this);
			if (finishCallback != null)
				finishCallback();
		}
		readyCallback = null;
		finishCallback = null;
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
#else
import openfl.display.BitmapData;

class VideoHandler extends hxvlc.openfl.Video
{
	@:noCompletion override function this_onEnterFrame(event:openfl.events.Event):Void
	{
		if (!events.contains(true))
			return;

		if (events[0])
		{
			events[0] = false;

			onOpening.dispatch();
		}

		if (events[1])
		{
			events[1] = false;

			onPlaying.dispatch();
		}

		if (events[2])
		{
			events[2] = false;

			onStopped.dispatch();
		}

		if (events[3])
		{
			events[3] = false;

			onPaused.dispatch();
		}

		if (events[4])
		{
			events[4] = false;

			onEndReached.dispatch();
		}

		if (events[5])
		{
			events[5] = false;

			final errmsg:String = cast(hxvlc.externs.LibVLC.errmsg(), String);

			onEncounteredError.dispatch(errmsg != null && errmsg.length > 0 ? errmsg : 'Could not specify the error');
		}

		if (events[6])
		{
			events[6] = false;

			onMediaChanged.dispatch();
		}

		if (events[7])
		{
			events[7] = false;

			var mustRecreate:Bool = false;

			if (bitmapData != null)
			{
				if (bitmapData.width != formatWidth && bitmapData.height != formatHeight)
				{
					bitmapData.dispose();

					if (texture != null)
						texture.dispose();

					mustRecreate = true;
				}
			}
			else
				mustRecreate = true;

			if (mustRecreate)
			{
				try
				{
					if (ClientPrefs.data.cacheOnGPU)
						texture = FlxG.stage.context3D.createTexture(formatWidth, formatHeight, BGRA, true);
					else // 1gb cache guaranteed!
					{
						// lime.utils.Log.warn('Failed to use texture, resorting to CPU based image');

						bitmapData = new BitmapData(formatWidth, formatHeight, true, 0);
					}
				}
				catch (e:haxe.Exception)
					lime.utils.Log.error('Failed to create video\'s texture');

				if (texture != null)
					bitmapData = BitmapData.fromTexture(texture);

				onFormatSetup.dispatch();
			}
		}

		if (events[8])
		{
			events[8] = false;

			if (__renderable && planes != null)
			{
				final planesData:haxe.io.BytesData = cpp.Pointer.fromRaw(planes).toUnmanagedArray(formatWidth * formatHeight * 4);

				if (texture != null)
					texture.uploadFromByteArray(planesData, 0);
				else if (bitmapData != null && bitmapData.image != null)
					bitmapData.setPixels(bitmapData.rect, planesData);

				__setRenderDirty();
			}

			onDisplay.dispatch();
		}
	}
}
#end
#end
