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
import lime.utils.Log;
import haxe.io.Bytes;
import openfl.Lib;

class VideoHandler extends hxvlc.openfl.Video
{
	public function new(smoothing = true)
	{
		super(ClientPrefs.data.antialiasing && smoothing);
	}

	@:noCompletion override function update(_):Void
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

			if (errmsg != null && errmsg.length > 0)
				onEncounteredError.dispatch(errmsg);
			else
				onEncounteredError.dispatch('Unknown error');
		}

		if (events[6])
		{
			events[6] = false;

			onMediaChanged.dispatch();
		}

		if (events[7])
		{
			events[7] = false;

			onCorked.dispatch();
		}

		if (events[8])
		{
			events[8] = false;

			onUncorked.dispatch();
		}

		if (events[9])
		{
			events[9] = false;

			onTimeChanged.dispatch(time);
		}

		if (events[10])
		{
			events[10] = false;

			onPositionChanged.dispatch(position);
		}

		if (events[11])
		{
			events[11] = false;

			onLengthChanged.dispatch(length);
		}

		if (events[12])
		{
			events[12] = false;

			onChapterChanged.dispatch(chapter);
		}

		if (events[13])
		{
			events[13] = false;

			var mustRecreate:Bool = false;

			if (bitmapData != null)
			{
				@:privateAccess
				if ((bitmapData.width != formatWidth && bitmapData.height != formatHeight)
					|| ((!ClientPrefs.data.cacheOnGPU && bitmapData.__texture != null) || (ClientPrefs.data.cacheOnGPU && bitmapData.image != null)))
				{
					bitmapData.dispose();

					if (texture != null)
					{
						texture.dispose();
						texture = null;
					}

					mustRecreate = true;
				}
			}
			else
				mustRecreate = true;

			if (mustRecreate)
			{
				try
				{
					if (ClientPrefs.data.cacheOnGPU && Lib.current.stage != null && Lib.current.stage.context3D != null)
					{
						texture = Lib.current.stage.context3D.createRectangleTexture(formatWidth, formatHeight, BGRA, true);

						bitmapData = BitmapData.fromTexture(texture);
					}
					else
					{
						if (ClientPrefs.data.cacheOnGPU)
							Log.warn('Unable to utilize GPU texture, resorting to CPU-based image rendering.');

						bitmapData = new BitmapData(formatWidth, formatHeight, true, 0);
					}
				}
				catch (e:haxe.Exception)
					Log.error('Failed to create video\'s texture: ${e.message}');

				onFormatSetup.dispatch();
			}
		}

		if (events[14])
		{
			events[14] = false;

			if (__renderable && planes != null)
			{
				try
				{
					final planesBytes:Bytes = Bytes.ofData(cpp.Pointer.fromRaw(planes).toUnmanagedArray(formatWidth * formatHeight * 4));

					if (texture != null)
					{
						texture.uploadFromTypedArray(lime.utils.UInt8Array.fromBytes(planesBytes));

						__setRenderDirty();
					}
					else if (bitmapData != null && bitmapData.image != null)
						bitmapData.setPixels(bitmapData.rect, planesBytes);
				}
				catch (e:haxe.Exception)
					Log.error('An error occurred while attempting to render the video: ${e.message}');
			}

			onDisplay.dispatch();
		}
	}
}
#end
#end
