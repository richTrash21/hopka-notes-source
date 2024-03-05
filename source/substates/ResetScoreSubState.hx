package substates;

import backend.WeekData;
import backend.Highscore;

import objects.HealthIcon;

class ResetScoreSubState extends MusicBeatSubstate
{
	var bg:FlxSprite;
	var alphabetArray:Array<Alphabet> = [];
	var icon:HealthIcon;
	var onYes:Bool = false;
	var yesText:Alphabet;
	var noText:Alphabet;

	var song:String;
	var difficulty:Int;
	var week:Int;

	// Week -1 = Freeplay
	public function new(song:String, difficulty:Int, character:String, week:Int = -1)
	{
		this.song = song;
		this.difficulty = difficulty;
		this.week = week;

		super();

		final name:String = '${(week > -1 ? WeekData.weeksLoaded.get(WeekData.weeksList[week]).weekName : song)} (${Difficulty.getString(difficulty)})?';

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		bg.active = false;
		add(bg);

		final tooLong:Float = (name.length > 18) ? 0.8 : 1; //Fucking Winter Horrorland
		final text:Alphabet = new Alphabet(0, 180, "Reset the score of", true);
		text.screenCenter(X);
		alphabetArray.push(text);
		text.alpha = 0;
		text.active = false;
		text.scrollFactor.set();
		add(text);
		final text:Alphabet = new Alphabet(0, text.y + 90, name, true);
		text.scaleX = tooLong;
		text.screenCenter(X);
		if(week == -1) text.x += 60 * tooLong;
		alphabetArray.push(text);
		text.alpha = 0;
		text.active = false;
		text.scrollFactor.set();
		add(text);
		if (week == -1)
		{
			icon = new HealthIcon(character);
			icon.setGraphicSize(Std.int(icon.width * tooLong));
			icon.updateHitbox();
			icon.setPosition(text.x - icon.width + (10 * tooLong), text.y - 30);
			icon.alpha = 0;
			icon.active = false;
			icon.scrollFactor.set();
			add(icon);
		}

		yesText = new Alphabet(0, text.y + 150, 'Yes', true);
		yesText.screenCenter(X);
		yesText.x -= 200;
		yesText.scrollFactor.set();
		yesText.active = false;
		add(yesText);
		noText = new Alphabet(0, text.y + 150, 'No', true);
		noText.screenCenter(X);
		noText.x += 200;
		noText.scrollFactor.set();
		noText.active = false;
		add(noText);
		updateOptions();
	}

	override function update(elapsed:Float)
	{
		bg.alpha = Math.min(bg.alpha + elapsed * 1.5, 0.6);

		for (i in 0...alphabetArray.length)
		{
			final spr = alphabetArray[i];
			spr.alpha += elapsed * 2.5;
		}
		if (week == -1) icon.alpha += elapsed * 2.5;

		if (controls.UI_LEFT_P || controls.UI_RIGHT_P)
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 1);
			onYes = !onYes;
			updateOptions();
		}
		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'), 1);
			close();
		}
		else if (controls.ACCEPT)
		{
			if (onYes)
			{
				(week == -1)
					? Highscore.resetSong(song, difficulty)
					: Highscore.resetWeek(WeekData.weeksList[week], difficulty);
			}
			FlxG.sound.play(Paths.sound('cancelMenu'), 1);
			close();
		}
		super.update(elapsed);
	}

	function updateOptions()
	{
		final scales:Array<Float> = [0.75, 1];
		final alphas:Array<Float> = [0.6, 1.25];
		final confirmInt:Int = onYes ? 1 : 0;

		yesText.alpha = alphas[confirmInt];
		yesText.scale.set(scales[confirmInt], scales[confirmInt]);
		noText.alpha = alphas[1 - confirmInt];
		noText.scale.set(scales[1 - confirmInt], scales[1 - confirmInt]);
		if (week == -1) icon.animation.curAnim.curFrame = confirmInt;
	}
}