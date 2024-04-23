package backend;

interface IMusicBeatState
{
	var curSection:Int;
	var stepsToDo:Int;

	var curStep:Int;
	var curBeat:Int;
	var curDecStep:Float;
	var curDecBeat:Float;

	var lastBeat:Int;
	var lastStep:Int;

	function stepHit():Void;
	function beatHit():Void;
	function sectionHit():Void;
}