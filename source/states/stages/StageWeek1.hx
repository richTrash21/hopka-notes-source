package states.stages;

import objects.ExtendedSprite;

class StageWeek1 extends BaseStage
{
	override function create()
	{
		final bg = new ExtendedSprite(-600, -200, "stageback");
		bg.scrollFactor.set(0.9, 0.9);
		add(bg);

		final stageFront = new ExtendedSprite(-650, 600, "stagefront");
		stageFront.setScale(1.1);
		stageFront.updateHitbox();
		add(stageFront);

		if (ClientPrefs.data.lowQuality)
			return; // fuck it

		final stageLight = new ExtendedSprite(-125, -100, "stage_light");
		stageLight.scrollFactor.set(0.9, 0.9);
		stageLight.setScale(1.1);
		stageLight.updateHitbox();
		add(stageLight);

		final stageLight = new ExtendedSprite(1225, -100, "stage_light");
		stageLight.scrollFactor.set(0.9, 0.9);
		stageLight.setScale(1.1);
		stageLight.updateHitbox();
		stageLight.flipX = true;
		add(stageLight);

		final stageCurtains = new ExtendedSprite(-500, -300, "stagecurtains");
		stageCurtains.scrollFactor.set(1.3, 1.3);
		stageCurtains.setScale(0.9);
		stageCurtains.updateHitbox();
		add(stageCurtains);
	}
}