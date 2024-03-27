package options;

class GraphicsSettingsSubState extends BaseOptionsMenu
{
	var spr:FlxSprite;
	var antialiasingOption:Int;
	public function new()
	{
		title = 'Graphics';
		rpcTitle = 'Graphics Settings Menu'; //for Discord Rich Presence

		spr = new FlxSprite(890, 210, Paths.image('newgrounds_logo'));
		spr.setGraphicSize(Std.int(spr.width * 0.85));
		spr.updateHitbox();
		spr.antialiasing = ClientPrefs.data.antialiasing;
		spr.visible = false;

		addOption(new Option('Low Quality',
			'If checked, disables some background details,\ndecreases loading times and improves performance.',
			'lowQuality',
			'bool'
		));

		final option:Option = new Option('Anti-Aliasing',
			'If unchecked, disables anti-aliasing, increases performance\nat the cost of sharper visuals.',
			'antialiasing',
			'bool');
		//Changing change is only needed if you want to make a special interaction after it changes the value
		option.change = () ->
			for (_leState in [this, _parentState])
				_leState.forEachOfType(FlxSprite, (sprite) -> sprite.antialiasing = ClientPrefs.data.antialiasing, true);
		addOption(option);
		antialiasingOption = optionsArray.length-1;

		addOption(new Option('Shaders',
			"If unchecked, disables shaders.\nIt's used for some visual effects, and also CPU intensive for weaker PCs.",
			'shaders',
			'bool'
		));

		addOption(new Option('GPU Caching',
			"If checked, allows the GPU to be used for caching textures, decreasing RAM usage.\nDon't turn this on if you have a shitty Graphics Card.",
			'cacheOnGPU',
			'bool'
		));

		#if !html5 //Apparently other framerates isn't correctly supported on Browser? Probably it has some V-Sync shit enabled by default, idk
		final option:Option = new Option('V-Sync',
			"[!] EXPERIMENTAL [!]\n\nNot really a V-Sync, but something similar.",
			'fixedTimestep',
			'bool');
		option.change = () -> FlxG.fixedTimestep = ClientPrefs.data.fixedTimestep;
		addOption(option);

		final option:Option = new Option('Framerate',
			"Pretty self explanatory, isn't it?",
			'framerate',
			'int');
		option.minValue = ClientPrefs.MIN_FPS;
		option.maxValue = ClientPrefs.MAX_FPS;
		option.displayFormat = '%v FPS';
		option.change = () ->
		{
			if (ClientPrefs.data.framerate > FlxG.drawFramerate)
				FlxG.drawFramerate = FlxG.updateFramerate = ClientPrefs.data.framerate;
			else
				FlxG.updateFramerate = FlxG.drawFramerate = ClientPrefs.data.framerate;
		}
		addOption(option);
		#end

		super();
		insert(2, spr);
	}

	override function changeSelection(change:Int = 0)
	{
		super.changeSelection(change);
		spr.visible = (antialiasingOption == curSelected);
	}

	override function destroy()
	{
		spr = null;
		super.destroy();
	}
}