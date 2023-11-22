package backend;

interface IMusicBeatState
{
	function stepHit():Void;
	function beatHit():Void;
	function sectionHit():Void;
}