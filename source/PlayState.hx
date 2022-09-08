package;

import flixel.graphics.FlxGraphic;
#if desktop
import Discord.DiscordClient;
#end
import Section.SwagSection;
import Song.SwagSong;
import WiggleEffect.WiggleEffectType;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.effects.FlxTrail;
import flixel.addons.effects.FlxTrailArea;
import flixel.addons.effects.chainable.FlxEffectSprite;
import flixel.addons.effects.chainable.FlxWaveEffect;
import flixel.addons.transition.FlxTransitionableState;
import flixel.graphics.atlas.FlxAtlas;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.util.FlxCollision;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxTimer;
import haxe.Json;
import lime.utils.Assets;
import openfl.Lib;
import openfl.display.BlendMode;
import openfl.display.StageQuality;
import openfl.filters.BitmapFilter;
import openfl.utils.Assets as OpenFlAssets;
import editors.ChartingState;
import editors.CharacterEditorState;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import Note.EventNote;
import openfl.events.KeyboardEvent;
import flixel.effects.particles.FlxEmitter;
import flixel.effects.particles.FlxParticle;
import flixel.util.FlxSave;
import animateatlas.AtlasFrameMaker;
import Achievements;
import StageData;
import FunkinLua;
import DialogueBoxPsych;
import Conductor.Rating;
#if sys
import sys.FileSystem;
#end
import lime.app.Application;
import flixel.addons.display.FlxBackdrop;

using StringTools;

class PlayState extends MusicBeatState
{
	public static var STRUM_X = 42;
	public static var STRUM_X_MIDDLESCROLL = -278;

	public static var ratingStuff:Array<Dynamic> = [
		['You Suck!', 0.2], //From 0% to 19%
		['Shit', 0.4], //From 20% to 39%
		['Bad', 0.5], //From 40% to 49%
		['Bruh', 0.6], //From 50% to 59%
		['Meh', 0.69], //From 60% to 68%
		['Nice', 0.7], //69%
		['Good', 0.8], //From 70% to 79%
		['Great', 0.9], //From 80% to 89%
		['Sick!', 1], //From 90% to 99%
		['Perfect!!', 1] //The value on this one isn't used actually, since Perfect is always "1"
	];
	public var modchartTweens:Map<String, FlxTween> = new Map<String, FlxTween>();
	public var modchartSprites:Map<String, ModchartSprite> = new Map<String, ModchartSprite>();
	public var modchartTimers:Map<String, FlxTimer> = new Map<String, FlxTimer>();
	public var modchartSounds:Map<String, FlxSound> = new Map<String, FlxSound>();
	public var modchartTexts:Map<String, ModchartText> = new Map<String, ModchartText>();
	public var modchartSaves:Map<String, FlxSave> = new Map<String, FlxSave>();
	public var modchartObjects:Map<String, FlxSprite> = new Map<String, FlxSprite>();

	//event variables
	private var isCameraOnForcedPos:Bool = false;
	#if (haxe >= "4.0.0")
	public var boyfriendMap:Map<String, Boyfriend> = new Map();
	public var dadMap:Map<String, Character> = new Map();
	public var gfMap:Map<String, Character> = new Map();
	#else
	public var boyfriendMap:Map<String, Boyfriend> = new Map<String, Boyfriend>();
	public var dadMap:Map<String, Character> = new Map<String, Character>();
	public var gfMap:Map<String, Character> = new Map<String, Character>();
	#end

	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var DAD_X:Float = 100;
	public var DAD_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;

	public var songSpeedTween:FlxTween;
	public var songSpeed(default, set):Float = 1;
	public var songSpeedType:String = "multiplicative";
	public var noteKillOffset:Float = 350;

	public var boyfriendGroup:FlxSpriteGroup;
	public var dadGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;
	public static var curStage:String = '';
	public static var isPixelStage:Bool = false;
	public static var SONG:SwagSong = null;
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;

	public var spawnTime:Float = 3000;

	public var vocals:FlxSound;

	public var dad:Character = null;
	public var gf:Character = null;
	public var boyfriend:Boyfriend = null;

	public var notes:FlxTypedGroup<Note>;
	public var unspawnNotes:Array<Note> = [];
	public var eventNotes:Array<EventNote> = [];

	private var strumLine:FlxSprite;

	//Handles the new epic mega sexy cam code that i've done
	private var camFollow:FlxPoint;
	private var camFollowPos:FlxObject;
	private static var prevCamFollow:FlxPoint;
	private static var prevCamFollowPos:FlxObject;

	public var strumLineNotes:FlxTypedGroup<StrumNote>;
	public var opponentStrums:FlxTypedGroup<StrumNote>;
	public var playerStrums:FlxTypedGroup<StrumNote>;
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;

	public var camZooming:Bool = false;
	public var camZoomingMult:Float = 1;
	public var camZoomingDecay:Float = 1;
	private var curSong:String = "";

	public var gfSpeed:Int = 1;
	public var health:Float = 1;
	public var combo:Int = 0;

	private var healthBarBG:AttachedSprite;
	public var healthBar:FlxBar;
	var songPercent:Float = 0;

	private var timeBarBG:AttachedSprite;
	public var timeBar:FlxBar;

	public var ratingsData:Array<Rating> = [];
	public var sicks:Int = 0;
	public var goods:Int = 0;
	public var bads:Int = 0;
	public var shits:Int = 0;

	private var generatedMusic:Bool = false;
	public var endingSong:Bool = false;
	public var startingSong:Bool = false;
	private var updateTime:Bool = true;
	public static var changedDifficulty:Bool = false;
	public static var chartingMode:Bool = false;

	//Gameplay settings
	public var healthGain:Float = 1;
	public var healthLoss:Float = 1;
	public var instakillOnMiss:Bool = false;
	public var cpuControlled:Bool = false;
	public var practiceMode:Bool = false;

	public var botplaySine:Float = 0;
	public var botplayTxt:FlxText;

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;
	public var cameraSpeed:Float = 1;

	var dialogue:Array<String> = ['blah blah blah', ':coolswag'];
	var dialogueJson:DialogueFile = null;

	var dadbattleBlack:BGSprite;
	var dadbattleLight:BGSprite;
	var dadbattleSmokes:FlxSpriteGroup;

	var halloweenBG:BGSprite;
	var halloweenWhite:BGSprite;

	var phillyLightsColors:Array<FlxColor>;
	var phillyWindow:BGSprite;
	var phillyStreet:BGSprite;
	var phillyTrain:BGSprite;
	var blammedLightsBlack:FlxSprite;
	var phillyWindowEvent:BGSprite;
	var trainSound:FlxSound;

	var phillyGlowGradient:PhillyGlow.PhillyGlowGradient;
	var phillyGlowParticles:FlxTypedGroup<PhillyGlow.PhillyGlowParticle>;

	var limoKillingState:Int = 0;
	var limo:BGSprite;
	var limoMetalPole:BGSprite;
	var limoLight:BGSprite;
	var limoCorpse:BGSprite;
	var limoCorpseTwo:BGSprite;
	var bgLimo:BGSprite;
	var grpLimoParticles:FlxTypedGroup<BGSprite>;
	var grpLimoDancers:FlxTypedGroup<BackgroundDancer>;
	var fastCar:BGSprite;

	var upperBoppers:BGSprite;
	var bottomBoppers:BGSprite;
	var santa:BGSprite;
	var heyTimer:Float;

	var bgGirls:BackgroundGirls;
	var wiggleShit:WiggleEffect = new WiggleEffect();
	var bgGhouls:BGSprite;

	var tankWatchtower:BGSprite;
	var tankGround:BGSprite;
	var tankmanRun:FlxTypedGroup<TankmenBG>;
	var foregroundSprites:FlxTypedGroup<BGSprite>;

	public var songScore:Int = 0;
	public var songHits:Int = 0;
	public var songMisses:Int = 0;
	public var scoreTxt:FlxText;
	var timeTxt:FlxText;
	var scoreTxtTween:FlxTween;

	public static var campaignScore:Int = 0;
	public static var campaignMisses:Int = 0;
	public static var seenCutscene:Bool = false;
	public static var deathCounter:Int = 0;

	public var defaultCamZoom:Float = 1.05;

	// how big to stretch the pixel art assets
	public static var daPixelZoom:Float = 6;
	private var singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

	public var inCutscene:Bool = false;
	public var skipCountdown:Bool = false;
	var songLength:Float = 0;

	public var boyfriendCameraOffset:Array<Float> = null;
	public var opponentCameraOffset:Array<Float> = null;
	public var girlfriendCameraOffset:Array<Float> = null;

	#if desktop
	// Discord RPC variables
	var storyDifficultyText:String = "";
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end

	//Achievement shit
	var keysPressed:Array<Bool> = [];
	var boyfriendIdleTime:Float = 0.0;
	var boyfriendIdled:Bool = false;

	// Lua shit
	public static var instance:PlayState;
	public var luaArray:Array<FunkinLua> = [];
	private var luaDebugGroup:FlxTypedGroup<DebugLuaText>;
	public var introSoundsSuffix:String = '';

	// Debug buttons
	private var debugKeysChart:Array<FlxKey>;
	private var debugKeysCharacter:Array<FlxKey>;

	// Less laggy controls
	private var keysArray:Array<Dynamic>;

	var precacheList:Map<String, String> = new Map<String, String>();

	var video:MP4Handler = new MP4Handler();

	var satan:BGSprite;
	var firebg:FlxSprite;
	var fx:FlxSprite;
	var Estatic:FlxSprite;
	var blackeffect:FlxSprite;
	var bgbleffect:FlxSprite;
	var snowemitter:FlxEmitter;
	var wbg:FlxSprite;

	var Estatic2:FlxSprite;

	var funnywindow:Bool = false;
	var funnywindowsmall:Bool = false;
	var NOMOREFUNNY:Bool = false;
	var strumy:Int = 50;
	var windowmove:Bool = false;
	var cameramove:Bool = false;

	var defaultStrumX:Array<Float> = [50,162,274,386,690,802,914,1026];
	var defaultStrumY:Float = 50;

	public static var SCREWYOU:Bool = false;

	var kadeEngineWatermark:FlxText;

	var witheredRa:FlxSprite;
	var witheredClouds:FlxBackdrop;
	var fxtwo:FlxSprite;
	public var camOverlay:FlxCamera;

	var WHATTHEFUCK:Bool = false;
	var WTFending:Bool = false;
	var intensecameramove:Bool = false;

	var moveing:Bool = false;

	var bgLol:FlxSprite;
	var cloudsa:FlxSprite;

	override public function create()
	{
		Paths.clearStoredMemory();

		// for lua
		instance = this;

		debugKeysChart = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));
		debugKeysCharacter = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_2'));
		PauseSubState.songName = null; //Reset to default

		keysArray = [
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_left')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_down')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_up')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_right'))
		];

		//Ratings
		ratingsData.push(new Rating('sick')); //default rating

		var rating:Rating = new Rating('good');
		rating.ratingMod = 0.7;
		rating.score = 200;
		rating.noteSplash = false;
		ratingsData.push(rating);

		var rating:Rating = new Rating('bad');
		rating.ratingMod = 0.4;
		rating.score = 100;
		rating.noteSplash = false;
		ratingsData.push(rating);

		var rating:Rating = new Rating('shit');
		rating.ratingMod = 0;
		rating.score = 50;
		rating.noteSplash = false;
		ratingsData.push(rating);

		// For the "Just the Two of Us" achievement
		for (i in 0...keysArray.length)
		{
			keysPressed.push(false);
		}

		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		// Gameplay settings
		healthGain = ClientPrefs.getGameplaySetting('healthgain', 1);
		healthLoss = ClientPrefs.getGameplaySetting('healthloss', 1);
		instakillOnMiss = ClientPrefs.getGameplaySetting('instakill', false);
		practiceMode = ClientPrefs.getGameplaySetting('practice', false);
		cpuControlled = ClientPrefs.getGameplaySetting('botplay', false);

		// var gameCam:FlxCamera = FlxG.camera;
		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camOther = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;
		camOverlay = new FlxCamera();
		camOverlay.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD);
		FlxG.cameras.add(camOther);
		FlxG.cameras.add(camOverlay);
		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();

		FlxCamera.defaultCameras = [camGame];
		CustomFadeTransition.nextCamera = camOther;
		//FlxG.cameras.setDefaultDrawTarget(camGame, true);

		persistentUpdate = true;
		persistentDraw = true;

		if (SONG == null)
			SONG = Song.loadFromJson('tutorial');

		Conductor.mapBPMChanges(SONG);
		Conductor.changeBPM(SONG.bpm);

		FlxG.camera.setFilters([ShadersHandler.chromaticAberration]);
		camHUD.setFilters([ShadersHandler.chromaticAberration]);

		#if desktop
		storyDifficultyText = CoolUtil.difficulties[storyDifficulty];

		// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
		if (isStoryMode)
		{
			detailsText = "Story Mode: " + WeekData.getCurrentWeek().weekName;
		}
		else
		{
			detailsText = "Freeplay";
		}

		// String for when the game is paused
		detailsPausedText = "Paused - " + detailsText;
		#end

		GameOverSubstate.resetVariables();
		var songName:String = Paths.formatToSongPath(SONG.song);

		curStage = SONG.stage;
		//trace('stage is: ' + curStage);
		if(SONG.stage == null || SONG.stage.length < 1) {
			switch (songName)
			{
				case 'cocoa':
					curStage = 'mall';
				default:
					curStage = 'stage';
			}
		}
		SONG.stage = curStage;

		var stageData:StageFile = StageData.getStageFile(curStage);
		if(stageData == null) { //Stage couldn't be found, create a dummy stage for preventing a crash
			stageData = {
				directory: "",
				defaultZoom: 0.9,
				isPixelStage: false,

				boyfriend: [770, 100],
				girlfriend: [400, 130],
				opponent: [100, 100],
				hide_girlfriend: false,

				camera_boyfriend: [0, 0],
				camera_opponent: [0, 0],
				camera_girlfriend: [0, 0],
				camera_speed: 1
			};
		}

		defaultCamZoom = stageData.defaultZoom;
		isPixelStage = stageData.isPixelStage;
		BF_X = stageData.boyfriend[0];
		BF_Y = stageData.boyfriend[1];
		GF_X = stageData.girlfriend[0];
		GF_Y = stageData.girlfriend[1];
		DAD_X = stageData.opponent[0];
		DAD_Y = stageData.opponent[1];

		if(stageData.camera_speed != null)
			cameraSpeed = stageData.camera_speed;

		boyfriendCameraOffset = stageData.camera_boyfriend;
		if(boyfriendCameraOffset == null) //Fucks sake should have done it since the start :rolling_eyes:
			boyfriendCameraOffset = [0, 0];

		opponentCameraOffset = stageData.camera_opponent;
		if(opponentCameraOffset == null)
			opponentCameraOffset = [0, 0];

		girlfriendCameraOffset = stageData.camera_girlfriend;
		if(girlfriendCameraOffset == null)
			girlfriendCameraOffset = [0, 0];

		boyfriendGroup = new FlxSpriteGroup(BF_X, BF_Y);
		dadGroup = new FlxSpriteGroup(DAD_X, DAD_Y);
		gfGroup = new FlxSpriteGroup(GF_X, GF_Y);
		
		switch (curStage)
		{ 	//all the stages here
			case 'ronPissed': //ron
				var sky:BGSprite = new BGSprite('bgs/pissedRon_sky', -100, 20, 0.1, 0.1);
				sky.setGraphicSize(Std.int(sky.width * 1.75));
				add(sky);

				var clouds:BGSprite = new BGSprite('bgs/pissedRon_clouds', -100, 20, 0.2, 0.2);
				clouds.setGraphicSize(Std.int(clouds.width * 1.75));
				add(clouds);

				var ground:BGSprite = new BGSprite('bgs/pissedRon_ground', -850, -500);
				ground.setGraphicSize(Std.int(ground.width * 1.2));
				ground.updateHitbox();
				add(ground);

			case 'ronMad': //ron
				var sky:BGSprite = new BGSprite('bgs/veryAngreRon_sky', -100, 20, 0.1, 0.1);
				sky.setGraphicSize(Std.int(sky.width * 1.75));
				add(sky);

				var clouds:BGSprite = new BGSprite('bgs/veryAngreRon_clouds', -100, 20, 0.2, 0.2);
				clouds.setGraphicSize(Std.int(clouds.width * 1.75));
				add(clouds);
				
				var rain:BGSprite = new BGSprite('bgs/annoyed_rain', -300, 140, 0.5, 0.1, ['rain']);
				rain.animation.addByPrefix('rain', 'rain', 24, true);
				rain.setGraphicSize(Std.int(rain.width * 4));
				rain.updateHitbox();
				rain.screenCenter(XY);
				add(rain);
				rain.animation.play('rain');

				var ground:BGSprite = new BGSprite('bgs/veryAngreRon_ground', -850, -500);
				ground.setGraphicSize(Std.int(ground.width * 1.2));
				ground.updateHitbox();
				add(ground);

			case 'ronNormal': //ron
				var sky:BGSprite = new BGSprite('bgs/happyRon_sky', -100, 20, 0.1, 0.1);
				sky.setGraphicSize(Std.int(sky.width * 1.75));
				add(sky);

				var ground:BGSprite = new BGSprite('bgs/happyRon_ground', -850, -500);
				ground.setGraphicSize(Std.int(ground.width * 1.2));
				ground.updateHitbox();
				add(ground);

			case 'hell': //ron
				var hellbg:BGSprite = new BGSprite('bgs/hell_bg', -300, 140, 0.5, 0.1, ['rain']);
				hellbg.animation.addByPrefix('idle instance 1', 'idle instance 1', 48, true);
				hellbg.setGraphicSize(Std.int(hellbg.width * 5));
				hellbg.updateHitbox();
				hellbg.screenCenter(XY);
				hellbg.y += hellbg.height / 5;
				add(hellbg);
				hellbg.animation.play('idle instance 1');

				firebg = new FlxSprite();
				firebg.frames = Paths.getSparrowAtlas('bgs/escape_fire');
				firebg.scale.set(6,6);
				firebg.animation.addByPrefix('idle', 'fire instance 1', 24, true);
				firebg.animation.play('idle');
				firebg.scrollFactor.set();
				firebg.screenCenter();
				firebg.alpha = 0;
				add(firebg);

				satan = new BGSprite('bgs/hellRon_satan', -600, -500, 0.15, 0.15);
				satan.setGraphicSize(Std.int(satan.width * 1.2));
				satan.screenCenter(XY);
				satan.y -= 100;
				satan.updateHitbox();
				add(satan);

				var ground:BGSprite = new BGSprite('bgs/hellRon_ground', -500, -500);
				ground.setGraphicSize(Std.int(ground.width * 1.2));
				ground.updateHitbox();
				add(ground);

				fx = new FlxSprite().loadGraphic(Paths.image('bgs/effect'));
				fx.setGraphicSize(Std.int(2560 * 1)); // i dont know why but this gets smol if i make it the same size as the kade ver
				fx.updateHitbox();
				fx.antialiasing = true;
				fx.screenCenter(XY);
				fx.scrollFactor.set(0, 0);
				fx.alpha = 0.3;

				blackeffect = new FlxSprite().makeGraphic(FlxG.width*3, FlxG.width*3, FlxColor.BLACK);
				blackeffect.updateHitbox();
				blackeffect.antialiasing = true;
				blackeffect.screenCenter(XY);
				blackeffect.scrollFactor.set();
				blackeffect.alpha = 1;
				if (SONG.song != 'Bloodshed-b')
					blackeffect.alpha = 0;
				add(blackeffect);

				Estatic = new FlxSprite().loadGraphic(Paths.image('bgs/deadly'));
				Estatic.scrollFactor.set();
				Estatic.screenCenter();
				Estatic.alpha = 0;

				Estatic2 = new FlxSprite();
				Estatic2.frames = Paths.getSparrowAtlas('bgs/trojan_static');
				Estatic2.scale.set(4,4);
				Estatic2.animation.addByPrefix('idle', 'static instance 1', 24, true);
				Estatic2.animation.play('idle');
				Estatic2.scrollFactor.set();
				Estatic2.screenCenter();
				Estatic2.alpha = 0;

			// extra shit
			/*case 'daveStage': //ron
				var sky:BGSprite = new BGSprite('bgs/happyRon_sky', -100, 20, 0.1, 0.1);
				sky.setGraphicSize(Std.int(sky.width * 1.75));
				add(sky);

				var ground:BGSprite = new BGSprite('bgs/happyRon_ground', -850, -500);
				ground.setGraphicSize(Std.int(ground.width * 1.2));
				ground.updateHitbox();
				add(ground);*/

			case 'stage': //Week 1
				var bg:BGSprite = new BGSprite('stageback', -537, 100, 0.9, 0.9);
				add(bg);

				var stageFront:BGSprite = new BGSprite('stagefront', -650, 600, 0.9, 0.9);
				stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
				stageFront.updateHitbox();
				add(stageFront);
				if(!ClientPrefs.lowQuality) {
					var stageLight:BGSprite = new BGSprite('stage_light', -125, -100, 0.9, 0.9);
					stageLight.setGraphicSize(Std.int(stageLight.width * 1.1));
					stageLight.updateHitbox();
					add(stageLight);
					var stageLight:BGSprite = new BGSprite('stage_light', 1225, -100, 0.9, 0.9);
					stageLight.setGraphicSize(Std.int(stageLight.width * 1.1));
					stageLight.updateHitbox();
					stageLight.flipX = true;
					add(stageLight);

					var stageCurtains:BGSprite = new BGSprite('stagecurtains', -500, -300, 1.3, 1.3);
					stageCurtains.setGraphicSize(Std.int(stageCurtains.width * 0.9));
					stageCurtains.updateHitbox();
					add(stageCurtains);
				}
			case 'mall': //Week 5 - Cocoa, Eggnog
				var bg:BGSprite = new BGSprite('christmas/bgWalls', -1000, -500, 0.2, 0.2);
				bg.setGraphicSize(Std.int(bg.width * 0.8));
				bg.updateHitbox();
				add(bg);

				if(!ClientPrefs.lowQuality) {
					upperBoppers = new BGSprite('christmas/upperBop', -240, -90, 0.33, 0.33, ['Upper Crowd Bob']);
					upperBoppers.setGraphicSize(Std.int(upperBoppers.width * 0.85));
					upperBoppers.updateHitbox();
					add(upperBoppers);

					var bgEscalator:BGSprite = new BGSprite('christmas/bgEscalator', -1100, -600, 0.3, 0.3);
					bgEscalator.setGraphicSize(Std.int(bgEscalator.width * 0.9));
					bgEscalator.updateHitbox();
					add(bgEscalator);
				}

				var tree:BGSprite = new BGSprite('christmas/christmasTree', 370, -250, 0.40, 0.40);
				add(tree);

				bottomBoppers = new BGSprite('christmas/bottomBop', -300, 140, 0.9, 0.9, ['Bottom Level Boppers Idle']);
				bottomBoppers.animation.addByPrefix('hey', 'Bottom Level Boppers HEY', 24, false);
				bottomBoppers.setGraphicSize(Std.int(bottomBoppers.width * 1));
				bottomBoppers.updateHitbox();
				add(bottomBoppers);

				var fgSnow:BGSprite = new BGSprite('christmas/fgSnow', -600, 700);
				add(fgSnow);

				santa = new BGSprite('christmas/santa', -840, 150, 1, 1, ['santa idle in fear']);
				add(santa);
				precacheList.set('Lights_Shut_off', 'sound');
			case 'daveHouse':
				defaultCamZoom = 0.9;

				var bg:FlxSprite = new FlxSprite(-600, -200).loadGraphic(Paths.image('bgs/sky'));
				bg.antialiasing = true;
				bg.scrollFactor.set(0.75, 0.75);
				bg.active = false;

				add(bg);

				var stageHills:FlxSprite = new FlxSprite(-225, -125).loadGraphic(Paths.image('bgs/hills'));
				stageHills.setGraphicSize(Std.int(stageHills.width * 1.25));
				stageHills.updateHitbox();
				stageHills.antialiasing = true;
				stageHills.scrollFactor.set(0.8, 0.8);
				stageHills.active = false;

				add(stageHills);

				var gate:FlxSprite = new FlxSprite(-200, -125).loadGraphic(Paths.image('bgs/gate'));
				gate.setGraphicSize(Std.int(gate.width * 1.2));
				gate.updateHitbox();
				gate.antialiasing = true;
				gate.scrollFactor.set(0.9, 0.9);
				gate.active = false;

				add(gate);

				var stageFront:FlxSprite = new FlxSprite(-225, -125).loadGraphic(Paths.image('bgs/grass'));
				stageFront.setGraphicSize(Std.int(stageFront.width * 1.2));
				stageFront.updateHitbox();
				stageFront.antialiasing = true;
				stageFront.active = false;

				add(stageFront);
			case 'withered':
				var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('bgs/bobtwerked/annoyed_sky'));
				bg.setGraphicSize(Std.int(bg.width * 0.75));
				bg.scrollFactor.set(0.2,0.2);
				bg.updateHitbox();
				bg.screenCenter(XY);
				add(bg);
				var sun:FlxSprite = new FlxSprite().loadGraphic(Paths.image('bgs/bobtwerked/annoyed_sun'));
				sun.setGraphicSize(Std.int(sun.width * 0.75));
				sun.scrollFactor.set(0.2,0.2);
				sun.updateHitbox();
				sun.screenCenter(XY);
				add(sun);
				witheredRa = new FlxSprite(-512, -260);
				witheredRa.frames = Paths.getSparrowAtlas('bgs/annoyed_rain');
				witheredRa.setGraphicSize(Std.int(witheredRa.width * 4));
				witheredRa.animation.addByPrefix('rain', 'rain', 24, true);
				witheredRa.updateHitbox();
				witheredRa.antialiasing = true;
				witheredRa.scrollFactor.set(0.5,0.1);
				witheredRa.screenCenter(XY);
				add(witheredRa);
				witheredRa.animation.play('rain');
				var wBackground:FlxSprite = new FlxSprite().loadGraphic(Paths.image('bgs/bobtwerked/annoyed_back'));
				wBackground.setGraphicSize(Std.int(wBackground.width * 0.95));
				wBackground.scrollFactor.set(0.4,0.2);
				wBackground.updateHitbox();
				wBackground.screenCenter(XY);
				add(wBackground);
				witheredClouds = new FlxBackdrop(Paths.image('bgs/bobtwerked/annoyed_cloud'), 0.2, 0, true, false);
				witheredClouds.scrollFactor.set(0.2,0);
				witheredClouds.screenCenter(XY);
				witheredClouds.scale.set(0.5,0.5);
				witheredClouds.y -= 180;
				add(witheredClouds);
				var ground:FlxSprite = new FlxSprite(260, -375).loadGraphic(Paths.image('bgs/bobtwerked/annoyed_ground'));
				ground.scale.set(1.1,1.1);
				ground.scrollFactor.set(1,1);
				ground.updateHitbox();
				ground.screenCenter(X);
				add(ground);
			case 'win':
				{
					defaultCamZoom = 0.8;
					var bg:FlxSprite = new FlxSprite();
					bg.frames = Paths.getSparrowAtlas('bgs/trojan_bg');
					bg.scale.set(4, 4);
					bg.animation.addByPrefix('idle', 'bg instance 1', 24, true);
					bg.animation.play('idle');
					bg.scrollFactor.set(0.05, 0.05);
					bg.screenCenter();
					add(bg);
					Estatic2 = new FlxSprite().loadGraphic(Paths.image('bgs/deadly'));
					Estatic2.scrollFactor.set();
					Estatic2.screenCenter();
					Estatic2.alpha = 0;
					var console:FlxSprite = new FlxSprite();
					console.frames = Paths.getSparrowAtlas('bgs/trojan_console');
					console.scale.set(4, 4);
					console.animation.addByPrefix('idle', 'ezgif.com-gif-maker (7)_gif instance 1', 24, true);
					console.animation.play('idle');
					console.scrollFactor.set(0.05, 0.05);
					console.screenCenter();
					console.alpha = 0.3;
					add(console);
					var popup:FlxSprite = new FlxSprite();
					popup.frames = Paths.getSparrowAtlas('bgs/atelo_popup_animated');
					popup.scale.set(4, 4);
					popup.animation.addByPrefix('idle', 'popups instance 1', 24, true);
					popup.animation.play('idle');
					popup.scrollFactor.set(0.05, 0.05);
					popup.screenCenter();
					add(popup);
					var lamp:FlxSprite = new FlxSprite(900, 100);
					lamp.frames = Paths.getSparrowAtlas('bgs/glitch_lamp');
					lamp.scale.set(2, 2);
					lamp.animation.addByPrefix('idle', 'lamppost', 24, true);
					lamp.animation.play('idle');
					lamp.scrollFactor.set(0.9, 0.9);
					add(lamp);
					var ground:FlxSprite = new FlxSprite(-537, -290).loadGraphic(Paths.image('bgs/trojan_ground'));
					ground.updateHitbox();
					ground.active = false;
					ground.antialiasing = true;
					add(ground);
					var error:FlxSprite = new FlxSprite(900, 550);
					error.frames = Paths.getSparrowAtlas('bgs/error');
					error.scale.set(2, 2);
					error.animation.addByPrefix('idle', 'error instance 1', 24, true);
					error.animation.play('idle');
					error.updateHitbox();
					error.antialiasing = true;
					add(error);
					Estatic = new FlxSprite();
					Estatic.frames = Paths.getSparrowAtlas('bgs/trojan_static');
					Estatic.scale.set(4, 4);
					Estatic.animation.addByPrefix('idle', 'static instance 1', 24, true);
					Estatic.animation.play('idle');
					Estatic.scrollFactor.set();
					Estatic.screenCenter();
				}
			case 'verymad': // trojan virus
				{
					defaultCamZoom = 0.9;
					curStage = 'verymad';
					var bg2:FlxSprite = new FlxSprite();
					bg2.frames = Paths.getSparrowAtlas('bgs/trojan_bg');
					bg2.scale.set(4, 4);
					bg2.animation.addByPrefix('idle', 'bg instance 1', 24, true);
					bg2.animation.play('idle');
					bg2.scrollFactor.set(0.05, 0.05);
					bg2.screenCenter();
					add(bg2);
					Estatic2 = new FlxSprite();
					Estatic2.frames = Paths.getSparrowAtlas('bgs/trojan_static');
					Estatic2.scale.set(4, 4);
					Estatic2.animation.addByPrefix('idle', 'static instance 1', 24, true);
					Estatic2.animation.play('idle');
					Estatic2.scrollFactor.set();
					Estatic2.screenCenter();
					add(Estatic2);
					var console:FlxSprite = new FlxSprite();
					console.frames = Paths.getSparrowAtlas('bgs/trojan_console');
					console.scale.set(4, 4);
					console.animation.addByPrefix('idle', 'ezgif.com-gif-maker (7)_gif instance 1', 24, true);
					console.animation.play('idle');
					console.scrollFactor.set(0.05, 0.05);
					console.screenCenter();
					console.alpha = 0.3;
					add(console);
					var popup:FlxSprite = new FlxSprite();
					popup.frames = Paths.getSparrowAtlas('bgs/atelo_popup_animated');
					popup.scale.set(4, 4);
					popup.animation.addByPrefix('idle', 'popups instance 1', 24, true);
					popup.animation.play('idle');
					popup.scrollFactor.set(0.05, 0.05);
					popup.screenCenter();
					add(popup);
					bgLol = new FlxSprite(-100, 10).loadGraphic(Paths.image('bgs/veryAngreRon_sky'));
					bgLol.updateHitbox();
					bgLol.scale.x = 1;
					bgLol.scale.y = 1;
					bgLol.active = false;
					bgLol.antialiasing = true;
					bgLol.screenCenter();
					bgLol.scrollFactor.set(0.1, 0.1);
					add(bgLol);
					witheredRa = new FlxSprite(-512, -260);
					witheredRa.frames = Paths.getSparrowAtlas('bgs/annoyed_rain');
					witheredRa.setGraphicSize(Std.int(witheredRa.width * 4));
					witheredRa.animation.addByPrefix('rain', 'rain', 24, true);
					witheredRa.updateHitbox();
					witheredRa.antialiasing = true;
					witheredRa.scrollFactor.set(0.5, 0.1);
					witheredRa.screenCenter(XY);
					add(witheredRa);
					witheredRa.animation.play('rain');

					cloudsa = new FlxSprite(-100, 10).loadGraphic(Paths.image('bgs/veryAngreRon_clouds'));
					cloudsa.updateHitbox();
					cloudsa.scale.x = 0.7;
					cloudsa.scale.y = 0.7;
					cloudsa.screenCenter();
					cloudsa.active = false;
					cloudsa.antialiasing = true;
					cloudsa.scrollFactor.set(0.2, 0.2);
					add(cloudsa);
					/*var glitchEffect = new FlxGlitchEffect(8,10,0.4,FlxGlitchDirection.HORIZONTAL);
						var glitchSprite = new FlxEffectSprite(bg, [glitchEffect]);
						add(glitchSprite); */

					var ground:FlxSprite = new FlxSprite(-537, -250).loadGraphic(Paths.image('bgs/veryAngreRon_ground'));
					ground.updateHitbox();
					ground.active = false;
					ground.antialiasing = true;
					add(ground);
				}
			case 'snow':
			{
				defaultCamZoom = 0.85;
				curStage = 'snow';
				bgLol = new FlxSprite(-100,10).loadGraphic(Paths.image('bgs/ss_sky'));
				bgLol.updateHitbox();
				bgLol.scale.x = 1;
				bgLol.scale.y = 1;
				bgLol.active = false;
				bgLol.antialiasing = true;
				bgLol.screenCenter();
				bgLol.scrollFactor.set(0.1, 0.1);
				add(bgLol);
				var graadienter:FlxSprite = new FlxSprite(-100,10).loadGraphic(Paths.image('bgs/ss_gradient'));
				graadienter.updateHitbox();
				graadienter.screenCenter();
				graadienter.active = false;
				graadienter.antialiasing = true;
				graadienter.scrollFactor.set(0.2, 0.2);
				add(graadienter);
				cloudsa = new FlxSprite(-100,10).loadGraphic(Paths.image('bgs/ss_clouds'));
				cloudsa.updateHitbox();
				cloudsa.scale.x = 0.7;
				cloudsa.scale.y = 0.7;
				cloudsa.screenCenter();
				cloudsa.active = false;
				cloudsa.antialiasing = true;
				cloudsa.scrollFactor.set(0.2, 0.2);
				add(cloudsa);
				var icicleb:FlxSprite = new FlxSprite(-100,10).loadGraphic(Paths.image('bgs/ss_iciclesbehind'));
				icicleb.updateHitbox();
				icicleb.scale.set(0.65,0.65);
				icicleb.screenCenter();
				icicleb.active = false;
				icicleb.antialiasing = true;
				icicleb.scrollFactor.set(0.3, 0.3);
				add(icicleb);
				var iciclef:FlxSprite = new FlxSprite(-100,10).loadGraphic(Paths.image('bgs/ss_iciclesnbulb'));
				iciclef.updateHitbox();
				iciclef.scale.set(0.65,0.65);
				iciclef.screenCenter();
				iciclef.active = false;
				iciclef.antialiasing = true;
				iciclef.scrollFactor.set(0.3, 0.3);
				add(iciclef);
				bgbleffect = new FlxSprite().makeGraphic(FlxG.width*3, FlxG.height*3, FlxColor.BLACK);
				bgbleffect.updateHitbox();
				bgbleffect.antialiasing = true;
				bgbleffect.screenCenter(XY);
				bgbleffect.scrollFactor.set();
				bgbleffect.alpha = 0.5;
				add(bgbleffect);
				satan = new BGSprite('bgs/ss_pentagram', 300, 20, 0.15, 0.15);
				satan.antialiasing = true;
				satan.scale.set(1.2,1.2);
				satan.screenCenter(XY);
				satan.y -= 100;
				satan.active = true;
				add(satan);	
				var diamond:FlxSprite = new FlxSprite(-100,10).loadGraphic(Paths.image('bgs/ss_diamond'));
				diamond.updateHitbox();
				diamond.screenCenter();
				diamond.active = false;
				diamond.antialiasing = true;
				diamond.scrollFactor.set(0.15, 0.15);
				diamond.y -= 160;
				add(diamond);
				var ground:FlxSprite = new FlxSprite(300,200).loadGraphic(Paths.image('bgs/ss_ground'));
				ground.antialiasing = true;
				ground.screenCenter(XY);
				ground.scrollFactor.set(0.9, 0.9);
				ground.active = false;
				add(ground);
				fx = new FlxSprite().loadGraphic(Paths.image('bgs/effect'));
				fx.setGraphicSize(Std.int(2560 * 0.75));
				fx.updateHitbox();
				fx.antialiasing = true;
				fx.screenCenter(XY);
				fx.scrollFactor.set(0, 0);
				fx.alpha = 0.3;		
				Estatic = new FlxSprite().loadGraphic(Paths.image('bgs/deadly2'));
				Estatic.scrollFactor.set();
				Estatic.screenCenter();
				Estatic.alpha = 0;
					Estatic2 = new FlxSprite();
				Estatic2.frames = Paths.getSparrowAtlas('bgs/trojan_static');
				Estatic2.scale.set(4,4);
				Estatic2.animation.addByPrefix('idle', 'static instance 1', 24, true);
				Estatic2.animation.play('idle');
				Estatic2.scrollFactor.set();
				Estatic2.screenCenter();
				Estatic2.alpha = 0;
			}
			case 'nothing':
			{
				wbg = new FlxSprite().makeGraphic(FlxG.width*3, FlxG.height*3, FlxColor.WHITE);
				wbg.updateHitbox();
				wbg.screenCenter(XY);
				wbg.scrollFactor.set();
				add(wbg);
				snowemitter = new FlxEmitter(9999, 0, 300);
				for (i in 0...150)
				{
					var p = new FlxParticle();
					var p2 = new FlxParticle();
					p.makeGraphic(12,12,FlxColor.GRAY);
					p2.makeGraphic(24,24,FlxColor.GRAY);
					
					snowemitter.add(p);
					snowemitter.add(p2);
				}
				snowemitter.width = FlxG.width*1.5;
				snowemitter.launchMode = SQUARE;
				snowemitter.velocity.set(-10, -240, 10, -320);
				snowemitter.lifespan.set(5);
				add(snowemitter);
				snowemitter.start(false, 0.05);
			}
		}

		if(isPixelStage) {
			introSoundsSuffix = '-pixel';
		}

		add(gfGroup); //Needed for blammed lights

		// Shitty layering but whatev it works LOL
		if (curStage == 'limo')
			add(limo);

		add(dadGroup);
		add(boyfriendGroup);

		switch(curStage)
		{
			case 'spooky':
				add(halloweenWhite);
			case 'tank':
				add(foregroundSprites);
		}

		#if LUA_ALLOWED
		luaDebugGroup = new FlxTypedGroup<DebugLuaText>();
		luaDebugGroup.cameras = [camOther];
		add(luaDebugGroup);
		#end

		// "GLOBAL" SCRIPTS
		#if LUA_ALLOWED
		var filesPushed:Array<String> = [];
		var foldersToCheck:Array<String> = [Paths.getPreloadPath('scripts/')];

		#if MODS_ALLOWED
		foldersToCheck.insert(0, Paths.mods('scripts/'));
		if(Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/scripts/'));

		for(mod in Paths.getGlobalMods())
			foldersToCheck.insert(0, Paths.mods(mod + '/scripts/'));
		#end

		for (folder in foldersToCheck)
		{
			if(FileSystem.exists(folder))
			{
				for (file in FileSystem.readDirectory(folder))
				{
					if(file.endsWith('.lua') && !filesPushed.contains(file))
					{
						luaArray.push(new FunkinLua(folder + file));
						filesPushed.push(file);
					}
				}
			}
		}
		#end


		// STAGE SCRIPTS
		#if (MODS_ALLOWED && LUA_ALLOWED)
		var doPush:Bool = false;
		var luaFile:String = 'stages/' + curStage + '.lua';
		if(FileSystem.exists(Paths.modFolders(luaFile))) {
			luaFile = Paths.modFolders(luaFile);
			doPush = true;
		} else {
			luaFile = Paths.getPreloadPath(luaFile);
			if(FileSystem.exists(luaFile)) {
				doPush = true;
			}
		}

		if(doPush)
			luaArray.push(new FunkinLua(luaFile));
		#end

		var gfVersion:String = SONG.gfVersion;
		if(gfVersion == null || gfVersion.length < 1)
		{
			switch (curStage)
			{
				case 'limo':
					gfVersion = 'gf-car';
				case 'mall' | 'mallEvil':
					gfVersion = 'gf-christmas';
				case 'school' | 'schoolEvil':
					gfVersion = 'gf-pixel';
				case 'tank':
					gfVersion = 'gf-tankmen';
				default:
					gfVersion = 'gf';
			}

			switch(Paths.formatToSongPath(SONG.song))
			{
				case 'stress':
					gfVersion = 'pico-speaker';
			}
			SONG.gfVersion = gfVersion; //Fix for the Chart Editor
		}

		if (!stageData.hide_girlfriend)
		{
			gf = new Character(0, 0, gfVersion);
			startCharacterPos(gf);
			gf.scrollFactor.set(0.95, 0.95);
			gfGroup.add(gf);
			startCharacterLua(gf.curCharacter);

			if(gfVersion == 'pico-speaker')
			{
				if(!ClientPrefs.lowQuality)
				{
					var firstTank:TankmenBG = new TankmenBG(20, 500, true);
					firstTank.resetShit(20, 600, true);
					firstTank.strumTime = 10;
					tankmanRun.add(firstTank);

					for (i in 0...TankmenBG.animationNotes.length)
					{
						if(FlxG.random.bool(16)) {
							var tankBih = tankmanRun.recycle(TankmenBG);
							tankBih.strumTime = TankmenBG.animationNotes[i][0];
							tankBih.resetShit(500, 200 + FlxG.random.int(50, 100), TankmenBG.animationNotes[i][1] < 2);
							tankmanRun.add(tankBih);
						}
					}
				}
			}
		}

		dad = new Character(0, 0, SONG.player2);
		startCharacterPos(dad, true);
		dadGroup.add(dad);
		startCharacterLua(dad.curCharacter);

		boyfriend = new Boyfriend(0, 0, SONG.player1);
		startCharacterPos(boyfriend);
		boyfriendGroup.add(boyfriend);
		startCharacterLua(boyfriend.curCharacter);

		var camPos:FlxPoint = new FlxPoint(girlfriendCameraOffset[0], girlfriendCameraOffset[1]);
		if(gf != null)
		{
			camPos.x += gf.getGraphicMidpoint().x + gf.cameraPosition[0];
			camPos.y += gf.getGraphicMidpoint().y + gf.cameraPosition[1];
		}

		if(dad.curCharacter.startsWith('gf')) {
			dad.setPosition(GF_X, GF_Y);
			if(gf != null)
				gf.visible = false;
		}


		switch(curStage)
		{
			case 'hell':
				var evilTrail = new FlxTrail(dad, null, 4, 24, 0.3, 0.069); //nice
				addBehindDad(evilTrail);
				if (SONG.song.toLowerCase() == 'bleeding')
					remove(evilTrail);
		}

		var file:String = Paths.json(songName + '/dialogue'); //Checks for json/Psych Engine dialogue
		if (OpenFlAssets.exists(file)) {
			dialogueJson = DialogueBoxPsych.parseDialogue(file);
		}

		var file:String = Paths.txt(songName + '/' + songName + 'Dialogue'); //Checks for vanilla/Senpai dialogue
		if (OpenFlAssets.exists(file)) {
			dialogue = CoolUtil.coolTextFile(file);
		}

		var doof:DialogueBox = new DialogueBox(false, dialogue);
		// doof.x += 70;
		// doof.y = FlxG.height * 0.5;
		doof.scrollFactor.set();
		doof.finishThing = startCountdown;
		doof.nextDialogueThing = startNextDialogue;
		doof.skipDialogueThing = skipDialogue;

		var doof2:DialogueBoxDave = new DialogueBoxDave(false, dialogue);
		doof2.scrollFactor.set();
		doof2.finishThing = startCountdown;

		Conductor.songPosition = -5000;

		strumLine = new FlxSprite(ClientPrefs.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X, 50).makeGraphic(FlxG.width, 10);
		if(ClientPrefs.downScroll) strumLine.y = FlxG.height - 150;
		strumLine.scrollFactor.set();

		var showTime:Bool = (ClientPrefs.timeBarType != 'Disabled');
		timeTxt = new FlxText(STRUM_X + (FlxG.width / 2) - 248, 19, 400, "", 32);
		timeTxt.setFormat(Paths.font("w95.otf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.alpha = 0;
		timeTxt.borderSize = 2;
		timeTxt.visible = showTime;
		if(ClientPrefs.downScroll) timeTxt.y = FlxG.height - 44;

		if(ClientPrefs.timeBarType == 'Song Name')
		{
			timeTxt.text = SONG.song;
		}
		updateTime = showTime;

		timeBarBG = new AttachedSprite('timeBar');
		timeBarBG.x = timeTxt.x;
		timeBarBG.y = timeTxt.y + (timeTxt.height / 4);
		timeBarBG.scrollFactor.set();
		timeBarBG.alpha = 0;
		timeBarBG.visible = showTime;
		timeBarBG.color = FlxColor.BLACK;
		timeBarBG.xAdd = -4;
		timeBarBG.yAdd = -4;
		add(timeBarBG);

		timeBar = new FlxBar(timeBarBG.x + 4, timeBarBG.y + 4, LEFT_TO_RIGHT, Std.int(timeBarBG.width - 8), Std.int(timeBarBG.height - 8), this,
			'songPercent', 0, 1);
		timeBar.scrollFactor.set();
		timeBar.createFilledBar(0xFF000000, 0xFFFFFFFF);
		timeBar.numDivisions = 800; //How much lag this causes?? Should i tone it down to idk, 400 or 200?
		timeBar.alpha = 0;
		timeBar.visible = showTime;
		add(timeBar);
		add(timeTxt);
		timeBarBG.sprTracker = timeBar;

		strumLineNotes = new FlxTypedGroup<StrumNote>();
		add(strumLineNotes);
		add(grpNoteSplashes);

		if(ClientPrefs.timeBarType == 'Song Name')
		{
			timeTxt.size = 24;
			timeTxt.y += 3;
		}

		var splash:NoteSplash = new NoteSplash(100, 100, 0);
		grpNoteSplashes.add(splash);
		splash.alpha = 0.0;

		opponentStrums = new FlxTypedGroup<StrumNote>();
		playerStrums = new FlxTypedGroup<StrumNote>();

		// startCountdown();

		generateSong(SONG.song);
		#if LUA_ALLOWED
		for (notetype in noteTypeMap.keys())
		{
			#if MODS_ALLOWED
			var luaToLoad:String = Paths.modFolders('custom_notetypes/' + notetype + '.lua');
			if(FileSystem.exists(luaToLoad))
			{
				luaArray.push(new FunkinLua(luaToLoad));
			}
			else
			{
				luaToLoad = Paths.getPreloadPath('custom_notetypes/' + notetype + '.lua');
				if(FileSystem.exists(luaToLoad))
				{
					luaArray.push(new FunkinLua(luaToLoad));
				}
			}
			#elseif sys
			var luaToLoad:String = Paths.getPreloadPath('custom_notetypes/' + notetype + '.lua');
			if(OpenFlAssets.exists(luaToLoad))
			{
				luaArray.push(new FunkinLua(luaToLoad));
			}
			#end
		}
		for (event in eventPushedMap.keys())
		{
			#if MODS_ALLOWED
			var luaToLoad:String = Paths.modFolders('custom_events/' + event + '.lua');
			if(FileSystem.exists(luaToLoad))
			{
				luaArray.push(new FunkinLua(luaToLoad));
			}
			else
			{
				luaToLoad = Paths.getPreloadPath('custom_events/' + event + '.lua');
				if(FileSystem.exists(luaToLoad))
				{
					luaArray.push(new FunkinLua(luaToLoad));
				}
			}
			#elseif sys
			var luaToLoad:String = Paths.getPreloadPath('custom_events/' + event + '.lua');
			if(OpenFlAssets.exists(luaToLoad))
			{
				luaArray.push(new FunkinLua(luaToLoad));
			}
			#end
		}
		#end
		noteTypeMap.clear();
		noteTypeMap = null;
		eventPushedMap.clear();
		eventPushedMap = null;

		// After all characters being loaded, it makes then invisible 0.01s later so that the player won't freeze when you change characters
		// add(strumLine);

		camFollow = new FlxPoint();
		camFollowPos = new FlxObject(0, 0, 1, 1);

		snapCamFollowToPos(camPos.x, camPos.y);
		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}
		if (prevCamFollowPos != null)
		{
			camFollowPos = prevCamFollowPos;
			prevCamFollowPos = null;
		}
		add(camFollowPos);

		FlxG.camera.follow(camFollowPos, LOCKON, 1);
		// FlxG.camera.setScrollBounds(0, FlxG.width, 0, FlxG.height);
		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.focusOn(camFollow);

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);

		FlxG.fixedTimestep = false;
		moveCameraSection(0);

		healthBarBG = new AttachedSprite('healthBar');
		healthBarBG.y = FlxG.height * 0.89;
		healthBarBG.screenCenter(X);
		healthBarBG.scrollFactor.set();
		healthBarBG.visible = !ClientPrefs.hideHud;
		healthBarBG.xAdd = -4;
		healthBarBG.yAdd = -4;
		add(healthBarBG);
		if(ClientPrefs.downScroll) healthBarBG.y = 0.11 * FlxG.height;

		healthBar = new FlxBar(healthBarBG.x + 4, healthBarBG.y + 4, RIGHT_TO_LEFT, Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8), this,
			'health', 0, 2);
		healthBar.scrollFactor.set();
		// healthBar
		healthBar.visible = !ClientPrefs.hideHud;
		healthBar.alpha = ClientPrefs.healthBarAlpha;
		add(healthBar);
		healthBarBG.sprTracker = healthBar;

		if (SONG.stage == 'daveHouse')
		{
			var songName = SONG.song;
			if (songName == 'Holy-Shit-Dave-Fnf')
				songName = 'Dave-Fnf';
			kadeEngineWatermark = new FlxText(4, healthBarBG.y
				+ 50, 0,
				songName
				+ " - "
				+ CoolUtil.difficulties[storyDifficulty]
				+ " | " + "Tristan Engine (KE 1.2)", 16);
			kadeEngineWatermark.setFormat(Paths.font("comic.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE,FlxColor.BLACK);
			kadeEngineWatermark.scrollFactor.set();
			add(kadeEngineWatermark);

			if (ClientPrefs.downScroll)
				kadeEngineWatermark.y = FlxG.height * 0.9 + 45;
		}

		iconP1 = new HealthIcon(boyfriend.healthIcon, true);
		iconP1.y = healthBar.y - 75;
		iconP1.visible = !ClientPrefs.hideHud;
		iconP1.alpha = ClientPrefs.healthBarAlpha;
		add(iconP1);

		iconP2 = new HealthIcon(dad.healthIcon, false);
		iconP2.y = healthBar.y - 75;
		iconP2.visible = !ClientPrefs.hideHud;
		iconP2.alpha = ClientPrefs.healthBarAlpha;
		add(iconP2);
		reloadHealthBarColors();

		scoreTxt = new FlxText(0, healthBarBG.y + 36, FlxG.width, "", 20);
		if (SONG.stage == 'daveHouse')
			scoreTxt.setFormat(Paths.font("comic.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE,FlxColor.BLACK);
		else
			scoreTxt.setFormat(Paths.font("w95.otf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = !ClientPrefs.hideHud;
		add(scoreTxt);

		botplayTxt = new FlxText(400, timeBarBG.y + 55, FlxG.width - 800, "BOTPLAY", 32);
		if (SONG.stage == 'daveHouse')
			botplayTxt.setFormat(Paths.font("comic.ttf"), 42, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE,FlxColor.BLACK);
		else
			botplayTxt.setFormat(Paths.font("w95.otf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = cpuControlled;
		add(botplayTxt);
		if(ClientPrefs.downScroll) {
			botplayTxt.y = timeBarBG.y - 78;
		}

		switch(SONG.player2)
		{
			case 'dave':
				gf.visible = false;
				boyfriend.y -= 120;
		}

		if (curSong == 'Withered-Tweaked')
		{
			fxtwo = new FlxSprite().loadGraphic(Paths.image('bgs/bobtwerked/effect'));
			fxtwo.scale.set(0.55, 0.55);
			fxtwo.updateHitbox();
			fxtwo.antialiasing = true;
			fxtwo.screenCenter();
			fxtwo.alpha = 0.2;
			fxtwo.scrollFactor.set(0, 0);
			add(fxtwo);
			fxtwo.cameras = [camOverlay];

			dad.x += 500;
			dad.y += 50;
		}

		strumLineNotes.cameras = [camHUD];
		grpNoteSplashes.cameras = [camHUD];
		notes.cameras = [camHUD];
		healthBar.cameras = [camHUD];
		healthBarBG.cameras = [camHUD];
		iconP1.cameras = [camHUD];
		iconP2.cameras = [camHUD];
		scoreTxt.cameras = [camHUD];
		botplayTxt.cameras = [camHUD];
		timeBar.cameras = [camHUD];
		timeBarBG.cameras = [camHUD];
		timeTxt.cameras = [camHUD];
		doof.cameras = [camHUD];
		doof2.cameras = [camHUD];
		if (curSong.toLowerCase() == 'holy-shit-dave-fnf')
			kadeEngineWatermark.cameras = [camHUD];

		// if (SONG.song == 'South')
		// FlxG.camera.alpha = 0.7;
		// UI_camera.zoom = 1;

		// cameras = [FlxG.cameras.list[1]];
		startingSong = true;

		// SONG SPECIFIC SCRIPTS
		#if LUA_ALLOWED
		var filesPushed:Array<String> = [];
		var foldersToCheck:Array<String> = [Paths.getPreloadPath('data/' + Paths.formatToSongPath(SONG.song) + '/')];

		#if MODS_ALLOWED
		foldersToCheck.insert(0, Paths.mods('data/' + Paths.formatToSongPath(SONG.song) + '/'));
		if(Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/data/' + Paths.formatToSongPath(SONG.song) + '/'));

		for(mod in Paths.getGlobalMods())
			foldersToCheck.insert(0, Paths.mods(mod + '/data/' + Paths.formatToSongPath(SONG.song) + '/' ));// using push instead of insert because these should run after everything else
		#end

		for (folder in foldersToCheck)
		{
			if(FileSystem.exists(folder))
			{
				for (file in FileSystem.readDirectory(folder))
				{
					if(file.endsWith('.lua') && !filesPushed.contains(file))
					{
						luaArray.push(new FunkinLua(folder + file));
						filesPushed.push(file);
					}
				}
			}
		}
		#end

		setChrome(0.0);
		var daSong:String = Paths.formatToSongPath(curSong);
		if (!seenCutscene)
		{
			switch (daSong)
			{
				case "ron" | 'ayo' | 'wasted' | 'bloodshed' | 'trojan-virus':
					schoolIntro(doof);
				case 'pretty-wacky':
					var graadienter:FlxSprite = new FlxSprite(-100,10).loadGraphic(Paths.image('bgs/ss_gradient'));
					graadienter.updateHitbox();
					graadienter.screenCenter();
					graadienter.active = false;
					graadienter.antialiasing = true;
					graadienter.scrollFactor.set(0.2, 0.2);
					add(graadienter);				
					startCountdown();
				case 'blizzard':
					add(fx);
					gf.visible = false;
					blackeffect = new FlxSprite().makeGraphic(FlxG.width*3, FlxG.height*3, FlxColor.BLACK);
					blackeffect.updateHitbox();
					blackeffect.antialiasing = true;
					blackeffect.screenCenter(XY);
					blackeffect.scrollFactor.set();
					blackeffect.alpha = 0.25;
					add(blackeffect);
					add(Estatic);
					FlxTween.tween(Estatic, {"scale.x":0.8,"scale.y":0.8}, 0.5, {ease: FlxEase.quadInOut, type: PINGPONG});
					snowemitter = new FlxEmitter(9999, 0, 300);
					for (i in 0...150)
					{
						var p = new FlxParticle();
						var p2 = new FlxParticle();

						p.loadGraphic(Paths.image('bgs/smallSnow'));
						p2.loadGraphic(Paths.image('bgs/bigSnow'));

						snowemitter.add(p);
						snowemitter.add(p2);
					}
					snowemitter.width = FlxG.width*1.5;
					snowemitter.launchMode = SQUARE;
					snowemitter.velocity.set(-120, 240, -200, 320);
					snowemitter.lifespan.set(5);
					add(snowemitter);
					snowemitter.start(false, 0.05);
					startCountdown();
				default:
					startCountdown();
			}
			seenCutscene = false;
		}
		else if (WeekData.weeksList[storyWeek] == 'freeplayshit')
		{
			switch (daSong)
			{
				case 'holy-shit-dave-fnf':
					schoolIntro2(doof2, false);
				case 'bleeding':
					schoolIntro(doof);
				default:
					startCountdown();
			}
			seenCutscene = true;
		} else
			startCountdown();

		if (daSong == 'bloodshed' || daSong == 'bleeding')
		{
			add(fx);
			add(Estatic);
			FlxTween.tween(Estatic, {"scale.x":0.8,"scale.y":0.8}, 0.5, {ease: FlxEase.quadInOut, type: PINGPONG});
			setChrome(ClientPrefs.rgbintense/350); // add chrome option later // HI PAST ME I ADDED GGOLE CHROME OPTION
		}

		RecalculateRating();

		//PRECACHING MISS SOUNDS BECAUSE I THINK THEY CAN LAG PEOPLE AND FUCK THEM UP IDK HOW HAXE WORKS
		if(ClientPrefs.hitsoundVolume > 0) precacheList.set('hitsound', 'sound');
		precacheList.set('missnote1', 'sound');
		precacheList.set('missnote2', 'sound');
		precacheList.set('missnote3', 'sound');

		if (PauseSubState.songName != null) {
			precacheList.set(PauseSubState.songName, 'music');
		} else if(ClientPrefs.pauseMusic != 'None') {
			precacheList.set(Paths.formatToSongPath(ClientPrefs.pauseMusic), 'music');
		}

		#if desktop
		// Updating Discord Rich Presence.
		DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		#end

		if(!ClientPrefs.controllerMode)
		{
			FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}

		Conductor.safeZoneOffset = (ClientPrefs.safeFrames / 60) * 1000;

		for (i in 0...unspawnNotes.length - 1)
		{
			if (!unspawnNotes[i].mustPress)
			{
				var skin = 'ronsip';
				switch (dad.curCharacter)
				{
					case 'douyhe':
						skin = 'NOTE_assets';
					case 'hellron':
						skin = 'ronhell';
					case 'hacker':
						skin = 'ronhell';
					case 'ateloron':
						skin = 'ronhell';
					case 'ron-usb':
						skin = 'ronhell';
					case 'demonron':
						skin = 'demonsip';
					case 'ronb':
						skin = 'evik';
					case 'ronmad-b':
						skin = 'evik';
					case 'ronangry-b':
						skin = 'evik';
					case 'godron':
						skin = 'bhell';
					case 'ateloron-b':
						skin = 'bhell';
					case 'ron-usb-b':
						skin = 'bhell';
					case 'dave':
						skin = 'NOTEold_assets';
				}

				unspawnNotes[i].texture = skin;
			} else if (SONG.player1 == 'ronDave')
				unspawnNotes[i].texture = 'ronsip';
		}

		callOnLuas('onCreatePost', []);

		super.create();

		Paths.clearUnusedMemory();

		for (key => type in precacheList)
		{
			//trace('Key $key is type $type');
			switch(type)
			{
				case 'image':
					Paths.image(key);
				case 'sound':
					Paths.sound(key);
				case 'music':
					Paths.music(key);
			}
		}
		CustomFadeTransition.nextCamera = camOther;
	}

	function set_songSpeed(value:Float):Float
	{
		if(generatedMusic)
		{
			var ratio:Float = value / songSpeed; //funny word huh
			for (note in notes) note.resizeByRatio(ratio);
			for (note in unspawnNotes) note.resizeByRatio(ratio);
		}
		songSpeed = value;
		noteKillOffset = 350 / songSpeed;
		return value;
	}

	public function addTextToDebug(text:String, color:FlxColor) {
		#if LUA_ALLOWED
		luaDebugGroup.forEachAlive(function(spr:DebugLuaText) {
			spr.y += 20;
		});

		if(luaDebugGroup.members.length > 34) {
			var blah = luaDebugGroup.members[34];
			blah.destroy();
			luaDebugGroup.remove(blah);
		}
		luaDebugGroup.insert(0, new DebugLuaText(text, luaDebugGroup, color));
		#end
	}

	public function reloadHealthBarColors() {
		healthBar.createFilledBar(FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]),
			FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2]));

		healthBar.updateBar();
	}

	public function addCharacterToList(newCharacter:String, type:Int) {
		switch(type) {
			case 0:
				if(!boyfriendMap.exists(newCharacter)) {
					var newBoyfriend:Boyfriend = new Boyfriend(0, 0, newCharacter);
					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);
					startCharacterPos(newBoyfriend);
					newBoyfriend.alpha = 0.00001;
					startCharacterLua(newBoyfriend.curCharacter);
				}

			case 1:
				if(!dadMap.exists(newCharacter)) {
					var newDad:Character = new Character(0, 0, newCharacter);
					dadMap.set(newCharacter, newDad);
					dadGroup.add(newDad);
					startCharacterPos(newDad, true);
					newDad.alpha = 0.00001;
					startCharacterLua(newDad.curCharacter);
				}

			case 2:
				if(gf != null && !gfMap.exists(newCharacter)) {
					var newGf:Character = new Character(0, 0, newCharacter);
					newGf.scrollFactor.set(0.95, 0.95);
					gfMap.set(newCharacter, newGf);
					gfGroup.add(newGf);
					startCharacterPos(newGf);
					newGf.alpha = 0.00001;
					startCharacterLua(newGf.curCharacter);
				}
		}
	}

	function startCharacterLua(name:String)
	{
		#if LUA_ALLOWED
		var doPush:Bool = false;
		var luaFile:String = 'characters/' + name + '.lua';
		#if MODS_ALLOWED
		if(FileSystem.exists(Paths.modFolders(luaFile))) {
			luaFile = Paths.modFolders(luaFile);
			doPush = true;
		} else {
			luaFile = Paths.getPreloadPath(luaFile);
			if(FileSystem.exists(luaFile)) {
				doPush = true;
			}
		}
		#else
		luaFile = Paths.getPreloadPath(luaFile);
		if(Assets.exists(luaFile)) {
			doPush = true;
		}
		#end

		if(doPush)
		{
			for (lua in luaArray)
			{
				if(lua.scriptName == luaFile) return;
			}
			luaArray.push(new FunkinLua(luaFile));
		}
		#end
	}

	public function getLuaObject(tag:String, text:Bool=true):FlxSprite {
		if(modchartObjects.exists(tag))return modchartObjects.get(tag);
		if(modchartSprites.exists(tag))return modchartSprites.get(tag);
		if(text && modchartTexts.exists(tag))return modchartTexts.get(tag);
		return null;
	}

	function startCharacterPos(char:Character, ?gfCheck:Bool = false) {
		if(gfCheck && char.curCharacter.startsWith('gf')) { //IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
			char.setPosition(GF_X, GF_Y);
			char.scrollFactor.set(0.95, 0.95);
			char.danceEveryNumBeats = 2;
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	public function startVideo(name:String):Void {
		#if VIDEOS_ALLOWED
		var foundFile:Bool = false;
		var fileName:String = #if MODS_ALLOWED Paths.modFolders('videos/' + name + '.' + Paths.VIDEO_EXT); #else ''; #end
		#if sys
		if(FileSystem.exists(fileName)) {
			foundFile = true;
		}
		#end

		if(!foundFile) {
			fileName = Paths.video(name);
			#if sys
			if(FileSystem.exists(fileName)) {
			#else
			if(OpenFlAssets.exists(fileName)) {
			#end
				foundFile = true;
			}
		}

		if(foundFile) {
			inCutscene = true;
			var bg = new FlxSprite(-FlxG.width, -FlxG.height).makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
			bg.scrollFactor.set();
			bg.cameras = [camHUD];
			add(bg);

			(new FlxVideo(fileName)).finishCallback = function() {
				remove(bg);
				startAndEnd();
			}
			return;
		}
		else
		{
			FlxG.log.warn('Couldnt find video file: ' + fileName);
			startAndEnd();
		}
		#end
		startAndEnd();
	}

	function startAndEnd()
	{
		if(endingSong)
			endSong();
		else
			startCountdown();
	}

	var dialogueCount:Int = 0;
	public var psychDialogue:DialogueBoxPsych;
	//You don't have to add a song, just saying. You can just do "startDialogue(dialogueJson);" and it should work
	public function startDialogue(dialogueFile:DialogueFile, ?song:String = null):Void
	{
		// TO DO: Make this more flexible, maybe?
		if(psychDialogue != null) return;

		if(dialogueFile.dialogue.length > 0) {
			inCutscene = true;
			precacheList.set('dialogue', 'sound');
			precacheList.set('dialogueClose', 'sound');
			psychDialogue = new DialogueBoxPsych(dialogueFile, song);
			psychDialogue.scrollFactor.set();
			if(endingSong) {
				psychDialogue.finishThing = function() {
					psychDialogue = null;
					endSong();
				}
			} else {
				psychDialogue.finishThing = function() {
					psychDialogue = null;
					startCountdown();
				}
			}
			psychDialogue.nextDialogueThing = startNextDialogue;
			psychDialogue.skipDialogueThing = skipDialogue;
			psychDialogue.cameras = [camHUD];
			add(psychDialogue);
		} else {
			FlxG.log.warn('Your dialogue file is badly formatted!');
			if(endingSong) {
				endSong();
			} else {
				startCountdown();
			}
		}
	}

	function schoolIntro(?dialogueBox:DialogueBox):Void
	{
		var black:FlxSprite = new FlxSprite(-100, -100).makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.BLACK);
		black.scrollFactor.set();
		add(black);

		var red:FlxSprite = new FlxSprite(-100, -100).makeGraphic(FlxG.width * 2, FlxG.height * 2, 0xFFff1b31);
		red.scrollFactor.set();

		remove(black);

		new FlxTimer().start(0.3, function(tmr:FlxTimer)
		{
			// too slow
			{
				if (dialogueBox != null)
				{
					inCutscene = true;
					add(dialogueBox);
				}
				else
					startCountdown();

				remove(black);
			}
		});
	}

	function schoolIntro2(?dialogueBox2:DialogueBoxDave, ?isStart:Bool = true):Void
	{
		camFollowPos.setPosition(boyfriend.getGraphicMidpoint().x - 200, dad.getGraphicMidpoint().y - 10);
		var black:FlxSprite = new FlxSprite(-100, -100).makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.BLACK);
		black.scrollFactor.set();
		add(black);

		var stupidBasics:Float = 1;
		if (isStart)
			FlxTween.tween(black, {alpha: 0}, stupidBasics);
		else
		{
			black.alpha = 0;
			stupidBasics = 0;
		}
		new FlxTimer().start(stupidBasics, function(fuckingSussy:FlxTimer)
		{
			if (dialogueBox2 != null)
			{
				add(dialogueBox2);
			}
			else
			{
				startCountdown();
			}
		});
	}

	function tankIntro()
	{
		var songName:String = Paths.formatToSongPath(SONG.song);
		dadGroup.alpha = 0.00001;
		camHUD.visible = false;
		//inCutscene = true; //this would stop the camera movement, oops

		var tankman:FlxSprite = new FlxSprite(-20, 320);
		tankman.frames = Paths.getSparrowAtlas('cutscenes/' + songName);
		tankman.antialiasing = ClientPrefs.globalAntialiasing;
		addBehindDad(tankman);

		var gfDance:FlxSprite = new FlxSprite(gf.x - 107, gf.y + 140);
		gfDance.antialiasing = ClientPrefs.globalAntialiasing;
		var gfCutscene:FlxSprite = new FlxSprite(gf.x - 104, gf.y + 122);
		gfCutscene.antialiasing = ClientPrefs.globalAntialiasing;
		var picoCutscene:FlxSprite = new FlxSprite(gf.x - 849, gf.y - 264);
		picoCutscene.antialiasing = ClientPrefs.globalAntialiasing;
		var boyfriendCutscene:FlxSprite = new FlxSprite(boyfriend.x + 5, boyfriend.y + 20);
		boyfriendCutscene.antialiasing = ClientPrefs.globalAntialiasing;

		var tankmanEnd:Void->Void = function()
		{
			var timeForStuff:Float = Conductor.crochet / 1000 * 5;
			FlxG.sound.music.fadeOut(timeForStuff);
			FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, timeForStuff, {ease: FlxEase.quadInOut});
			moveCamera(true);
			startCountdown();

			dadGroup.alpha = 1;
			camHUD.visible = true;

			var stuff:Array<FlxSprite> = [tankman, gfDance, gfCutscene, picoCutscene, boyfriendCutscene];
			for (char in stuff)
			{
				char.kill();
				remove(char);
				char.destroy();
			}
			Paths.clearUnusedMemory();
		};

		camFollow.set(dad.x + 280, dad.y + 170);
	}

	var startTimer:FlxTimer;
	var finishTimer:FlxTimer = null;

	// For being able to mess with the sprites on Lua
	public var countdownReady:FlxSprite;
	public var countdownSet:FlxSprite;
	public var countdownGo:FlxSprite;
	public static var startOnTime:Float = 0;

	public function startCountdown():Void
	{
		if(startedCountdown) {
			callOnLuas('onStartCountdown', []);
			return;
		}

		inCutscene = false;
		var ret:Dynamic = callOnLuas('onStartCountdown', []);
		if(ret != FunkinLua.Function_Stop) {
			if (skipCountdown || startOnTime > 0) skipArrowStartTween = true;

			generateStaticArrows(0);
			generateStaticArrows(1);
			for (i in 0...playerStrums.length) {
				setOnLuas('defaultPlayerStrumX' + i, playerStrums.members[i].x);
				setOnLuas('defaultPlayerStrumY' + i, playerStrums.members[i].y);
			}
			for (i in 0...opponentStrums.length) {
				setOnLuas('defaultOpponentStrumX' + i, opponentStrums.members[i].x);
				setOnLuas('defaultOpponentStrumY' + i, opponentStrums.members[i].y);
				//if(ClientPrefs.middleScroll) opponentStrums.members[i].visible = false;
			}

			startedCountdown = true;
			Conductor.songPosition = 0;
			Conductor.songPosition -= Conductor.crochet * 5;
			setOnLuas('startedCountdown', true);
			callOnLuas('onCountdownStarted', []);

			var swagCounter:Int = 0;


			if(startOnTime < 0) startOnTime = 0;

			if (startOnTime > 0) {
				clearNotesBefore(startOnTime);
				setSongTime(startOnTime - 350);
				return;
			}
			else if (skipCountdown)
			{
				setSongTime(0);
				return;
			}

			startTimer = new FlxTimer().start(Conductor.crochet / 1000, function(tmr:FlxTimer)
			{
				if (gf != null && tmr.loopsLeft % Math.round(gfSpeed * gf.danceEveryNumBeats) == 0 && gf.animation.curAnim != null && !gf.animation.curAnim.name.startsWith("sing") && !gf.stunned)
				{
					gf.dance();
				}
				if (tmr.loopsLeft % boyfriend.danceEveryNumBeats == 0 && boyfriend.animation.curAnim != null && !boyfriend.animation.curAnim.name.startsWith('sing') && !boyfriend.stunned)
				{
					boyfriend.dance();
				}
				if (tmr.loopsLeft % dad.danceEveryNumBeats == 0 && dad.animation.curAnim != null && !dad.animation.curAnim.name.startsWith('sing') && !dad.stunned)
				{
					dad.dance();
				}

				var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
				introAssets.set('default', ['ready', 'set', 'go']);
				introAssets.set('pixel', ['pixelUI/ready-pixel', 'pixelUI/set-pixel', 'pixelUI/date-pixel']);

				var introAlts:Array<String> = introAssets.get('default');
				var antialias:Bool = ClientPrefs.globalAntialiasing;
				if(isPixelStage) {
					introAlts = introAssets.get('pixel');
					antialias = false;
				}

				// head bopping for bg characters on Mall
				if(curStage == 'mall') {
					if(!ClientPrefs.lowQuality)
						upperBoppers.dance(true);

					bottomBoppers.dance(true);
					santa.dance(true);
				}

				switch (swagCounter)
				{
					case 0:
						FlxG.sound.play(Paths.sound('intro3' + introSoundsSuffix), 0.6);
					case 1:
						countdownReady = new FlxSprite().loadGraphic(Paths.image(introAlts[0]));
						countdownReady.scrollFactor.set();
						countdownReady.updateHitbox();

						if (PlayState.isPixelStage)
							countdownReady.setGraphicSize(Std.int(countdownReady.width * daPixelZoom));

						countdownReady.screenCenter();
						countdownReady.antialiasing = antialias;
						add(countdownReady);
						FlxTween.tween(countdownReady, {/*y: countdownReady.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
							ease: FlxEase.cubeInOut,
							onComplete: function(twn:FlxTween)
							{
								remove(countdownReady);
								countdownReady.destroy();
							}
						});
						FlxG.sound.play(Paths.sound('intro2' + introSoundsSuffix), 0.6);
					case 2:
						countdownSet = new FlxSprite().loadGraphic(Paths.image(introAlts[1]));
						countdownSet.scrollFactor.set();

						if (PlayState.isPixelStage)
							countdownSet.setGraphicSize(Std.int(countdownSet.width * daPixelZoom));

						countdownSet.screenCenter();
						countdownSet.antialiasing = antialias;
						add(countdownSet);
						FlxTween.tween(countdownSet, {/*y: countdownSet.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
							ease: FlxEase.cubeInOut,
							onComplete: function(twn:FlxTween)
							{
								remove(countdownSet);
								countdownSet.destroy();
							}
						});
						FlxG.sound.play(Paths.sound('intro1' + introSoundsSuffix), 0.6);
					case 3:
						countdownGo = new FlxSprite().loadGraphic(Paths.image(introAlts[2]));
						countdownGo.scrollFactor.set();

						if (PlayState.isPixelStage)
							countdownGo.setGraphicSize(Std.int(countdownGo.width * daPixelZoom));

						countdownGo.updateHitbox();

						countdownGo.screenCenter();
						countdownGo.antialiasing = antialias;
						add(countdownGo);
						FlxTween.tween(countdownGo, {/*y: countdownGo.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
							ease: FlxEase.cubeInOut,
							onComplete: function(twn:FlxTween)
							{
								remove(countdownGo);
								countdownGo.destroy();
							}
						});
						FlxG.sound.play(Paths.sound('introGo' + introSoundsSuffix), 0.6);
					case 4:
				}

				if(ClientPrefs.opponentStrums)
				{
					notes.forEachAlive(function(note:Note) {
						note.copyAlpha = false;
						note.alpha = note.multAlpha;
						if(ClientPrefs.middleScroll && !note.mustPress) {
							note.alpha *= 0.35;
						}
					});
				}
				callOnLuas('onCountdownTick', [swagCounter]);

				swagCounter += 1;
				// generateSong('fresh');
			}, 5);
		}
	}

	public function addBehindGF(obj:FlxObject)
	{
		insert(members.indexOf(gfGroup), obj);
	}
	public function addBehindBF(obj:FlxObject)
	{
		insert(members.indexOf(boyfriendGroup), obj);
	}
	public function addBehindDad (obj:FlxObject)
	{
		insert(members.indexOf(dadGroup), obj);
	}

	public function clearNotesBefore(time:Float)
	{
		var i:Int = unspawnNotes.length - 1;
		while (i >= 0) {
			var daNote:Note = unspawnNotes[i];
			if(daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				if(modchartObjects.exists('note${daNote.ID}'))modchartObjects.remove('note${daNote.ID}');
				daNote.kill();
				unspawnNotes.remove(daNote);
				daNote.destroy();
			}
			--i;
		}

		i = notes.length - 1;
		while (i >= 0) {
			var daNote:Note = notes.members[i];
			if(daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				if(modchartObjects.exists('note${daNote.ID}'))modchartObjects.remove('note${daNote.ID}');
				daNote.kill();
				notes.remove(daNote, true);
				daNote.destroy();
			}
			--i;
		}
	}

	public function setSongTime(time:Float)
	{
		if(time < 0) time = 0;

		FlxG.sound.music.pause();
		vocals.pause();

		FlxG.sound.music.time = time;
		FlxG.sound.music.play();

		vocals.time = time;
		vocals.play();
		Conductor.songPosition = time;
		songTime = time;
	}

	function startNextDialogue() {
		dialogueCount++;
		callOnLuas('onNextDialogue', [dialogueCount]);
	}

	function skipDialogue() {
		callOnLuas('onSkipDialogue', [dialogueCount]);
	}

	var previousFrameTime:Int = 0;
	var lastReportedPlayheadPosition:Int = 0;
	var songTime:Float = 0;

	function startSong():Void
	{
		startingSong = false;

		previousFrameTime = FlxG.game.ticks;
		lastReportedPlayheadPosition = 0;

		FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 1, false);
		FlxG.sound.music.onComplete = onSongComplete;
		vocals.play();

		if(startOnTime > 0)
		{
			setSongTime(startOnTime - 500);
		}
		startOnTime = 0;

		if(paused) {
			//trace('Oopsie doopsie! Paused sound');
			FlxG.sound.music.pause();
			vocals.pause();
		}

		// Song duration in a float, useful for the time left feature
		songLength = FlxG.sound.music.length;
		FlxTween.tween(timeBar, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
		FlxTween.tween(timeTxt, {alpha: 1}, 0.5, {ease: FlxEase.circOut});

		switch(curStage)
		{
			case 'tank':
				if(!ClientPrefs.lowQuality) tankWatchtower.dance();
				foregroundSprites.forEach(function(spr:BGSprite)
				{
					spr.dance();
				});
		}

		#if desktop
		// Updating Discord Rich Presence (with Time Left)
		DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength);
		#end
		setOnLuas('songLength', songLength);
		callOnLuas('onSongStart', []);
		
		//better credits system
		if (FileSystem.exists(Paths.txt(songLowercase  + "/credits")))
		{
			var creditsText:String = Assets.getText(Paths.txt(songLowercase  + "/credits"));
			var credits:FlxText = new FlxText(0, 0, 0, creditsText, 32);
			var creditsblack:FlxSprite = new FlxSprite().makeGraphic(300, FlxG.height*3, FlxColor.BLACK);
			
			credits.setFormat(Paths.font("w95.otf"), 36, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE,FlxColor.BLACK); 
			credits.scrollFactor.set();
			credits.screenCenter();
			credits.y = FlxG.camera.scroll.y+FlxG.height+40;
			
			creditsblack.scrollFactor.set();
			creditsblack.alpha = 0;
			creditsblack.screenCenter();
			
			add(creditsblack);
			add(credits);
			creditsblack.cameras = [camHUD];
			credits.cameras = [camHUD];
			
			FlxTween.tween(creditsblack, {alpha: 0.5}, 0.5});
			FlxTween.tween(credits, {y: FlxG.camera.scroll.y+FlxG.height/2}, 0.5});
			
			new FlxTimer().start(5, function(tmr:FlxTimer)
			{
				FlxTween.tween(credits, {alpha: 0}, 3, {
					onComplete: function(tween:FlxTween)
					{
						credits.destroy();
					}
				});		
				FlxTween.tween(creditsblack, {alpha: 0}, 3, {
					onComplete: function(tween:FlxTween)
					{
						creditsblack.destroy();
					}
				});						
			});
		}
	}

	var debugNum:Int = 0;
	private var noteTypeMap:Map<String, Bool> = new Map<String, Bool>();
	private var eventPushedMap:Map<String, Bool> = new Map<String, Bool>();
	private function generateSong(dataPath:String):Void
	{
		// FlxG.log.add(ChartParser.parse());
		songSpeedType = ClientPrefs.getGameplaySetting('scrolltype','multiplicative');

		switch(songSpeedType)
		{
			case "multiplicative":
				songSpeed = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1);
			case "constant":
				songSpeed = ClientPrefs.getGameplaySetting('scrollspeed', 1);
		}

		var songData = SONG;
		Conductor.changeBPM(songData.bpm);

		curSong = songData.song;

		if (SONG.needsVoices)
			vocals = new FlxSound().loadEmbedded(Paths.voices(PlayState.SONG.song));
		else
			vocals = new FlxSound();

		FlxG.sound.list.add(vocals);
		FlxG.sound.list.add(new FlxSound().loadEmbedded(Paths.inst(PlayState.SONG.song)));

		notes = new FlxTypedGroup<Note>();
		add(notes);

		var noteData:Array<SwagSection>;

		// NEW SHIT
		noteData = songData.notes;

		var playerCounter:Int = 0;

		var daBeats:Int = 0; // Not exactly representative of 'daBeats' lol, just how much it has looped

		var songName:String = Paths.formatToSongPath(SONG.song);
		var file:String = Paths.json(songName + '/events');
		#if MODS_ALLOWED
		if (FileSystem.exists(Paths.modsJson(songName + '/events')) || FileSystem.exists(file)) {
		#else
		if (OpenFlAssets.exists(file)) {
		#end
			var eventsData:Array<Dynamic> = Song.loadFromJson('events', songName).events;
			for (event in eventsData) //Event Notes
			{
				for (i in 0...event[1].length)
				{
					var newEventNote:Array<Dynamic> = [event[0], event[1][i][0], event[1][i][1], event[1][i][2]];
					var subEvent:EventNote = {
						strumTime: newEventNote[0] + ClientPrefs.noteOffset,
						event: newEventNote[1],
						value1: newEventNote[2],
						value2: newEventNote[3]
					};
					subEvent.strumTime -= eventNoteEarlyTrigger(subEvent);
					eventNotes.push(subEvent);
					eventPushed(subEvent);
				}
			}
		}

		for (section in noteData)
		{
			for (songNotes in section.sectionNotes)
			{
				var daStrumTime:Float = songNotes[0];
				var daNoteData:Int = Std.int(songNotes[1] % 4);

				var gottaHitNote:Bool = section.mustHitSection;

				var skin = 'NOTE_assets';

				if (songNotes[1] > 3)
				{
					gottaHitNote = !section.mustHitSection;
				}

				var oldNote:Note;
				if (unspawnNotes.length > 0)
					oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];
				else
					oldNote = null;
				
				var swagNote:Note = new Note(daStrumTime, daNoteData, oldNote);
				swagNote.mustPress = gottaHitNote;
				swagNote.sustainLength = songNotes[2];
				swagNote.gfNote = (section.gfSection && (songNotes[1]<4));
				swagNote.noteType = songNotes[3];
				if(!Std.isOfType(songNotes[3], String)) swagNote.noteType = editors.ChartingState.noteTypeList[songNotes[3]]; //Backward compatibility + compatibility with Week 7 charts

				swagNote.scrollFactor.set();

				var susLength:Float = swagNote.sustainLength;

				susLength = susLength / Conductor.stepCrochet;
				swagNote.ID = unspawnNotes.length;
				modchartObjects.set('note${swagNote.ID}', swagNote);
				unspawnNotes.push(swagNote);

				var floorSus:Int = Math.floor(susLength);
				if(floorSus > 0) {
					for (susNote in 0...floorSus+1)
					{
						oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];

						var sustainNote:Note = new Note(daStrumTime + (Conductor.stepCrochet * susNote) + (Conductor.stepCrochet / FlxMath.roundDecimal(songSpeed, 2)), daNoteData, oldNote, true);
						sustainNote.mustPress = gottaHitNote;
						sustainNote.gfNote = (section.gfSection && (songNotes[1]<4));
						sustainNote.noteType = swagNote.noteType;
						sustainNote.ID = unspawnNotes.length;
						modchartObjects.set('note${sustainNote.ID}', sustainNote);
						sustainNote.scrollFactor.set();
						swagNote.tail.push(sustainNote);
						sustainNote.parent = swagNote;
						unspawnNotes.push(sustainNote);

						if (sustainNote.mustPress)
						{
							sustainNote.x += FlxG.width / 2; // general offset
						}
						else if(ClientPrefs.middleScroll)
						{
							sustainNote.x += 310;
							if(daNoteData > 1) //Up and Right
							{
								sustainNote.x += FlxG.width / 2 + 25;
							}
						}
					}
				}

				if (swagNote.mustPress)
				{
					swagNote.x += FlxG.width / 2; // general offset
				}
				else if(ClientPrefs.middleScroll)
				{
					swagNote.x += 310;
					if(daNoteData > 1) //Up and Right
					{
						swagNote.x += FlxG.width / 2 + 25;
					}
				}

				if(!noteTypeMap.exists(swagNote.noteType)) {
					noteTypeMap.set(swagNote.noteType, true);
				}
			}
			daBeats += 1;
		}
		for (event in songData.events) //Event Notes
		{
			for (i in 0...event[1].length)
			{
				var newEventNote:Array<Dynamic> = [event[0], event[1][i][0], event[1][i][1], event[1][i][2]];
				var subEvent:EventNote = {
					strumTime: newEventNote[0] + ClientPrefs.noteOffset,
					event: newEventNote[1],
					value1: newEventNote[2],
					value2: newEventNote[3]
				};
				subEvent.strumTime -= eventNoteEarlyTrigger(subEvent);
				eventNotes.push(subEvent);
				eventPushed(subEvent);
			}
		}

		// trace(unspawnNotes.length);
		// playerCounter += 1;

		unspawnNotes.sort(sortByShit);
		if(eventNotes.length > 1) { //No need to sort if there's a single one or none at all
			eventNotes.sort(sortByTime);
		}
		checkEventNote();
		generatedMusic = true;
	}

	function eventPushed(event:EventNote) {
		switch(event.event) {
			case 'Change Character':
				var charType:Int = 0;
				switch(event.value1.toLowerCase()) {
					case 'gf' | 'girlfriend' | '1':
						charType = 2;
					case 'dad' | 'opponent' | '0':
						charType = 1;
					default:
						charType = Std.parseInt(event.value1);
						if(Math.isNaN(charType)) charType = 0;
				}

				var newCharacter:String = event.value2;
				addCharacterToList(newCharacter, charType);

			case 'Dadbattle Spotlight':
				dadbattleBlack = new BGSprite(null, -800, -400, 0, 0);
				dadbattleBlack.makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
				dadbattleBlack.alpha = 0.25;
				dadbattleBlack.visible = false;
				add(dadbattleBlack);

				dadbattleLight = new BGSprite('spotlight', 400, -400);
				dadbattleLight.alpha = 0.375;
				dadbattleLight.blend = ADD;
				dadbattleLight.visible = false;

				dadbattleSmokes = new FlxSpriteGroup();
				dadbattleSmokes.alpha = 0.7;
				dadbattleSmokes.blend = ADD;
				dadbattleSmokes.visible = false;
				add(dadbattleLight);
				add(dadbattleSmokes);

				var offsetX = 200;
				var smoke:BGSprite = new BGSprite('smoke', -1550 + offsetX, 660 + FlxG.random.float(-20, 20), 1.2, 1.05);
				smoke.setGraphicSize(Std.int(smoke.width * FlxG.random.float(1.1, 1.22)));
				smoke.updateHitbox();
				smoke.velocity.x = FlxG.random.float(15, 22);
				smoke.active = true;
				dadbattleSmokes.add(smoke);
				var smoke:BGSprite = new BGSprite('smoke', 1550 + offsetX, 660 + FlxG.random.float(-20, 20), 1.2, 1.05);
				smoke.setGraphicSize(Std.int(smoke.width * FlxG.random.float(1.1, 1.22)));
				smoke.updateHitbox();
				smoke.velocity.x = FlxG.random.float(-15, -22);
				smoke.active = true;
				smoke.flipX = true;
				dadbattleSmokes.add(smoke);


			case 'Philly Glow':
				blammedLightsBlack = new FlxSprite(FlxG.width * -0.5, FlxG.height * -0.5).makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
				blammedLightsBlack.visible = false;
				insert(members.indexOf(phillyStreet), blammedLightsBlack);

				phillyWindowEvent = new BGSprite('philly/window', phillyWindow.x, phillyWindow.y, 0.3, 0.3);
				phillyWindowEvent.setGraphicSize(Std.int(phillyWindowEvent.width * 0.85));
				phillyWindowEvent.updateHitbox();
				phillyWindowEvent.visible = false;
				insert(members.indexOf(blammedLightsBlack) + 1, phillyWindowEvent);


				phillyGlowGradient = new PhillyGlow.PhillyGlowGradient(-400, 225); //This shit was refusing to properly load FlxGradient so fuck it
				phillyGlowGradient.visible = false;
				insert(members.indexOf(blammedLightsBlack) + 1, phillyGlowGradient);

				precacheList.set('philly/particle', 'image'); //precache particle image
				phillyGlowParticles = new FlxTypedGroup<PhillyGlow.PhillyGlowParticle>();
				phillyGlowParticles.visible = false;
				insert(members.indexOf(phillyGlowGradient) + 1, phillyGlowParticles);
		}

		if(!eventPushedMap.exists(event.event)) {
			eventPushedMap.set(event.event, true);
		}
	}

	function eventNoteEarlyTrigger(event:EventNote):Float {
		var returnedValue:Float = callOnLuas('eventEarlyTrigger', [event.event]);
		if(returnedValue != 0) {
			return returnedValue;
		}

		switch(event.event) {
			case 'Kill Henchmen': //Better timing so that the kill sound matches the beat intended
				return 280; //Plays 280ms before the actual position
		}
		return 0;
	}

	function sortByShit(Obj1:Note, Obj2:Note):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	function sortByTime(Obj1:EventNote, Obj2:EventNote):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	public var skipArrowStartTween:Bool = false; //for lua
	private function generateStaticArrows(player:Int):Void
	{
		for (i in 0...4)
		{
			// FlxG.log.add(i);
			var targetAlpha:Float = 1;
			if (player < 1)
			{
				if(!ClientPrefs.opponentStrums) targetAlpha = 0;
				else if(ClientPrefs.middleScroll) targetAlpha = 0.35;
			}

			var babyArrow:StrumNote = new StrumNote(ClientPrefs.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X, strumLine.y, i, player, dad.curCharacter);
			babyArrow.downScroll = ClientPrefs.downScroll;
			if (!isStoryMode && !skipArrowStartTween)
			{
				//babyArrow.y -= 10;
				babyArrow.alpha = 0;
				FlxTween.tween(babyArrow, {/*y: babyArrow.y + 10,*/ alpha: targetAlpha}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
			}
			else
			{
				babyArrow.alpha = targetAlpha;
			}

			if (player == 1)
			{
				modchartObjects.set("playerStrum" + i, babyArrow);
				playerStrums.add(babyArrow);
			}
			else
			{
				modchartObjects.set("opponentStrum" + i, babyArrow);
				if(ClientPrefs.middleScroll)
				{
					babyArrow.x += 310;
					if(i > 1) { //Up and Right
						babyArrow.x += FlxG.width / 2 + 25;
					}
				}
				opponentStrums.add(babyArrow);
			}

			strumLineNotes.add(babyArrow);
			babyArrow.postAddedToGroup();
		}
	}

	override function openSubState(SubState:FlxSubState)
	{
		if (paused)
		{
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.pause();
				vocals.pause();
			}

			if (startTimer != null && !startTimer.finished)
				startTimer.active = false;
			if (finishTimer != null && !finishTimer.finished)
				finishTimer.active = false;
			if (songSpeedTween != null)
				songSpeedTween.active = false;

			if(carTimer != null) carTimer.active = false;

			var chars:Array<Character> = [boyfriend, gf, dad];
			for (char in chars) {
				if(char != null && char.colorTween != null) {
					char.colorTween.active = false;
				}
			}

			for (tween in modchartTweens) {
				tween.active = false;
			}
			for (timer in modchartTimers) {
				timer.active = false;
			}
		}

		super.openSubState(SubState);
	}

	override function closeSubState()
	{
		if (paused)
		{
			if (FlxG.sound.music != null && !startingSong)
			{
				resyncVocals();
			}

			if (startTimer != null && !startTimer.finished)
				startTimer.active = true;
			if (finishTimer != null && !finishTimer.finished)
				finishTimer.active = true;
			if (songSpeedTween != null)
				songSpeedTween.active = true;

			if(carTimer != null) carTimer.active = true;

			var chars:Array<Character> = [boyfriend, gf, dad];
			for (char in chars) {
				if(char != null && char.colorTween != null) {
					char.colorTween.active = true;
				}
			}

			for (tween in modchartTweens) {
				tween.active = true;
			}
			for (timer in modchartTimers) {
				timer.active = true;
			}
			paused = false;
			callOnLuas('onResume', []);

			#if desktop
			if (startTimer != null && startTimer.finished)
			{
				DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength - Conductor.songPosition - ClientPrefs.noteOffset);
			}
			else
			{
				DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
			}
			#end
		}

		super.closeSubState();
	}

	override public function onFocus():Void
	{
		#if desktop
		if (health > 0 && !paused)
		{
			if (Conductor.songPosition > 0.0)
			{
				DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength - Conductor.songPosition - ClientPrefs.noteOffset);
			}
			else
			{
				DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
			}
		}
		#end

		super.onFocus();
	}

	override public function onFocusLost():Void
	{
		#if desktop
		if (health > 0 && !paused)
		{
			DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		}
		#end

		super.onFocusLost();
	}

	function resyncVocals():Void
	{
		if(finishTimer != null) return;

		vocals.pause();

		FlxG.sound.music.play();
		Conductor.songPosition = FlxG.sound.music.time;
		vocals.time = Conductor.songPosition;
		vocals.play();
	}

	public var paused:Bool = false;
	public var canReset:Bool = true;
	var startedCountdown:Bool = false;
	var canPause:Bool = true;
	var limoSpeed:Float = 0;

	override public function update(elapsed:Float)
	{
		/*if (FlxG.keys.justPressed.NINE)
		{
			iconP1.swapOldIcon();
		}*/
		callOnLuas('onUpdate', [elapsed]);

		var currentBeat:Float = (Conductor.songPosition / 1000)*(Conductor.bpm/60);

		switch(SONG.song.toLowerCase())
		{
			case 'bloodshed': 
				if(funnywindow)
					setWindowPos(Std.int(127 * Math.sin(currentBeat * Math.PI) + 327), Std.int(127 * Math.sin(currentBeat * 3) + 160));
				if(funnywindowsmall)
					setWindowPos(Std.int(24 * Math.sin(currentBeat * Math.PI) + 327), Std.int(24 * Math.sin(currentBeat * 3) + 160));
				if(NOMOREFUNNY)
					setWindowPos(Std.int(0 * Math.sin(currentBeat * Math.PI) + 327), Std.int(0 * Math.sin(currentBeat * 3) + 160));
				if(daNoteMove)
				{
				    for (i in 4...8) 
					{
						var member = strumLineNotes.members[i];

						member.x  = defaultStrumX[i]+ 8* Math.sin((currentBeat + i*0.25) * Math.PI);

						if(FlxG.save.data.downscroll)
							member.y  = defaultStrumY -  18 *  Math.cos((currentBeat + i*2.5) * Math.PI);
						else 
							member.y  = defaultStrumY +  18 *  Math.cos((currentBeat + i*2.5) * Math.PI);
						
					}
				}
				if(daNoteMoveH)
				{
				    for (i in 4...8)
					{ 
						var member = strumLineNotes.members[i];
						member.x  = defaultStrumX[i] + 32 * Math.sin((currentBeat + i*0.25) * Math.PI);	
					}
				}
			
				if(daNoteMoveH3)
				{
				    for (i in 4...8)
					{ 
						var member = strumLineNotes.members[i];
						if(ClientPrefs.downScroll)
							member.y =  defaultStrumY - 128 * Math.cos((currentBeat/4) * Math.PI) - 128;	
						else 
							member.y =  defaultStrumY + 128 * Math.cos((currentBeat/4) * Math.PI) + 128;	

						member.x =  defaultStrumX[i]  + 128 * Math.sin((currentBeat) * Math.PI);	
					}
				}
				if(daNoteMoveH4)
				{
				    for (i in 4...8)
					{ 
						var member = strumLineNotes.members[i];
						member.x  = defaultStrumX[i] + 128 * Math.sin((currentBeat) * Math.PI);	

						if(ClientPrefs.downScroll)
							member.y  = defaultStrumY - 24 * Math.cos((currentBeat) * Math.PI);
						else
							member.y  = defaultStrumY + 24 * Math.cos((currentBeat) * Math.PI);
					}
					camHUD.angle = 10 * Math.sin((currentBeat/6) * Math.PI);
					FlxG.camera.angle = 2 * Math.sin((currentBeat/6) * Math.PI);
				}
				if(daNoteMoveH5)
				{
					for (i in 4...8)
					{ 
						var member = strumLineNotes.members[i];
						member.x  = defaultStrumX[i] + 128 * Math.sin((currentBeat) * Math.PI);	
						
						if(ClientPrefs.downScroll)
							member.y  = defaultStrumY - 96 * Math.cos((currentBeat/4) * Math.PI) - 96;
						else 
							member.y  = defaultStrumY + 96 * Math.cos((currentBeat/4) * Math.PI) + 96;
					}
					camHUD.angle = 25 * Math.sin((currentBeat/5) * Math.PI);
					FlxG.camera.angle = 5 * Math.sin((currentBeat/5) * Math.PI);
				}
		}

		switch (curStage)
		{
			case 'mall':
				if(heyTimer > 0)
				{
					heyTimer -= elapsed;
					if(heyTimer <= 0)
					{
						bottomBoppers.dance(true);
						heyTimer = 0;
					}
				}
		}

		if(!inCutscene)
		{
			var lerpVal:Float = CoolUtil.boundTo(elapsed * 2.4 * cameraSpeed, 0, 1);
			camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));
			if(!startingSong && !endingSong && boyfriend.animation.curAnim.name.startsWith('idle'))
			{
				boyfriendIdleTime += elapsed;
				if(boyfriendIdleTime >= 0.15) // Kind of a mercy thing for making the achievement easier to get as it's apparently frustrating to some playerss
					boyfriendIdled = true;
			} else
				boyfriendIdleTime = 0;
		}

		if (curSong.toLowerCase() == 'bloodbath')
		{
			if (windowmove)
				setWindowPos(Math.round(24 * Math.sin(currentBeat * Math.PI) + 327), Math.round(24 * Math.sin(currentBeat * 3) + 160));
			if (cameramove)
			{
				camHUD.angle = 10 * Math.sin((currentBeat/6) * Math.PI);
				FlxG.camera.angle = 2 * Math.sin((currentBeat/6) * Math.PI);
			}
		}

		if (curSong.toLowerCase() == 'bleeding')
		{
			if (windowmove)
				setWindowPos(Math.round(24 * Math.sin(currentBeat * Math.PI) + 327), Math.round(24 * Math.sin(currentBeat * 3) + 160));
			if (cameramove)
			{
				camHUD.angle = 22 * Math.sin((currentBeat/4) * Math.PI);
				FlxG.camera.angle = 4 * Math.sin((currentBeat/4) * Math.PI);
			}
			if (intensecameramove)
			{
				camHUD.angle = 45 * Math.sin((currentBeat/2) * Math.PI);
				FlxG.camera.angle = 9 * Math.sin((currentBeat/2) * Math.PI);
			}
			if (WHATTHEFUCK)
			{
				camHUD.angle = 90 * Math.sin((currentBeat / 2) * Math.PI);
				FlxG.camera.angle = 18 * Math.sin((currentBeat / 2) * Math.PI);
			}
			if (WTFending)
			{
				camHUD.angle = 360 * Math.sin((currentBeat / 8) * Math.PI);
				FlxG.camera.angle = 27 * Math.sin((currentBeat / 2) * Math.PI);
			}
		}

		if (curSong.toLowerCase() == 'trojan-virus' && startedCountdown)
		{
			if (moveing)
			{
				for (i in 0...8)
					strumLineNotes.members[i].x = defaultStrumX[i]+ 32 * Math.sin((currentBeat + i*0.25) * Math.PI);
			} else
			{
				for (i in 0...8)
					strumLineNotes.members[i].x = defaultStrumX[i]+ 16 * Math.sin((currentBeat/4 + i*0.25) * Math.PI);
			}
		}

		var chromeOffset:Float = (((2 - health/2)/2+0.5));
		chromeOffset /= 350;

		if ((curSong == 'Atelophobia') || (curSong == 'Factory-Reset') || (curSong == 'Bloodshed') || (curSong == 'Bloodshed-b') || (curSong == 'Bloodshed-old') || (curSong == 'BLOODSHED-TWO') || (curSong == 'Factory-Reset-b') || (curSong == 'Atelophobia-b') || (curSong == 'Trojan-Virus') || (curSong == 'Trojan-Virus-b') || (curSong == 'File-Manipulation') || (curSong == 'File Manipulation-b')) 
		{

			if (chromeOffset <= 0)
			{
				setChrome(0.0);
			}
			else
			{
				if (ClientPrefs.rgbenable)
				{
					switch (curSong)
					{
						case 'File-Manipulation':
							setChrome(ClientPrefs.rgbintense/350);
						default:
							var sinus = 1;
							if (curStep >= 538)
								sinus = 2 * Std.int(Math.sin((curStep - 538) / 3));
							setChrome(chromeOffset*ClientPrefs.rgbintense*sinus/350);
					}
				}
				else
					setChrome(0.0);
			}
		}
		else
		{
			if ((curSong == 'Withered-Tweaked') && (curStep >= 1152))
				setChrome(chromeOffset*ClientPrefs.rgbintense/350);
		}

		super.update(elapsed);

		scoreTxt.text = 'Score: ' + songScore + ' | Misses: ' + songMisses + ' | Rating: ' + ratingName;
		if(ratingName != '?')
			scoreTxt.text += ' (' + Highscore.floorDecimal(ratingPercent * 100, 2) + '%)' + ' - ' + ratingFC;

		if(botplayTxt.visible) {
			botplaySine += 180 * elapsed;
			botplayTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180);
		}

		if (controls.PAUSE && startedCountdown && canPause)
		{
			var ret:Dynamic = callOnLuas('onPause', []);
			if(ret != FunkinLua.Function_Stop) {
				persistentUpdate = false;
				persistentDraw = true;
				paused = true;

				// 1 / 1000 chance for Gitaroo Man easter egg
				/*if (FlxG.random.bool(0.1))
				{
					// gitaroo man easter egg
					cancelMusicFadeTween();
					MusicBeatState.switchState(new GitarooPause());
				}
				else {*/
				if(FlxG.sound.music != null) {
					FlxG.sound.music.pause();
					vocals.pause();
				}
				openSubState(new PauseSubState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));
				//}

				#if desktop
				DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
				#end
			}
		}

		if (FlxG.keys.anyJustPressed(debugKeysChart) && !endingSong && !inCutscene)
		{
			openChartEditor();
		}

		// FlxG.watch.addQuick('VOL', vocals.amplitudeLeft);
		// FlxG.watch.addQuick('VOLRight', vocals.amplitudeRight);

		var mult:Float = FlxMath.lerp(1, iconP1.scale.x, CoolUtil.boundTo(1 - (elapsed * 9), 0, 1));
		iconP1.scale.set(mult, mult);
		iconP1.updateHitbox();

		var mult:Float = FlxMath.lerp(1, iconP2.scale.x, CoolUtil.boundTo(1 - (elapsed * 9), 0, 1));
		iconP2.scale.set(mult, mult);
		iconP2.updateHitbox();

		var iconOffset:Int = 26;

		iconP1.x = healthBar.x + (healthBar.width * (FlxMath.remapToRange(healthBar.percent, 0, 100, 100, 0) * 0.01)) + (150 * iconP1.scale.x - 150) / 2 - iconOffset;
		iconP2.x = healthBar.x + (healthBar.width * (FlxMath.remapToRange(healthBar.percent, 0, 100, 100, 0) * 0.01)) - (150 * iconP2.scale.x) / 2 - iconOffset * 2;

		if (health > 2)
			health = 2;

		if (healthBar.percent < 20)
			iconP1.animation.curAnim.curFrame = 1;
		else
			iconP1.animation.curAnim.curFrame = 0;

		if (healthBar.percent > 80)
			iconP2.animation.curAnim.curFrame = 1;
		else
			iconP2.animation.curAnim.curFrame = 0;

		if (FlxG.keys.anyJustPressed(debugKeysCharacter) && !endingSong && !inCutscene) {
			persistentUpdate = false;
			paused = true;
			cancelMusicFadeTween();
			MusicBeatState.switchState(new CharacterEditorState(SONG.player2));
		}

		if (startingSong)
		{
			if (startedCountdown)
			{
				Conductor.songPosition += FlxG.elapsed * 1000;
				if (Conductor.songPosition >= 0)
					startSong();
			}
		}
		else
		{
			Conductor.songPosition += FlxG.elapsed * 1000;

			if (!paused)
			{
				songTime += FlxG.game.ticks - previousFrameTime;
				previousFrameTime = FlxG.game.ticks;

				// Interpolation type beat
				if (Conductor.lastSongPos != Conductor.songPosition)
				{
					songTime = (songTime + Conductor.songPosition) / 2;
					Conductor.lastSongPos = Conductor.songPosition;
					// Conductor.songPosition += FlxG.elapsed * 1000;
					// trace('MISSED FRAME');
				}

				if(updateTime) {
					var curTime:Float = Conductor.songPosition - ClientPrefs.noteOffset;
					if(curTime < 0) curTime = 0;
					songPercent = (curTime / songLength);

					var songCalc:Float = (songLength - curTime);
					if(ClientPrefs.timeBarType == 'Time Elapsed') songCalc = curTime;

					var secondsTotal:Int = Math.floor(songCalc / 1000);
					if(secondsTotal < 0) secondsTotal = 0;

					if(ClientPrefs.timeBarType != 'Song Name')
						timeTxt.text = FlxStringUtil.formatTime(secondsTotal, false);
				}
			}

			// Conductor.lastSongPos = FlxG.sound.music.time;
		}

		if (camZooming)
		{
			FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom, FlxG.camera.zoom, CoolUtil.boundTo(1 - (elapsed * 3.125 * camZoomingDecay), 0, 1));
			camHUD.zoom = FlxMath.lerp(1, camHUD.zoom, CoolUtil.boundTo(1 - (elapsed * 3.125 * camZoomingDecay), 0, 1));
		}

		FlxG.watch.addQuick("beatShit", curBeat);
		FlxG.watch.addQuick("stepShit", curStep);

		// RESET = Quick Game Over Screen
		if (!ClientPrefs.noReset && controls.RESET && canReset && !inCutscene && startedCountdown && !endingSong)
		{
			health = 0;
			trace("RESET = True");
		}
		doDeathCheck();

		if (unspawnNotes[0] != null)
		{
			var time:Float = spawnTime;//shit be werid on 4:3
			if(songSpeed < 1) time /= songSpeed;

			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time)
			{
				var dunceNote:Note = unspawnNotes[0];
				notes.insert(0, dunceNote);
				dunceNote.spawned=true;
				callOnLuas('onSpawnNote', [notes.members.indexOf(dunceNote), dunceNote.noteData, dunceNote.noteType, dunceNote.isSustainNote, dunceNote.ID]);

				var index:Int = unspawnNotes.indexOf(dunceNote);
				unspawnNotes.splice(index, 1);
			}
		}

		if (generatedMusic)
		{
			if (!inCutscene) {
				if(!cpuControlled) {
					keyShit();
				} else if(boyfriend.holdTimer > Conductor.stepCrochet * 0.0011 * boyfriend.singDuration && boyfriend.animation.curAnim.name.startsWith('sing') && !boyfriend.animation.curAnim.name.endsWith('miss')) {
					boyfriend.dance();
					//boyfriend.animation.curAnim.finish();
				}
			}

			var fakeCrochet:Float = (60 / SONG.bpm) * 1000;
			notes.forEachAlive(function(daNote:Note)
			{
				var strumGroup:FlxTypedGroup<StrumNote> = playerStrums;
				if(!daNote.mustPress) strumGroup = opponentStrums;

				var strumX:Float = strumGroup.members[daNote.noteData].x;
				var strumY:Float = strumGroup.members[daNote.noteData].y;
				var strumAngle:Float = strumGroup.members[daNote.noteData].angle;
				var strumDirection:Float = strumGroup.members[daNote.noteData].direction;
				var strumAlpha:Float = strumGroup.members[daNote.noteData].alpha;
				var strumScroll:Bool = strumGroup.members[daNote.noteData].downScroll;

				strumX += daNote.offsetX;
				strumY += daNote.offsetY;
				strumAngle += daNote.offsetAngle;
				strumAlpha *= daNote.multAlpha;

				if (strumScroll) //Downscroll
				{
					//daNote.y = (strumY + 0.45 * (Conductor.songPosition - daNote.strumTime) * songSpeed);
					daNote.distance = (0.45 * (Conductor.songPosition - daNote.strumTime) * songSpeed * daNote.multSpeed);
				}
				else //Upscroll
				{
					//daNote.y = (strumY - 0.45 * (Conductor.songPosition - daNote.strumTime) * songSpeed);
					daNote.distance = (-0.45 * (Conductor.songPosition - daNote.strumTime) * songSpeed * daNote.multSpeed);
				}

				var angleDir = strumDirection * Math.PI / 180;
				if (daNote.copyAngle)
					daNote.angle = strumDirection - 90 + strumAngle;

				if(daNote.copyAlpha)
					daNote.alpha = strumAlpha;

				if(daNote.copyX)
					daNote.x = strumX + Math.cos(angleDir) * daNote.distance;

				if(daNote.copyY)
				{
					daNote.y = strumY + Math.sin(angleDir) * daNote.distance;

					//Jesus fuck this took me so much mother fucking time AAAAAAAAAA
					if(strumScroll && daNote.isSustainNote)
					{
						if (daNote.animation.curAnim.name.endsWith('end')) {
							daNote.y += 10.5 * (fakeCrochet / 400) * 1.5 * songSpeed + (46 * (songSpeed - 1));
							daNote.y -= 46 * (1 - (fakeCrochet / 600)) * songSpeed;
							if(PlayState.isPixelStage) {
								daNote.y += 8 + (6 - daNote.originalHeightForCalcs) * PlayState.daPixelZoom;
							} else {
								daNote.y -= 19;
							}
						}
						daNote.y += (Note.swagWidth / 2) - (60.5 * (songSpeed - 1));
						daNote.y += 27.5 * ((SONG.bpm / 100) - 1) * (songSpeed - 1);
					}
				}

				if (!daNote.mustPress && daNote.wasGoodHit && !daNote.hitByOpponent && !daNote.ignoreNote)
					opponentNoteHit(daNote);

				if(daNote.mustPress && cpuControlled) {
					if(daNote.isSustainNote) {
						if(daNote.canBeHit) {
							goodNoteHit(daNote);
						}
					} else if(daNote.strumTime <= Conductor.songPosition || (daNote.isSustainNote && daNote.canBeHit && daNote.mustPress)) {
						goodNoteHit(daNote);
					}
				}

				var center:Float = strumY + Note.swagWidth / 2;
				if(strumGroup.members[daNote.noteData].sustainReduce && daNote.isSustainNote && (daNote.mustPress || !daNote.ignoreNote) &&
					(!daNote.mustPress || (daNote.wasGoodHit || (daNote.prevNote.wasGoodHit && !daNote.canBeHit))))
				{
					if (strumScroll)
					{
						if(daNote.y - daNote.offset.y * daNote.scale.y + daNote.height >= center)
						{
							var swagRect = new FlxRect(0, 0, daNote.frameWidth, daNote.frameHeight);
							swagRect.height = (center - daNote.y) / daNote.scale.y;
							swagRect.y = daNote.frameHeight - swagRect.height;

							daNote.clipRect = swagRect;
						}
					}
					else
					{
						if (daNote.y + daNote.offset.y * daNote.scale.y <= center)
						{
							var swagRect = new FlxRect(0, 0, daNote.width / daNote.scale.x, daNote.height / daNote.scale.y);
							swagRect.y = (center - daNote.y) / daNote.scale.y;
							swagRect.height -= swagRect.y;

							daNote.clipRect = swagRect;
						}
					}
				}

				// Kill extremely late notes and cause misses
				if (Conductor.songPosition > noteKillOffset + daNote.strumTime)
				{
					if (daNote.mustPress && !cpuControlled &&!daNote.ignoreNote && !endingSong && (daNote.tooLate || !daNote.wasGoodHit)) {
						noteMiss(daNote);
					}

					daNote.active = false;
					daNote.visible = false;

					if(modchartObjects.exists('note${daNote.ID}'))modchartObjects.remove('note${daNote.ID}');
					daNote.kill();
					notes.remove(daNote, true);
					daNote.destroy();
				}
			});
		}
		checkEventNote();

		//#if debug
		if(!endingSong && !startingSong) {
			if (FlxG.keys.justPressed.ONE) {
				KillNotes();
				FlxG.sound.music.onComplete();
			}
			if(FlxG.keys.justPressed.TWO) { //Go 10 seconds into the future :O
				setSongTime(Conductor.songPosition + 10000);
				clearNotesBefore(Conductor.songPosition);
			}
		}
		//#end

		setOnLuas('cameraX', camFollowPos.x);
		setOnLuas('cameraY', camFollowPos.y);
		setOnLuas('botPlay', cpuControlled);
		callOnLuas('onUpdatePost', [elapsed]);
	}

	function openChartEditor()
	{
		persistentUpdate = false;
		paused = true;
		cancelMusicFadeTween();
		MusicBeatState.switchState(new ChartingState());
		chartingMode = true;

		#if desktop
		DiscordClient.changePresence("Chart Editor", null, null, true);
		#end
	}

	public var isDead:Bool = false; //Don't mess with this on Lua!!!
	function doDeathCheck(?skipHealthCheck:Bool = false) {
		if (((skipHealthCheck && instakillOnMiss) || health <= 0) && !practiceMode && !isDead)
		{
			var ret:Dynamic = callOnLuas('onGameOver', []);
			if(ret != FunkinLua.Function_Stop) {
				setChrome(0.0);

				boyfriend.stunned = true;
				deathCounter++;

				paused = true;

				vocals.stop();
				FlxG.sound.music.stop();

				persistentUpdate = false;
				persistentDraw = false;
				for (tween in modchartTweens) {
					tween.active = true;
				}
				for (timer in modchartTimers) {
					timer.active = true;
				}
				openSubState(new GameOverSubstate(boyfriend.getScreenPosition().x - boyfriend.positionArray[0], boyfriend.getScreenPosition().y - boyfriend.positionArray[1], camFollowPos.x, camFollowPos.y));

				// MusicBeatState.switchState(new GameOverState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));

				#if desktop
				// Game Over doesn't get his own variable because it's only used here
				DiscordClient.changePresence("Game Over - " + detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
				#end
				isDead = true;
				return true;
			}
		}
		return false;
	}

	public function checkEventNote() {
		while(eventNotes.length > 0) {
			var leStrumTime:Float = eventNotes[0].strumTime;
			if(Conductor.songPosition < leStrumTime) {
				break;
			}

			var value1:String = '';
			if(eventNotes[0].value1 != null)
				value1 = eventNotes[0].value1;

			var value2:String = '';
			if(eventNotes[0].value2 != null)
				value2 = eventNotes[0].value2;

			triggerEventNote(eventNotes[0].event, value1, value2);
			eventNotes.shift();
		}
	}

	public function getControl(key:String) {
		var pressed:Bool = Reflect.getProperty(controls, key);
		//trace('Control result: ' + pressed);
		return pressed;
	}

	public function triggerEventNote(eventName:String, value1:String, value2:String) {
		switch(eventName) {
			case 'Dadbattle Spotlight':
				var val:Null<Int> = Std.parseInt(value1);
				if(val == null) val = 0;

				switch(Std.parseInt(value1))
				{
					case 1, 2, 3: //enable and target dad
						if(val == 1) //enable
						{
							dadbattleBlack.visible = true;
							dadbattleLight.visible = true;
							dadbattleSmokes.visible = true;
							defaultCamZoom += 0.12;
						}

						var who:Character = dad;
						if(val > 2) who = boyfriend;
						//2 only targets dad
						dadbattleLight.alpha = 0;
						new FlxTimer().start(0.12, function(tmr:FlxTimer) {
							dadbattleLight.alpha = 0.375;
						});
						dadbattleLight.setPosition(who.getGraphicMidpoint().x - dadbattleLight.width / 2, who.y + who.height - dadbattleLight.height + 50);

					default:
						dadbattleBlack.visible = false;
						dadbattleLight.visible = false;
						defaultCamZoom -= 0.12;
						FlxTween.tween(dadbattleSmokes, {alpha: 0}, 1, {onComplete: function(twn:FlxTween)
						{
							dadbattleSmokes.visible = false;
						}});
				}

			case 'Hey!':
				var value:Int = 2;
				switch(value1.toLowerCase().trim()) {
					case 'bf' | 'boyfriend' | '0':
						value = 0;
					case 'gf' | 'girlfriend' | '1':
						value = 1;
				}

				var time:Float = Std.parseFloat(value2);
				if(Math.isNaN(time) || time <= 0) time = 0.6;

				if(value != 0) {
					if(dad.curCharacter.startsWith('gf')) { //Tutorial GF is actually Dad! The GF is an imposter!! ding ding ding ding ding ding ding, dindinding, end my suffering
						dad.playAnim('cheer', true);
						dad.specialAnim = true;
						dad.heyTimer = time;
					} else if (gf != null) {
						gf.playAnim('cheer', true);
						gf.specialAnim = true;
						gf.heyTimer = time;
					}

					if(curStage == 'mall') {
						bottomBoppers.animation.play('hey', true);
						heyTimer = time;
					}
				}
				if(value != 1) {
					boyfriend.playAnim('hey', true);
					boyfriend.specialAnim = true;
					boyfriend.heyTimer = time;
				}

			case 'Set GF Speed':
				var value:Int = Std.parseInt(value1);
				if(Math.isNaN(value) || value < 1) value = 1;
				gfSpeed = value;

			case 'Philly Glow':
				var lightId:Int = Std.parseInt(value1);
				if(Math.isNaN(lightId)) lightId = 0;

				var chars:Array<Character> = [boyfriend, gf, dad];
				switch(lightId)
				{
					case 0:
						if(phillyGlowGradient.visible)
						{
							FlxG.camera.flash(FlxColor.WHITE, 0.15, null, true);
							FlxG.camera.zoom += 0.5;
							if(ClientPrefs.camZooms) camHUD.zoom += 0.1;

							blammedLightsBlack.visible = false;
							phillyWindowEvent.visible = false;
							phillyGlowGradient.visible = false;
							phillyGlowParticles.visible = false;
							curLightEvent = -1;

							for (who in chars)
							{
								who.color = FlxColor.WHITE;
							}
							phillyStreet.color = FlxColor.WHITE;
						}

					case 1: //turn on
						curLightEvent = FlxG.random.int(0, phillyLightsColors.length-1, [curLightEvent]);
						var color:FlxColor = phillyLightsColors[curLightEvent];

						if(!phillyGlowGradient.visible)
						{
							FlxG.camera.flash(FlxColor.WHITE, 0.15, null, true);
							FlxG.camera.zoom += 0.5;
							if(ClientPrefs.camZooms) camHUD.zoom += 0.1;

							blammedLightsBlack.visible = true;
							blammedLightsBlack.alpha = 1;
							phillyWindowEvent.visible = true;
							phillyGlowGradient.visible = true;
							phillyGlowParticles.visible = true;
						}
						else if(ClientPrefs.flashing)
						{
							var colorButLower:FlxColor = color;
							colorButLower.alphaFloat = 0.3;
							FlxG.camera.flash(colorButLower, 0.5, null, true);
						}

						for (who in chars)
						{
							who.color = color;
						}
						phillyGlowParticles.forEachAlive(function(particle:PhillyGlow.PhillyGlowParticle)
						{
							particle.color = color;
						});
						phillyGlowGradient.color = color;
						phillyWindowEvent.color = color;

						var colorDark:FlxColor = color;
						colorDark.brightness *= 0.5;
						phillyStreet.color = colorDark;

					case 2: // spawn particles
						if(!ClientPrefs.lowQuality)
						{
							var particlesNum:Int = FlxG.random.int(8, 12);
							var width:Float = (2000 / particlesNum);
							var color:FlxColor = phillyLightsColors[curLightEvent];
							for (j in 0...3)
							{
								for (i in 0...particlesNum)
								{
									var particle:PhillyGlow.PhillyGlowParticle = new PhillyGlow.PhillyGlowParticle(-400 + width * i + FlxG.random.float(-width / 5, width / 5), phillyGlowGradient.originalY + 200 + (FlxG.random.float(0, 125) + j * 40), color);
									phillyGlowParticles.add(particle);
								}
							}
						}
						phillyGlowGradient.bop();
				}

			case 'Kill Henchmen':
				killHenchmen();

			case 'Add Camera Zoom':
				if(ClientPrefs.camZooms && FlxG.camera.zoom < 1.35) {
					var camZoom:Float = Std.parseFloat(value1);
					var hudZoom:Float = Std.parseFloat(value2);
					if(Math.isNaN(camZoom)) camZoom = 0.015;
					if(Math.isNaN(hudZoom)) hudZoom = 0.03;

					FlxG.camera.zoom += camZoom;
					camHUD.zoom += hudZoom;
				}

			case 'Trigger BG Ghouls':
				if(curStage == 'schoolEvil' && !ClientPrefs.lowQuality) {
					bgGhouls.dance(true);
					bgGhouls.visible = true;
				}

			case 'Play Animation':
				//trace('Anim to play: ' + value1);
				var char:Character = dad;
				switch(value2.toLowerCase().trim()) {
					case 'bf' | 'boyfriend':
						char = boyfriend;
					case 'gf' | 'girlfriend':
						char = gf;
					default:
						var val2:Int = Std.parseInt(value2);
						if(Math.isNaN(val2)) val2 = 0;

						switch(val2) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.playAnim(value1, true);
					char.specialAnim = true;
				}

			case 'Camera Follow Pos':
				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);
				if(Math.isNaN(val1)) val1 = 0;
				if(Math.isNaN(val2)) val2 = 0;

				isCameraOnForcedPos = false;
				if(!Math.isNaN(Std.parseFloat(value1)) || !Math.isNaN(Std.parseFloat(value2))) {
					camFollow.x = val1;
					camFollow.y = val2;
					isCameraOnForcedPos = true;
				}

			case 'Alt Idle Animation':
				var char:Character = dad;
				switch(value1.toLowerCase()) {
					case 'gf' | 'girlfriend':
						char = gf;
					case 'boyfriend' | 'bf':
						char = boyfriend;
					default:
						var val:Int = Std.parseInt(value1);
						if(Math.isNaN(val)) val = 0;

						switch(val) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.idleSuffix = value2;
					char.recalculateDanceIdle();
				}

			case 'Screen Shake':
				var valuesArray:Array<String> = [value1, value2];
				var targetsArray:Array<FlxCamera> = [camGame, camHUD];
				for (i in 0...targetsArray.length) {
					var split:Array<String> = valuesArray[i].split(',');
					var duration:Float = 0;
					var intensity:Float = 0;
					if(split[0] != null) duration = Std.parseFloat(split[0].trim());
					if(split[1] != null) intensity = Std.parseFloat(split[1].trim());
					if(Math.isNaN(duration)) duration = 0;
					if(Math.isNaN(intensity)) intensity = 0;

					if(duration > 0 && intensity != 0) {
						targetsArray[i].shake(intensity, duration);
					}
				}


			case 'Change Character':
				var charType:Int = 0;
				switch(value1) {
					case 'gf' | 'girlfriend':
						charType = 2;
					case 'dad' | 'opponent':
						charType = 1;
					default:
						charType = Std.parseInt(value1);
						if(Math.isNaN(charType)) charType = 0;
				}

				switch(charType) {
					case 0:
						if(boyfriend.curCharacter != value2) {
							if(!boyfriendMap.exists(value2)) {
								addCharacterToList(value2, charType);
							}

							var lastAlpha:Float = boyfriend.alpha;
							boyfriend.alpha = 0.00001;
							boyfriend = boyfriendMap.get(value2);
							boyfriend.alpha = lastAlpha;
							iconP1.changeIcon(boyfriend.healthIcon);
						}
						setOnLuas('boyfriendName', boyfriend.curCharacter);

					case 1:
						if(dad.curCharacter != value2) {
							if(!dadMap.exists(value2)) {
								addCharacterToList(value2, charType);
							}

							var wasGf:Bool = dad.curCharacter.startsWith('gf');
							var lastAlpha:Float = dad.alpha;
							dad.alpha = 0.00001;
							dad = dadMap.get(value2);
							if(!dad.curCharacter.startsWith('gf')) {
								if(wasGf && gf != null) {
									gf.visible = true;
								}
							} else if(gf != null) {
								gf.visible = false;
							}
							dad.alpha = lastAlpha;
							iconP2.changeIcon(dad.healthIcon);
						}
						setOnLuas('dadName', dad.curCharacter);

					case 2:
						if(gf != null)
						{
							if(gf.curCharacter != value2)
							{
								if(!gfMap.exists(value2))
								{
									addCharacterToList(value2, charType);
								}

								var lastAlpha:Float = gf.alpha;
								gf.alpha = 0.00001;
								gf = gfMap.get(value2);
								gf.alpha = lastAlpha;
							}
							setOnLuas('gfName', gf.curCharacter);
						}
				}
				reloadHealthBarColors();

			case 'BG Freaks Expression':
				if(bgGirls != null) bgGirls.swapDanceType();

			case 'Change Scroll Speed':
				if (songSpeedType == "constant")
					return;
				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);
				if(Math.isNaN(val1)) val1 = 1;
				if(Math.isNaN(val2)) val2 = 0;

				var newValue:Float = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1) * val1;

				if(val2 <= 0)
				{
					songSpeed = newValue;
				}
				else
				{
					songSpeedTween = FlxTween.tween(this, {songSpeed: newValue}, val2, {ease: FlxEase.linear, onComplete:
						function (twn:FlxTween)
						{
							songSpeedTween = null;
						}
					});
				}

			case 'Set Property':
				var killMe:Array<String> = value1.split('.');
				if(killMe.length > 1) {
					FunkinLua.setVarInArray(FunkinLua.getPropertyLoopThingWhatever(killMe, true, true), killMe[killMe.length-1], value2);
				} else {
					FunkinLua.setVarInArray(this, value1, value2);
				}
		}
		callOnLuas('onEvent', [eventName, value1, value2]);
	}

	function moveCameraSection(?id:Int = 0):Void {
		if(SONG.notes[id] == null) return;

		if (gf != null && SONG.notes[id].gfSection)
		{
			camFollow.set(gf.getMidpoint().x, gf.getMidpoint().y);
			camFollow.x += gf.cameraPosition[0] + girlfriendCameraOffset[0];
			camFollow.y += gf.cameraPosition[1] + girlfriendCameraOffset[1];
			tweenCamIn();
			callOnLuas('onMoveCamera', ['gf']);
			return;
		}

		if (!SONG.notes[id].mustHitSection)
		{
			moveCamera(true);
			callOnLuas('onMoveCamera', ['dad']);
		}
		else
		{
			moveCamera(false);
			callOnLuas('onMoveCamera', ['boyfriend']);
		}
	}

	var cameraTwn:FlxTween;
	public function moveCamera(isDad:Bool)
	{
		if(isDad)
		{
			camFollow.set(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100);
			camFollow.x += dad.cameraPosition[0] + opponentCameraOffset[0];
			camFollow.y += dad.cameraPosition[1] + opponentCameraOffset[1];
			tweenCamIn();
		}
		else
		{
			camFollow.set(boyfriend.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
			camFollow.x -= boyfriend.cameraPosition[0] - boyfriendCameraOffset[0];
			camFollow.y += boyfriend.cameraPosition[1] + boyfriendCameraOffset[1];

			if (Paths.formatToSongPath(SONG.song) == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1)
			{
				cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1}, (Conductor.stepCrochet * 4 / 1000), {ease: FlxEase.elasticInOut, onComplete:
					function (twn:FlxTween)
					{
						cameraTwn = null;
					}
				});
			}
		}
	}

	function tweenCamIn() {
		if (Paths.formatToSongPath(SONG.song) == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1.3) {
			cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1.3}, (Conductor.stepCrochet * 4 / 1000), {ease: FlxEase.elasticInOut, onComplete:
				function (twn:FlxTween) {
					cameraTwn = null;
				}
			});
		}
	}

	function snapCamFollowToPos(x:Float, y:Float) {
		camFollow.set(x, y);
		camFollowPos.setPosition(x, y);
	}

	//Any way to do this without using a different function? kinda dumb
	private function onSongComplete()
	{
		finishSong(false);
	}
	public function finishSong(?ignoreNoteOffset:Bool = false):Void
	{
		var finishCallback:Void->Void = endSong; //In case you want to change it in a specific song.

		updateTime = false;
		FlxG.sound.music.volume = 0;
		vocals.volume = 0;
		vocals.pause();
		if(ClientPrefs.noteOffset <= 0 || ignoreNoteOffset) {
			finishCallback();
		} else {
			finishTimer = new FlxTimer().start(ClientPrefs.noteOffset / 1000, function(tmr:FlxTimer) {
				finishCallback();
			});
		}
	}


	public var transitioning = false;
	public function endSong():Void
	{
		//Should kill you if you tried to cheat
		if(!startingSong) {
			notes.forEach(function(daNote:Note) {
				if(daNote.strumTime < songLength - Conductor.safeZoneOffset) {
					health -= 0.05 * healthLoss;
				}
			});
			for (daNote in unspawnNotes) {
				if(daNote.strumTime < songLength - Conductor.safeZoneOffset) {
					health -= 0.05 * healthLoss;
				}
			}

			if(doDeathCheck()) {
				return;
			}
		}

		timeBarBG.visible = false;
		timeBar.visible = false;
		timeTxt.visible = false;
		canPause = false;
		endingSong = true;
		camZooming = false;
		inCutscene = false;
		updateTime = false;

		deathCounter = 0;
		seenCutscene = false;

		#if ACHIEVEMENTS_ALLOWED
		if(achievementObj != null) {
			return;
		} else {
			var achieve:String = checkForAchievement(['week1_nomiss', 'week2_nomiss', 'week3_nomiss', 'week4_nomiss',
				'week5_nomiss', 'week6_nomiss', 'week7_nomiss', 'ur_bad',
				'ur_good', 'hype', 'two_keys', 'toastie', 'debugger']);

			if(achieve != null) {
				startAchievement(achieve);
				return;
			}
		}
		#end

		#if LUA_ALLOWED
		var ret:Dynamic = callOnLuas('onEndSong', []);
		#else
		var ret:Dynamic = FunkinLua.Function_Continue;
		#end

		if(ret != FunkinLua.Function_Stop && !transitioning) {
			if (SONG.validScore)
			{
				#if !switch
				var percent:Float = ratingPercent;
				if(Math.isNaN(percent)) percent = 0;
				Highscore.saveScore(SONG.song, songScore, storyDifficulty, percent);
				#end
			}

			if (chartingMode)
			{
				openChartEditor();
				return;
			}

			if (isStoryMode)
			{
				campaignScore += songScore;
				campaignMisses += songMisses;

				storyPlaylist.remove(storyPlaylist[0]);

				if (storyPlaylist.length <= 0)
				{
					FlxG.sound.playMusic(Paths.music('freakyMenu'));

					cancelMusicFadeTween();
					if(FlxTransitionableState.skipNextTransIn)
						CustomFadeTransition.nextCamera = null;
					MusicBeatState.switchState(new StoryMenuState());

					// if ()
					if(!ClientPrefs.getGameplaySetting('practice', false) && !ClientPrefs.getGameplaySetting('botplay', false)) {
						StoryMenuState.weekCompleted.set(WeekData.weeksList[storyWeek], true);

						if (SONG.validScore)
						{
							Highscore.saveWeekScore(WeekData.getWeekFileName(), campaignScore, storyDifficulty);
						}

						FlxG.save.data.weekCompleted = StoryMenuState.weekCompleted;
						FlxG.save.flush();
					}
					changedDifficulty = false;
				}
				else
				{
					var difficulty:String = CoolUtil.getDifficultyFilePath();

					trace('LOADING NEXT SONG');
					trace(Paths.formatToSongPath(PlayState.storyPlaylist[0]) + difficulty);


					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;

					prevCamFollow = camFollow;
					prevCamFollowPos = camFollowPos;

					PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0] + difficulty, PlayState.storyPlaylist[0]);
					FlxG.sound.music.stop();

					cancelMusicFadeTween();
					if (SONG.song.toLowerCase() == 'bloodshed')
					{
						video.playMP4(Paths.video('bloodshed'), new PlayState(), false, false, false);
					}
					else
					{
						LoadingState.loadAndSwitchState(new PlayState());
					}
				}
			}
			else
			{
				trace('WENT BACK TO FREEPLAY??');
				cancelMusicFadeTween();
				if(FlxTransitionableState.skipNextTransIn) {
					CustomFadeTransition.nextCamera = null;
				}
				MusicBeatState.switchState(new FreeplayState());
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
				changedDifficulty = false;
			}
			transitioning = true;
		}
	}

	#if ACHIEVEMENTS_ALLOWED
	var achievementObj:AchievementObject = null;
	function startAchievement(achieve:String) {
		achievementObj = new AchievementObject(achieve, camOther);
		achievementObj.onFinish = achievementEnd;
		add(achievementObj);
		trace('Giving achievement ' + achieve);
	}
	function achievementEnd():Void
	{
		achievementObj = null;
		if(endingSong && !inCutscene) {
			endSong();
		}
	}
	#end

	public function KillNotes() {
		while(notes.length > 0) {
			var daNote:Note = notes.members[0];
			daNote.active = false;
			daNote.visible = false;

			if(modchartObjects.exists('note${daNote.ID}'))modchartObjects.remove('note${daNote.ID}');
			daNote.kill();
			notes.remove(daNote, true);
			daNote.destroy();
		}
		unspawnNotes = [];
		eventNotes = [];
	}

	public var totalPlayed:Int = 0;
	public var totalNotesHit:Float = 0.0;

	public var showCombo:Bool = true;
	public var showRating:Bool = true;

	private function popUpScore(note:Note = null):Void
	{
		var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.ratingOffset);
		//trace(noteDiff, ' ' + Math.abs(note.strumTime - Conductor.songPosition));

		// boyfriend.playAnim('hey');
		vocals.volume = 1;

		var placement:String = Std.string(combo);

		var coolText:FlxText = new FlxText(0, 0, 0, placement, 32);
		coolText.screenCenter();
		coolText.x = FlxG.width * 0.35;
		//

		var rating:FlxSprite = new FlxSprite();
		var score:Int = 350;

		//tryna do MS based judgment due to popular demand
		var daRating:Rating = Conductor.judgeNote(note, noteDiff);
		var ratingNum:Int = 0;

		if (SCREWYOU)
		{
			switch(daRating.name)
			{
				// i should nerf unforgiving input its too hard
				case 'shit':
					health -= 0.15;
				case 'bad':
					health -= 0.045;
				case 'good' | 'sick':
					health += 0.05;
			}
		}

		totalNotesHit += daRating.ratingMod;
		note.ratingMod = daRating.ratingMod;
		if(!note.ratingDisabled) daRating.increase();
		note.rating = daRating.name;

		if(daRating.noteSplash && !note.noteSplashDisabled)
		{
			spawnNoteSplashOnNote(note);
		}

		if(!practiceMode && !cpuControlled) {
			songScore += score;
			if(!note.ratingDisabled)
			{
				songHits++;
				totalPlayed++;
				RecalculateRating();
			}

			if(ClientPrefs.scoreZoom)
			{
				if(scoreTxtTween != null) {
					scoreTxtTween.cancel();
				}
				scoreTxt.scale.x = 1.075;
				scoreTxt.scale.y = 1.075;
				scoreTxtTween = FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2, {
					onComplete: function(twn:FlxTween) {
						scoreTxtTween = null;
					}
				});
			}
		}

		var pixelShitPart1:String = "";
		var pixelShitPart2:String = '';

		if (PlayState.isPixelStage)
		{
			pixelShitPart1 = 'pixelUI/';
			pixelShitPart2 = '-pixel';
		}

		rating.loadGraphic(Paths.image(pixelShitPart1 + daRating.image + pixelShitPart2));
		rating.cameras = [camHUD];
		rating.screenCenter();
		rating.x = coolText.x - 40;
		rating.y -= 60;
		rating.acceleration.y = 550;
		rating.velocity.y -= FlxG.random.int(140, 175);
		rating.velocity.x -= FlxG.random.int(0, 10);
		rating.visible = (!ClientPrefs.hideHud && showRating);
		rating.x += ClientPrefs.comboOffset[0];
		rating.y -= ClientPrefs.comboOffset[1];

		var comboSpr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(pixelShitPart1 + 'combo' + pixelShitPart2));
		comboSpr.cameras = [camHUD];
		comboSpr.screenCenter();
		comboSpr.x = coolText.x;
		comboSpr.acceleration.y = 600;
		comboSpr.velocity.y -= 150;
		comboSpr.visible = (!ClientPrefs.hideHud && showCombo);
		comboSpr.x += ClientPrefs.comboOffset[0];
		comboSpr.y -= ClientPrefs.comboOffset[1];


		comboSpr.velocity.x += FlxG.random.int(1, 10);
		insert(members.indexOf(strumLineNotes), rating);

		if (!PlayState.isPixelStage)
		{
			rating.setGraphicSize(Std.int(rating.width * 0.7));
			rating.antialiasing = ClientPrefs.globalAntialiasing;
			comboSpr.setGraphicSize(Std.int(comboSpr.width * 0.7));
			comboSpr.antialiasing = ClientPrefs.globalAntialiasing;
		}
		else
		{
			rating.setGraphicSize(Std.int(rating.width * daPixelZoom * 0.85));
			comboSpr.setGraphicSize(Std.int(comboSpr.width * daPixelZoom * 0.85));
		}

		comboSpr.updateHitbox();
		rating.updateHitbox();

		var seperatedScore:Array<Int> = [];

		if(combo >= 1000) {
			seperatedScore.push(Math.floor(combo / 1000) % 10);
		}
		seperatedScore.push(Math.floor(combo / 100) % 10);
		seperatedScore.push(Math.floor(combo / 10) % 10);
		seperatedScore.push(combo % 10);

		var daLoop:Int = 0;
		for (i in seperatedScore)
		{
			var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.image(pixelShitPart1 + 'num' + Std.int(i) + pixelShitPart2));
			numScore.cameras = [camHUD];
			numScore.screenCenter();
			numScore.x = coolText.x + (43 * daLoop) - 90;
			numScore.y += 80;

			numScore.x += ClientPrefs.comboOffset[2];
			numScore.y -= ClientPrefs.comboOffset[3];

			if (!PlayState.isPixelStage)
			{
				numScore.antialiasing = ClientPrefs.globalAntialiasing;
				numScore.setGraphicSize(Std.int(numScore.width * 0.5));
			}
			else
			{
				numScore.setGraphicSize(Std.int(numScore.width * daPixelZoom));
			}
			numScore.updateHitbox();

			numScore.acceleration.y = FlxG.random.int(200, 300);
			numScore.velocity.y -= FlxG.random.int(140, 160);
			numScore.velocity.x = FlxG.random.float(-5, 5);
			numScore.visible = !ClientPrefs.hideHud;

			//if (combo >= 10 || combo == 0)
				insert(members.indexOf(strumLineNotes), numScore);

			FlxTween.tween(numScore, {alpha: 0}, 0.2, {
				onComplete: function(tween:FlxTween)
				{
					numScore.destroy();
				},
				startDelay: Conductor.crochet * 0.002
			});

			daLoop++;
		}
		/*
			trace(combo);
			trace(seperatedScore);
		 */

		coolText.text = Std.string(seperatedScore);
		// add(coolText);

		FlxTween.tween(rating, {alpha: 0}, 0.2, {
			startDelay: Conductor.crochet * 0.001
		});

		FlxTween.tween(comboSpr, {alpha: 0}, 0.2, {
			onComplete: function(tween:FlxTween)
			{
				coolText.destroy();
				comboSpr.destroy();

				rating.destroy();
			},
			startDelay: Conductor.crochet * 0.001
		});
	}

	private function onKeyPress(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);
		//trace('Pressed: ' + eventKey);

		if (!cpuControlled && startedCountdown && !paused && key > -1 && (FlxG.keys.checkStatus(eventKey, JUST_PRESSED) || ClientPrefs.controllerMode))
		{
			if(!boyfriend.stunned && generatedMusic && !endingSong)
			{
				//more accurate hit time for the ratings?
				var lastTime:Float = Conductor.songPosition;
				Conductor.songPosition = FlxG.sound.music.time;

				var canMiss:Bool = !ClientPrefs.ghostTapping;

				// heavily based on my own code LOL if it aint broke dont fix it
				var pressNotes:Array<Note> = [];
				//var notesDatas:Array<Int> = [];
				var notesStopped:Bool = false;

				var sortedNotesList:Array<Note> = [];
				notes.forEachAlive(function(daNote:Note)
				{
					if (daNote.canBeHit && daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit && !daNote.isSustainNote)
					{
						if(daNote.noteData == key)
						{
							sortedNotesList.push(daNote);
							//notesDatas.push(daNote.noteData);
						}
						canMiss = true;
					}
				});
				sortedNotesList.sort((a, b) -> Std.int(a.strumTime - b.strumTime));

				if (sortedNotesList.length > 0) {
					for (epicNote in sortedNotesList)
					{
						for (doubleNote in pressNotes) {
							if (Math.abs(doubleNote.strumTime - epicNote.strumTime) < 1) {
								if(modchartObjects.exists('note${doubleNote.ID}'))modchartObjects.remove('note${doubleNote.ID}');
								doubleNote.kill();
								notes.remove(doubleNote, true);
								doubleNote.destroy();
							} else
								notesStopped = true;
						}

						// eee jack detection before was not super good
						if (!notesStopped) {
							goodNoteHit(epicNote);
							pressNotes.push(epicNote);
						}

					}
				}
				else{
					callOnLuas('onGhostTap', [key]);
					if (canMiss) {
						noteMissPress(key);
						callOnLuas('noteMissPress', [key]);
					}
				}

				// I dunno what you need this for but here you go
				//									- Shubs

				// Shubs, this is for the "Just the Two of Us" achievement lol
				//									- Shadow Mario
				keysPressed[key] = true;

				//more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
				Conductor.songPosition = lastTime;
			}

			var spr:StrumNote = playerStrums.members[key];
			if(spr != null && spr.animation.curAnim.name != 'confirm')
			{
				spr.playAnim('pressed');
				spr.resetAnim = 0;
			}
			callOnLuas('onKeyPress', [key]);
		}
		//trace('pressed: ' + controlArray);
	}

	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);
		if(!cpuControlled && startedCountdown && !paused && key > -1)
		{
			var spr:StrumNote = playerStrums.members[key];
			if(spr != null)
			{
				spr.playAnim('static');
				spr.resetAnim = 0;
			}
			callOnLuas('onKeyRelease', [key]);
		}
		//trace('released: ' + controlArray);
	}

	private function getKeyFromEvent(key:FlxKey):Int
	{
		if(key != NONE)
		{
			for (i in 0...keysArray.length)
			{
				for (j in 0...keysArray[i].length)
				{
					if(key == keysArray[i][j])
					{
						return i;
					}
				}
			}
		}
		return -1;
	}

	// Hold notes
	private function keyShit():Void
	{
		// HOLDING
		var up = controls.NOTE_UP;
		var right = controls.NOTE_RIGHT;
		var down = controls.NOTE_DOWN;
		var left = controls.NOTE_LEFT;
		var controlHoldArray:Array<Bool> = [left, down, up, right];

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if(ClientPrefs.controllerMode)
		{
			var controlArray:Array<Bool> = [controls.NOTE_LEFT_P, controls.NOTE_DOWN_P, controls.NOTE_UP_P, controls.NOTE_RIGHT_P];
			if(controlArray.contains(true))
			{
				for (i in 0...controlArray.length)
				{
					if(controlArray[i])
						onKeyPress(new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, true, -1, keysArray[i][0]));
				}
			}
		}

		// FlxG.watch.addQuick('asdfa', upP);
		if (startedCountdown && !boyfriend.stunned && generatedMusic)
		{
			// rewritten inputs???
			notes.forEachAlive(function(daNote:Note)
			{
				// hold note functions
				if (daNote.isSustainNote && controlHoldArray[daNote.noteData] && daNote.canBeHit
				&& daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit) {
					goodNoteHit(daNote);
				}
			});

			if (controlHoldArray.contains(true) && !endingSong) {
				#if ACHIEVEMENTS_ALLOWED
				var achieve:String = checkForAchievement(['oversinging']);
				if (achieve != null) {
					startAchievement(achieve);
				}
				#end
			}
			else if (boyfriend.holdTimer > Conductor.stepCrochet * 0.0011 * boyfriend.singDuration && boyfriend.animation.curAnim.name.startsWith('sing') && !boyfriend.animation.curAnim.name.endsWith('miss'))
			{
				boyfriend.dance();
				//boyfriend.animation.curAnim.finish();
			}
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if(ClientPrefs.controllerMode)
		{
			var controlArray:Array<Bool> = [controls.NOTE_LEFT_R, controls.NOTE_DOWN_R, controls.NOTE_UP_R, controls.NOTE_RIGHT_R];
			if(controlArray.contains(true))
			{
				for (i in 0...controlArray.length)
				{
					if(controlArray[i])
						onKeyRelease(new KeyboardEvent(KeyboardEvent.KEY_UP, true, true, -1, keysArray[i][0]));
				}
			}
		}
	}

	function noteMiss(daNote:Note):Void { //You didn't hit the key and let it go offscreen, also used by Hurt Notes
		//Dupe note remove
		notes.forEachAlive(function(note:Note) {
			if (daNote != note && daNote.mustPress && daNote.noteData == note.noteData && daNote.isSustainNote == note.isSustainNote && Math.abs(daNote.strumTime - note.strumTime) < 1) {
				if(modchartObjects.exists('note${note.ID}'))modchartObjects.remove('note${note.ID}');
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
		});
		combo = 0;

		health -= daNote.missHealth * healthLoss;
		if(instakillOnMiss)
		{
			vocals.volume = 0;
			doDeathCheck(true);
		}

		//For testing purposes
		//trace(daNote.missHealth);
		songMisses++;
		vocals.volume = 0;
		if(!practiceMode) songScore -= 10;

		totalPlayed++;
		RecalculateRating();

		var char:Character = boyfriend;
		if(daNote.gfNote) {
			char = gf;
		}

		if(char != null && !daNote.noMissAnimation && char.hasMissAnimations)
		{
			var daAlt = '';
			if(daNote.noteType == 'Alt Animation') daAlt = '-alt';

			var animToPlay:String = singAnimations[Std.int(Math.abs(daNote.noteData))] + 'miss' + daAlt;
			char.playAnim(animToPlay, true);
		}

		callOnLuas('noteMiss', [notes.members.indexOf(daNote), daNote.noteData, daNote.noteType, daNote.isSustainNote, daNote.ID]);
	}

	function noteMissPress(direction:Int = 1):Void //You pressed a key when there was no notes to press for this key
	{
		if(ClientPrefs.ghostTapping) return; //fuck it

		if (!boyfriend.stunned)
		{
			health -= 0.05 * healthLoss;
			if(instakillOnMiss)
			{
				vocals.volume = 0;
				doDeathCheck(true);
			}

			if (combo > 5 && gf != null && gf.animOffsets.exists('sad'))
			{
				gf.playAnim('sad');
			}
			combo = 0;

			if(!practiceMode) songScore -= 10;
			if(!endingSong) {
				songMisses++;
			}
			totalPlayed++;
			RecalculateRating();

			FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
			// FlxG.sound.play(Paths.sound('missnote1'), 1, false);
			// FlxG.log.add('played imss note');

			/*boyfriend.stunned = true;

			// get stunned for 1/60 of a second, makes you able to
			new FlxTimer().start(1 / 60, function(tmr:FlxTimer)
			{
				boyfriend.stunned = false;
			});*/

			if(boyfriend.hasMissAnimations) {
				boyfriend.playAnim(singAnimations[Std.int(Math.abs(direction))] + 'miss', true);
			}
			vocals.volume = 0;
		}
		callOnLuas('noteMissPress', [direction]);
	}

	function opponentNoteHit(note:Note):Void
	{
		if (Paths.formatToSongPath(SONG.song) != 'tutorial')
			camZooming = true;

		if(note.noteType == 'Hey!' && dad.animOffsets.exists('hey')) {
			dad.playAnim('hey', true);
			dad.specialAnim = true;
			dad.heyTimer = 0.6;
		} else if(!note.noAnimation) {
			var altAnim:String = "";

			var curSection:Int = Math.floor(curStep / 16);
			if (SONG.notes[curSection] != null)
			{
				if (SONG.notes[curSection].altAnim || note.noteType == 'Alt Animation') {
					altAnim = '-alt';
				}
			}

			var char:Character = dad;
			var animToPlay:String = singAnimations[Std.int(Math.abs(note.noteData))] + altAnim;
			if(note.gfNote) {
				char = gf;
			}

			if(char != null)
			{
				char.playAnim(animToPlay, true);
				char.holdTimer = 0;
			}
		}

		if (SONG.needsVoices)
			vocals.volume = 1;

		var time:Float = 0.15;
		if(note.isSustainNote && !note.animation.curAnim.name.endsWith('end')) {
			time += 0.15;
		}
		StrumPlayAnim(true, Std.int(Math.abs(note.noteData)) % 4, time);
		note.hitByOpponent = true;

		//shakes the fuck out of your screen and hud -ekical
		// now it drains your health because fuck you -ekical
		if ((dad.curCharacter == 'hellron') || (dad.curCharacter == 'devilron'))
		{
			var multiplier:Float = 1;
			if (health >= 1)
				multiplier = 1;
			else
				multiplier = multiplier + ((1 - health));

			camHUD.shake(0.0055 * multiplier / 4, 0.15);
			if (curSong == 'Withered-Tweaked')
			{
				// he doesn't give a fuck in withered
				if (health > 0.03)
					health -= 0.0135;
			}
			else
			{
				FlxG.camera.shake(0.025 * multiplier / 4, 0.1);
				if (health > 0.03)
					health -= 0.014;
				else
					health = 0.02;
			}
		}
		if (dad.curCharacter == 'ron-usb' || dad.curCharacter == 'ateloron')
		{
			if (health > 0.03)
				health -= 0.014;
			else
				health = 0.02;
		}
		// NO MERE MORTAL CAN HANDLE THE POWERFUL DRIP RON
		if (dad.curCharacter == 'hellron-drippin')
		{
			var multiplier:Float = 1;
			if (health >= 1)
				multiplier = 1;
			else
				multiplier = multiplier + ((1 - health));
			FlxG.camera.shake(0.025 * multiplier / 4, 0.1);
			camHUD.shake(0.0055 * multiplier / 4, 0.15);
			if (health > 0.03)
				health -= 0.007;
			else
				health = 0.02;
			Lib.application.window.move(Lib.application.window.x + FlxG.random.int(-4, 4), Lib.application.window.y + FlxG.random.int(-4, 4));
		}

		callOnLuas('opponentNoteHit', [notes.members.indexOf(note), Math.abs(note.noteData), note.noteType, note.isSustainNote, note.ID]);

		if (!note.isSustainNote)
		{
			if(modchartObjects.exists('note${note.ID}'))modchartObjects.remove('note${note.ID}');
			note.kill();
			notes.remove(note, true);
			note.destroy();
		}
	}

	function goodNoteHit(note:Note):Void
	{
		if (!note.wasGoodHit)
		{
			if(cpuControlled && (note.ignoreNote || note.hitCausesMiss)) return;

			if (ClientPrefs.hitsoundVolume > 0 && !note.hitsoundDisabled)
			{
				FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.hitsoundVolume);
			}

			if(note.hitCausesMiss) {
				noteMiss(note);
				if(!note.noteSplashDisabled && !note.isSustainNote) {
					spawnNoteSplashOnNote(note);
				}

				if(!note.noMissAnimation)
				{
					switch(note.noteType) {
						case 'Hurt Note': //Hurt note
							if(boyfriend.animation.getByName('hurt') != null) {
								boyfriend.playAnim('hurt', true);
								boyfriend.specialAnim = true;
							}
					}
				}

				note.wasGoodHit = true;
				if (!note.isSustainNote)
				{
					if(modchartObjects.exists('note${note.ID}'))modchartObjects.remove('note${note.ID}');
					note.kill();
					notes.remove(note, true);
					note.destroy();
				}
				return;
			}

			if (!note.isSustainNote)
			{
				combo += 1;
				popUpScore(note);
				if(combo > 9999) combo = 9999;
			}
			if (!SCREWYOU)
			{
				// i just dont like how psych engine's health mechanics work
				if (note.isSustainNote)
					health += note.hitHealth * healthGain / 2;
				else
					health += note.hitHealth * healthGain * 4;
			}

			if(!note.noAnimation) {
				var daAlt = '';
				if(note.noteType == 'Alt Animation') daAlt = '-alt';

				var animToPlay:String = singAnimations[Std.int(Math.abs(note.noteData))];

				if(note.gfNote)
				{
					if(gf != null)
					{
						gf.playAnim(animToPlay + daAlt, true);
						gf.holdTimer = 0;
					}
				}
				else
				{
					boyfriend.playAnim(animToPlay + daAlt, true);
					boyfriend.holdTimer = 0;
				}

				if(note.noteType == 'Hey!') {
					if(boyfriend.animOffsets.exists('hey')) {
						boyfriend.playAnim('hey', true);
						boyfriend.specialAnim = true;
						boyfriend.heyTimer = 0.6;
					}

					if(gf != null && gf.animOffsets.exists('cheer')) {
						gf.playAnim('cheer', true);
						gf.specialAnim = true;
						gf.heyTimer = 0.6;
					}
				}
			}

			if(cpuControlled) {
				var time:Float = 0.15;
				if(note.isSustainNote && !note.animation.curAnim.name.endsWith('end')) {
					time += 0.15;
				}
				StrumPlayAnim(false, Std.int(Math.abs(note.noteData)) % 4, time);
			} else {
				playerStrums.forEach(function(spr:StrumNote)
				{
					if (Math.abs(note.noteData) == spr.ID)
					{
						spr.playAnim('confirm', true);
					}
				});
			}
			note.wasGoodHit = true;
			vocals.volume = 1;

			var isSus:Bool = note.isSustainNote; //GET OUT OF MY HEAD, GET OUT OF MY HEAD, GET OUT OF MY HEAD
			var leData:Int = Math.round(Math.abs(note.noteData));
			var leType:String = note.noteType;
			callOnLuas('goodNoteHit', [notes.members.indexOf(note), leData, leType, isSus, note.ID]);

			if (!note.isSustainNote)
			{
				if(modchartObjects.exists('note${note.ID}'))modchartObjects.remove('note${note.ID}');
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
		}
	}

	function spawnNoteSplashOnNote(note:Note) {
		if(ClientPrefs.noteSplashes && note != null) {
			var strum:StrumNote = playerStrums.members[note.noteData];
			if(strum != null) {
				spawnNoteSplash(strum.x, strum.y, note.noteData, note);
			}
		}
	}

	public function spawnNoteSplash(x:Float, y:Float, data:Int, ?note:Note = null) {
		var skin:String = 'noteSplashes';
		if(PlayState.SONG.splashSkin != null && PlayState.SONG.splashSkin.length > 0) skin = PlayState.SONG.splashSkin;

		var hue:Float = ClientPrefs.arrowHSV[data % 4][0] / 360;
		var sat:Float = ClientPrefs.arrowHSV[data % 4][1] / 100;
		var brt:Float = ClientPrefs.arrowHSV[data % 4][2] / 100;
		if(note != null) {
			skin = note.noteSplashTexture;
			hue = note.noteSplashHue;
			sat = note.noteSplashSat;
			brt = note.noteSplashBrt;
		}

		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.setupNoteSplash(x, y, data, skin, hue, sat, brt);
		grpNoteSplashes.add(splash);
	}

	var fastCarCanDrive:Bool = true;

	function resetFastCar():Void
	{
		fastCar.x = -12600;
		fastCar.y = FlxG.random.int(140, 250);
		fastCar.velocity.x = 0;
		fastCarCanDrive = true;
	}

	var carTimer:FlxTimer;
	function fastCarDrive()
	{
		//trace('Car drive');
		FlxG.sound.play(Paths.soundRandom('carPass', 0, 1), 0.7);

		fastCar.velocity.x = (FlxG.random.int(170, 220) / FlxG.elapsed) * 3;
		fastCarCanDrive = false;
		carTimer = new FlxTimer().start(2, function(tmr:FlxTimer)
		{
			resetFastCar();
			carTimer = null;
		});
	}

	var trainMoving:Bool = false;
	var trainFrameTiming:Float = 0;

	var trainCars:Int = 8;
	var trainFinishing:Bool = false;
	var trainCooldown:Int = 0;

	function trainStart():Void
	{
		trainMoving = true;
		if (!trainSound.playing)
			trainSound.play(true);
	}

	var startedMoving:Bool = false;

	function updateTrainPos():Void
	{
		if (trainSound.time >= 4700)
		{
			startedMoving = true;
			if (gf != null)
			{
				gf.playAnim('hairBlow');
				gf.specialAnim = true;
			}
		}

		if (startedMoving)
		{
			phillyTrain.x -= 400;

			if (phillyTrain.x < -2000 && !trainFinishing)
			{
				phillyTrain.x = -1150;
				trainCars -= 1;

				if (trainCars <= 0)
					trainFinishing = true;
			}

			if (phillyTrain.x < -4000 && trainFinishing)
				trainReset();
		}
	}

	function trainReset():Void
	{
		if(gf != null)
		{
			gf.danced = false; //Sets head to the correct position once the animation ends
			gf.playAnim('hairFall');
			gf.specialAnim = true;
		}
		phillyTrain.x = FlxG.width + 200;
		trainMoving = false;
		// trainSound.stop();
		// trainSound.time = 0;
		trainCars = 8;
		trainFinishing = false;
		startedMoving = false;
	}

	function lightningStrikeShit():Void
	{
		FlxG.sound.play(Paths.soundRandom('thunder_', 1, 2));
		if(!ClientPrefs.lowQuality) halloweenBG.animation.play('halloweem bg lightning strike');

		lightningStrikeBeat = curBeat;
		lightningOffset = FlxG.random.int(8, 24);

		if(boyfriend.animOffsets.exists('scared')) {
			boyfriend.playAnim('scared', true);
		}

		if(gf != null && gf.animOffsets.exists('scared')) {
			gf.playAnim('scared', true);
		}

		if(ClientPrefs.camZooms) {
			FlxG.camera.zoom += 0.015;
			camHUD.zoom += 0.03;

			if(!camZooming) { //Just a way for preventing it to be permanently zoomed until Skid & Pump hits a note
				FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, 0.5);
				FlxTween.tween(camHUD, {zoom: 1}, 0.5);
			}
		}

		if(ClientPrefs.flashing) {
			halloweenWhite.alpha = 0.4;
			FlxTween.tween(halloweenWhite, {alpha: 0.5}, 0.075);
			FlxTween.tween(halloweenWhite, {alpha: 0}, 0.25, {startDelay: 0.15});
		}
	}

	function killHenchmen():Void
	{
		if(!ClientPrefs.lowQuality && ClientPrefs.violence && curStage == 'limo') {
			if(limoKillingState < 1) {
				limoMetalPole.x = -400;
				limoMetalPole.visible = true;
				limoLight.visible = true;
				limoCorpse.visible = false;
				limoCorpseTwo.visible = false;
				limoKillingState = 1;

				#if ACHIEVEMENTS_ALLOWED
				Achievements.henchmenDeath++;
				FlxG.save.data.henchmenDeath = Achievements.henchmenDeath;
				var achieve:String = checkForAchievement(['roadkill_enthusiast']);
				if (achieve != null) {
					startAchievement(achieve);
				} else {
					FlxG.save.flush();
				}
				FlxG.log.add('Deaths: ' + Achievements.henchmenDeath);
				#end
			}
		}
	}

	function resetLimoKill():Void
	{
		if(curStage == 'limo') {
			limoMetalPole.x = -500;
			limoMetalPole.visible = false;
			limoLight.x = -500;
			limoLight.visible = false;
			limoCorpse.x = -500;
			limoCorpse.visible = false;
			limoCorpseTwo.x = -500;
			limoCorpseTwo.visible = false;
		}
	}

	var tankX:Float = 400;
	var tankSpeed:Float = FlxG.random.float(5, 7);
	var tankAngle:Float = FlxG.random.int(-90, 45);

	function moveTank(?elapsed:Float = 0):Void
	{
		if(!inCutscene)
		{
			tankAngle += elapsed * tankSpeed;
			tankGround.angle = tankAngle - 90 + 15;
			tankGround.x = tankX + 1500 * Math.cos(Math.PI / 180 * (1 * tankAngle + 180));
			tankGround.y = 1300 + 1100 * Math.sin(Math.PI / 180 * (1 * tankAngle + 180));
		}
	}

	private var preventLuaRemove:Bool = false;
	override function destroy() {
		preventLuaRemove = true;
		for (i in 0...luaArray.length) {
			luaArray[i].call('onDestroy', []);
			luaArray[i].stop();
		}
		luaArray = [];

		if(!ClientPrefs.controllerMode)
		{
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}
		super.destroy();
	}

	public static function cancelMusicFadeTween() {
		if(FlxG.sound.music.fadeTween != null) {
			FlxG.sound.music.fadeTween.cancel();
		}
		FlxG.sound.music.fadeTween = null;
	}

	public function removeLua(lua:FunkinLua) {
		if(luaArray != null && !preventLuaRemove) {
			luaArray.remove(lua);
		}
	}

	var daNoteMove:Bool =false;
	var daNoteMoveH:Bool =false;
	var daNoteMoveH2:Bool =false;
	var daNoteMoveH3:Bool =false;
	var daNoteMoveH4:Bool =false;
	var daNoteMoveH5:Bool =false;

	var lastStepHit:Int = -1;
	override function stepHit()
	{
		super.stepHit();
		if (Math.abs(FlxG.sound.music.time - (Conductor.songPosition - Conductor.offset)) > 20
			|| (SONG.needsVoices && Math.abs(vocals.time - (Conductor.songPosition - Conductor.offset)) > 20))
		{
			resyncVocals();
		}

		if(curStep == lastStepHit) {
			return;
		}

		if (curSong == 'Ayo')
		{
			switch (curStep)
			{
				case 892:
					bruh();
				case 1148:
					FlxTween.tween(FlxG.camera, {zoom: 1.5}, 0.4, {ease: FlxEase.expoOut,});
			}
		}
		
		if 	(curSong == 'blizzard')
			{	
				healthBarBG.alpha = 0;
				healthBar.alpha = 0;
				iconP1.visible = true;
				iconP2.visible = true;
				iconP2.alpha = (2-(health)-0.25)/2+0.2;
				iconP1.alpha = (health-0.25)/2+0.2;
				Estatic.alpha = (((2-health)/3)+0.2);
				if ((curStep >= 256))
				{
					snowemitter.x = FlxG.camera.scroll.x;
					snowemitter.y = FlxG.camera.scroll.y-40;
				}
				else
					snowemitter.x = 9999;
				switch (curStep)
				{
					case 240:
						defaultCamZoom += 0.1;
					case 256:
						FlxG.camera.flash(FlxColor.WHITE, 0.2);
						blackeffect.alpha = 0;
						bgbleffect.alpha = 0;
						fx.alpha = 0;
						defaultCamZoom += 0.1;
				}		
				if ((curStep >= 256) && (curStep <= 512))
				{
					FlxG.camera.shake(0.01, 0.1);
					camHUD.shake(0.001, 0.15);		
					if (curStep == 256)
					{
						FlxTween.angle(satan, 0, 359.99, 1.5, { 
							ease: FlxEase.quadIn, 
							onComplete: function(twn:FlxTween) 
							{
								FlxTween.angle(satan, 0, 359.99, 0.75, { type: FlxTween.LOOPING } );
							}} 
						);
					}
					if (health > 0.2)
						health -= 0.05;
				}
				else
				{
					if ((curStep == 1297) || (curStep == 614))
						FlxTween.cancelTweensOf(satan);
					if (satan.angle != 0)
						FlxTween.angle(satan, satan.angle, 359.99, 0.5, {ease: FlxEase.quadIn});
					if (fx.alpha > 0.3)
						fx.alpha -= 0.05;
				}
			}

		if 	(curSong == 'pretty-wacky')
		{	
			switch (curStep)
			{
				case 120:
					defaultCamZoom += 0.1;
				case 128:
					FlxG.camera.flash(FlxColor.BLACK, 0.5);
			}	
			if (curStep >= 128)
			{
				snowemitter.x = FlxG.camera.scroll.x;
				snowemitter.y = FlxG.camera.scroll.y+FlxG.height+40;
				if (curStep % 4 == 0)
				{
					if (curStep % 8 == 0)
					{
						camGame.angle = -2;
						camHUD.angle = -4;
					}
					else
					{
						camGame.angle = 2;
						camHUD.angle = 4;
					}
					FlxTween.tween(camGame, {angle: 0}, 0.4, {ease: FlxEase.circOut});
					FlxTween.tween(camHUD, {angle: 0}, 0.4, {ease: FlxEase.circOut});
				}
			}
			else
			{
				snowemitter.x = 9999;
			}
		}

		if (curSong == 'Bloodshed') 
		{
			healthBarBG.alpha = 0;
			healthBar.alpha = 0;
			iconP1.visible = true;
			iconP2.visible = true;
			iconP2.alpha = (2-(health)-0.25)/2+0.2;
			iconP1.alpha = (health-0.25)/2+0.2;
			switch (curStep) {
				case 0:
					ClientPrefs.downScroll = false;
					strumLine.y = 50;
				case 259:
					defaultCamZoom = 0.95;
				case 341:
					defaultCamZoom = 1.05;
				case 356:
					defaultCamZoom = 1.15;
				case 372:
					defaultCamZoom = 1.25;
				case 389:
					defaultCamZoom = 0.85;
				case 518:
					defaultCamZoom = 0.85;
					satan.angle = 0;
					FlxTween.tween(camHUD, {angle: 20}, 1, {ease: FlxEase.quadInOut, type: BACKWARD});
				case 776:
					defaultCamZoom = 0.9;
					FlxTween.tween(firebg, {alpha: 1}, 1, {ease: FlxEase.quadInOut});
				case 792:
					defaultCamZoom = 0.95;
				case 808:
					defaultCamZoom = 1;
				case 824:
					defaultCamZoom = 1.05;
				case 840:
					defaultCamZoom = 1.1;
				case 856:
					defaultCamZoom = 1.15;
				case 872:
					defaultCamZoom = 1.2;
				case 888:
					defaultCamZoom = 1.25;
				case 904:
					defaultCamZoom = 0.95;
				case 920:
					defaultCamZoom = 1.05;
				case 936:
					defaultCamZoom = 1.15;
				case 952:
					defaultCamZoom = 1.25;
				case 968:
					defaultCamZoom = 0.95;
				case 984:
					defaultCamZoom = 1.05;
				case 1000:
					defaultCamZoom = 1.15;
				case 1016:
					defaultCamZoom = 1.25;
				case 1150:
					camHUD.angle = 0;
					camHUD.alpha = 1;
			}
			if ((curStep >= 259) && (curStep <= 518))
			{
				if (fx.alpha < 0.6)
					fx.alpha += 0.05;			
				if (curStep == 260)
				{
					FlxTween.angle(satan, 0, 359.99, 1.5, { 
						ease: FlxEase.quadIn, 
						onComplete: function(twn:FlxTween) 
						{
							FlxTween.angle(satan, 0, 359.99, 0.75, { type: FlxTweenType.LOOPING } );
						}} 
					);
				}
				FlxG.camera.shake(0.01, 0.1);
				camHUD.shake(0.001, 0.15);
			}
			else if ((curStep >= 776) && (curStep <= 1070))
			{
				if (fx.alpha > 0)
					fx.alpha -= 0.05;
				if (curStep == 777)
				{
					FlxTween.angle(satan, 0, 359.99, 0.75, { 
						ease: FlxEase.quadIn, 
						onComplete: function(twn:FlxTween) 
						{
							FlxTween.angle(satan, 0, 359.99, 0.35, { type: FlxTweenType.LOOPING } );
						}} 
					);
				}
				FlxG.camera.shake(0.015, 0.1);
				camHUD.shake(0.0015, 0.15);
			}
			else
			{
				if ((curStep == 1071) || (curStep == 519))
					FlxTween.cancelTweensOf(satan);
				if (satan.angle != 0)
					FlxTween.angle(satan, satan.angle, 359.99, 0.5, {ease: FlxEase.quadIn});
				if (fx.alpha > 0.3)
					fx.alpha -= 0.05;
			}
			Estatic.alpha = (((2-health)/3)+0.2);
		}

		if (curSong == 'bloodbath') // hi it me chromasen and im proud of this code because i made it:)
		{
			SCREWYOU = true;
			botplayTxt.visible = true;
			if (!ClientPrefs.gameplaySettings['botplay'])
			{
				botplayTxt.text = "UNFORGIVING INPUT ENABLED!";
				botplayTxt.screenCenter(X);
				botplayTxt.y = scoreTxt.y - 100;
			}
            healthBarBG.alpha = 0;
            healthBar.alpha = 0;
            scoreTxt.alpha = 0;
            iconP1.visible = true;
            iconP2.visible = true;
            iconP2.alpha = (2-(health)-0.25)/2+0.2;
            iconP1.alpha = (health-0.25)/2+0.2;
            switch (curStep)
            {
                case 128: defaultCamZoom = 0.9;
                case 253: defaultCamZoom = 1.2;
                case 409: defaultCamZoom = 1.1;
                case 413: defaultCamZoom = 0.95;    
                case 513: defaultCamZoom = 0.85;
                case 518: defaultCamZoom = 0.9;
                case 528: defaultCamZoom = 0.95;
                case 535: defaultCamZoom = 1;
                case 540: defaultCamZoom = 0.9;
                case 575: defaultCamZoom = 1.1;
                case 582: defaultCamZoom = 1.05;
                case 592: defaultCamZoom = 0.98;
                case 599: defaultCamZoom = 1.15;
                case 639: defaultCamZoom = 0.85;
                case 768:
                     defaultCamZoom = 1.1;
                     FlxTween.tween(firebg, {alpha: 1}, 1, {ease: FlxEase.quadInOut});
			case 1039: defaultCamZoom = 0.85; // shit ton of code because yeah
		}
		if ((curStep >= 254) && (curStep <= 518))
		{
			if (fx.alpha < 0.6)
				fx.alpha += 0.05;            
			if (curStep == 256)
			{
				FlxTween.angle(satan, 0, 359.99, 1.5, { 
					ease: FlxEase.quadIn, 
					onComplete: function(twn:FlxTween) 
					{
						FlxTween.angle(satan, 0, 359.99, 0.75, { type: FlxTweenType.LOOPING } );
					}} 
				);
			}
			FlxG.camera.shake(0.01, 0.1);
			camHUD.shake(0.001, 0.15);
		}
		else if ((curStep >= 768) && (curStep <= 1040))
			{
				if (fx.alpha > 0)
					fx.alpha -= 0.05;
				if (curStep == 768)
				{
					FlxTween.angle(satan, 0, 359.99, 0.75, { 
						ease: FlxEase.quadIn, 
						onComplete: function(twn:FlxTween) 
						{
							FlxTween.angle(satan, 0, 359.99, 0.35, { type: FlxTweenType.LOOPING } );
						}} 
					);
				}
				FlxG.camera.shake(0.015, 0.1);
				camHUD.shake(0.0015, 0.15);
			}
		else
			{
				if ((curStep == 519) || (curStep == 1041))
					FlxTween.cancelTweensOf(satan);
				if (satan.angle != 0)
					FlxTween.angle(satan, satan.angle, 359.99, 0.5, {ease: FlxEase.quadIn});
				if (fx.alpha > 0.3)
					fx.alpha -= 0.05;
			}
			Estatic.alpha = (((2-health)/3)+0.2);
		}

		if (curSong == 'Bleeding') {
			healthBarBG.alpha = 0;
			healthBar.alpha = 0;
			iconP1.visible = true;
			iconP2.visible = true;
			iconP2.alpha = (2-(health)-0.25)/2+0.2;
			iconP1.alpha = (health-0.25)/2+0.2;
			switch (curStep)
			{
				case 256:
					var xx = dad.x;
					var yy = dad.y;
					triggerEventNote('Change Character', 'dad', 'hellron-drippin');
					dad.x = xx-80;
					dad.y = yy-200;
					defaultCamZoom += 0.1;
					SCREWYOU = true;
					botplayTxt.visible = true;
					botplayTxt.y = scoreTxt.y - 100;
					if (!ClientPrefs.gameplaySettings['botplay'])
					{
						botplayTxt.text = "UNFORGIVING INPUT ENABLED!";
						botplayTxt.screenCenter(X);
					}
				case 384:
					defaultCamZoom += 0.15;
				case 512:
					SCREWYOU = false;
					if (!ClientPrefs.gameplaySettings['botplay'])
						botplayTxt.visible = false;
					var xx = dad.x;
					var yy = dad.y;
					triggerEventNote('Change Character', 'dad', 'hellron');
					dad.x = xx+80;
					dad.y = yy+200;
					defaultCamZoom -= 0.25;
				case 664:
					defaultCamZoom += 0.3;
				case 672:
					defaultCamZoom -= 0.3;
				case 768:
					SCREWYOU = true;
					botplayTxt.visible = true;
					if (!ClientPrefs.gameplaySettings['botplay'])
						botplayTxt.text = "UNFORGIVING INPUT ENABLED!";
					var xx = dad.x;
					var yy = dad.y;
					triggerEventNote('Change Character', 'dad', 'hellron-drippin');
					dad.x = xx-80;
					dad.y = yy-200;
					FlxTween.tween(firebg, {alpha: 1}, 1, {ease: FlxEase.quadInOut});
					defaultCamZoom += 0.1;
				case 832:
					defaultCamZoom += 0.1;
				case 896:
					defaultCamZoom += 0.1;
				case 1024:
					defaultCamZoom += 0.1;
				case 1040:
					defaultCamZoom -= 0.2;
				case 1168:
					defaultCamZoom -= 0.1;
				case 1296:
					FlxTween.tween(firebg, {alpha: 0}, 1, {ease: FlxEase.quadInOut});
					defaultCamZoom -= 0.1;
					SCREWYOU = false;
					if (!ClientPrefs.gameplaySettings['botplay'])
						botplayTxt.visible = false;
			}
			if ((curStep >= 256) && (curStep <= 512))
			{
				if (fx.alpha < 0.6)
					fx.alpha += 0.05;			
				if (curStep == 256)
				{
					FlxTween.angle(satan, 0, 359.99, 1.5, { 
						ease: FlxEase.quadIn, 
						onComplete: function(twn:FlxTween) 
						{
							FlxTween.angle(satan, 0, 359.99, 0.75, { type: FlxTweenType.LOOPING } );
						}} 
					);
				}
				FlxG.camera.shake(0.01, 0.1);
				camHUD.shake(0.001, 0.15);
			}
			else if ((curStep >= 768) && (curStep <= 1296))
			{
				if (fx.alpha > 0)
					fx.alpha -= 0.05;
				if (curStep == 768)
				{
					FlxTween.angle(satan, 0, 359.99, 0.75, { 
						ease: FlxEase.quadIn, 
						onComplete: function(twn:FlxTween) 
						{
							FlxTween.angle(satan, 0, 359.99, 0.35, { type: FlxTweenType.LOOPING } );
						}} 
					);
				}
				FlxG.camera.shake(0.015, 0.1);
				camHUD.shake(0.0015, 0.15);
			}
			else
			{
				if ((curStep == 1297) || (curStep == 614))
					FlxTween.cancelTweensOf(satan);
				if (satan.angle != 0)
					FlxTween.angle(satan, satan.angle, 359.99, 0.5, {ease: FlxEase.quadIn});
				if (fx.alpha > 0.3)
					fx.alpha -= 0.05;
			}
			Estatic.alpha = (((2-health)/3)+0.2);
		}

		switch(SONG.song.toLowerCase())
		{
			case 'bloodshed': 
				if(curStep == 129)
				{
					funnywindowsmall = true;
					for (i in 0...4)
					{ 
						var member = strumLineNotes.members[i];
						FlxTween.tween(strumLineNotes.members[i], { x: defaultStrumX[i]+ 1250 ,angle: 360}, 1);
						defaultStrumX[i] += 1250;
					}
					for (i in 4...8)
					{ 
						var member = strumLineNotes.members[i];
						FlxTween.tween(strumLineNotes.members[i], { x: defaultStrumX[i] - 275,angle: 360}, 1);
						defaultStrumX[i] -= 275;
					}
				}
				if(curStep == 258)
				{
					daNoteMoveH2 = true;
					funnywindowsmall = false;
					funnywindow = true;
				}
				if(curStep == 389)
				{
					daNoteMoveH2 = false;
					daNoteMoveH3 = true;
				}
				if(curStep == 518)
				{
					daNoteMoveH3 = false;
					daNoteMoveH4 = true;
					funnywindow = false;
					funnywindowsmall = true;
				}
				if(curStep == 776)
				{
					funnywindowsmall = false;
					funnywindow = true;
					daNoteMoveH4 = false;
					daNoteMoveH5 = true;
				}
				if(curStep >= 1053)
				{
					NOMOREFUNNY = true;
					funnywindow = false;
					funnywindowsmall = false;
					if(PlayState.instance.camHUD.alpha > 0 ){
						PlayState.instance.camHUD.alpha  -= 0.05;
					}
				}
		}

		if (curSong == 'Holy-Shit-Dave-Fnf')
		{
			switch (curStep)
			{
				case 352:
					defaultCamZoom = 1;
				case 368:
					defaultCamZoom = 1.2;
				case 384:
					FlxG.camera.flash(FlxColor.WHITE, 0.2);
				case 400:
					defaultCamZoom = 1.5;
				case 448:
					defaultCamZoom = 0.9;
			}

			if (curStep >= 384 && curStep < 400)
				dad.playAnim('um');
			else if (curStep >= 400 && curStep < 448)
				dad.playAnim('err');
		}

		if (curSong == 'Trojan-Virus')
		{
			switch (curStep)
			{
				case 384:
					FlxTween.tween(cloudsa, {alpha: 0}, 1, {ease: FlxEase.quadIn});
					FlxTween.tween(witheredRa, {alpha: 0}, 1, {ease: FlxEase.quadIn});
					FlxTween.tween(bgLol, {alpha: 0}, 1, {ease: FlxEase.quadIn});
					camHUD.shake(0.002);
					defaultCamZoom += 0.2;
				case 640:
					defaultCamZoom -= 0.2;
				case 1584:
					var budjet = new FlxSprite(0, 0);
					budjet.loadGraphic(Paths.image('ron/budjet'));
					budjet.screenCenter();
					budjet.cameras = [camHUD];
					add(budjet);
					dad.visible = false;
					defaultCamZoom = 1;
					FlxTween.tween(FlxG.camera, {zoom: 1}, 0.4, {ease: FlxEase.expoOut,});
			}
			if ((curStep >= 384) && (curStep <= 640))
				FlxG.camera.shake(0.00625, 0.1);

			camHUD.shake(0.00125, 0.15);
		}

		if (curSong == 'Withered-Tweaked')
		{
			witheredClouds.x += 2;
			switch (curStep)
			{
				case 16 | 32 | 48 | 64 | 80 | 96 | 112:
					FlxG.camera.zoom += 0.02;
					defaultCamZoom -= 0.02;
				case 127:
					defaultCamZoom = 0.75;
				case 128 | 260 | 320 | 336 | 368:
					defaultCamZoom += 0.1;
				case 383:
					defaultCamZoom -= 0.5;
				case 448 | 464 | 480 | 496:
					defaultCamZoom += 0.12;
				case 512:
					defaultCamZoom -= 0.5;
				// drop
				case 576 | 592 | 608 | 624:
					defaultCamZoom += 0.12;
				case 640:
					defaultCamZoom -= 0.5;
				case 688:
					defaultCamZoom += 0.5;
				case 704:
					defaultCamZoom -= 0.5;
				case 720 | 736 | 752 | 760:
					defaultCamZoom += 0.12;
				case 768:
					defaultCamZoom -= 0.5;
					FlxTween.tween(fxtwo, {alpha: 0.5}, 1, {ease: FlxEase.expoOut,});
				case 880:
					defaultCamZoom += 0.5;
				case 896:
					defaultCamZoom -= 0.4;
				case 1024:
					defaultCamZoom += 0.1;
				case 1120:
					FlxG.camera.setFilters([ShadersHandler.chromaticAberration]);
					camHUD.setFilters([ShadersHandler.chromaticAberration]);
					dad.x += 80;
					dad.y += 80;
					defaultCamZoom += 0.3;
					FlxTween.tween(fxtwo, {alpha: 1}, 8, {ease: FlxEase.expoOut,});
					for (i in 0...4)
					{
						var member = strumLineNotes.members[i];
						FlxTween.tween(strumLineNotes.members[i], {x: defaultStrumX[i] + 1250, angle: 360}, 2);
						defaultStrumX[i] += 1250;
					}
					for (i in 4...8)
					{
						var member = strumLineNotes.members[i];
						FlxTween.tween(strumLineNotes.members[i], {x: defaultStrumX[i] - 275, angle: 360}, 2);
						defaultStrumX[i] -= 275;
					}
				case 1216 | 1232 | 1248 | 1280:
					defaultCamZoom += 0.05;
				case 1344 | 1376:
					defaultCamZoom -= 0.2;
				case 1408:
					defaultCamZoom = 0.75;
					FlxTween.tween(fxtwo, {alpha: 0}, 1, {ease: FlxEase.expoOut,});
			}
		}

		if (curSong == 'Ron') 
		{
			if (curStep == 326 || curStep == 590 || curStep == 606 || curStep == 638 || curStep == 751 || curStep == 754)
				FlxTween.tween(FlxG.camera, {zoom: 1.5}, 0.4, {ease: FlxEase.expoOut,});
		}

		lastStepHit = curStep;
		setOnLuas('curStep', curStep);

		if (curSong.toLowerCase() == 'bloodbath')
		{
			if (curStep == 258)
			{
				windowmove = true;
				for (i in 0...4)
				{
					FlxTween.tween(strumLineNotes.members[i], {x: strumLineNotes.members[i].x + 1250, angle: strumLineNotes.members[i].angle + 359}, 1, {ease: FlxEase.linear, onComplete: function(w:FlxTween)
						setDefault(i)});
				}
				for (i in 4...8)
				{
					FlxTween.tween(strumLineNotes.members[i], {x: strumLineNotes.members[i].x - 275, angle: strumLineNotes.members[i].angle}, 1, {
						ease: FlxEase.linear,
						onComplete: function(w:FlxTween) setDefault(i)
					});
				}
				cameramove = true;
			}
			if (curStep == 518)
			{
				windowmove = false;
				cameramove = false;
			}
			if (curStep == 768)
			{
				windowmove = true;
				cameramove = true;
			}
		}

		if (curSong.toLowerCase() == 'bleeding')
		{
			if (curStep == 256)
			{
				windowmove = true;
				cameramove = true;
			}
			if (curStep == 512)
			{
				windowmove = false;
				cameramove = false;
			}
			if (curStep == 768)
			{
				for (i in 0...4)
				{
					FlxTween.tween(strumLineNotes.members[i], {x: strumLineNotes.members[i].x - 1250, angle: strumLineNotes.members[i].angle + 359}, 1, {ease: FlxEase.linear, onComplete: function(w:FlxTween)
						setDefault(i)});
				}
				for (i in 4...8)
				{
					FlxTween.tween(strumLineNotes.members[i], {x: strumLineNotes.members[i].x - 300, angle: strumLineNotes.members[i].angle}, 1, {
						ease: FlxEase.linear,
						onComplete: function(w:FlxTween) setDefault(i)
					});
				}
				windowmove = true;
				cameramove = false;
				intensecameramove = true;
			}
			if (curStep == 896)
			{
				intensecameramove = false;
				WHATTHEFUCK = true;
			}
			if (curStep == 1024)
			{
				WHATTHEFUCK = false;
				WTFending = true;
			}
			if (curStep == 1040)
				WTFending = false;
			if (curStep == 1296)
			{
				windowmove = false;
				cameramove = false;
				intensecameramove = false;
			}
		}

		if (curSong.toLowerCase() == 'trojan-virus')
		{
			if (curStep == 384)
				moveing = true;
			if (curStep == 640)
				moveing = false;
		}

		callOnLuas('onStepHit', []);
	}

	var lightningStrikeBeat:Int = 0;
	var lightningOffset:Int = 8;

	var lastBeatHit:Int = -1;

	override function beatHit()
	{
		super.beatHit();

		if(lastBeatHit >= curBeat) {
			//trace('BEAT HIT: ' + curBeat + ', LAST HIT: ' + lastBeatHit);
			return;
		}

		if (generatedMusic)
		{
			notes.sort(FlxSort.byY, ClientPrefs.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
		}

		if (SONG.notes[Math.floor(curStep / 16)] != null)
		{
			if (SONG.notes[Math.floor(curStep / 16)].changeBPM)
			{
				Conductor.changeBPM(SONG.notes[Math.floor(curStep / 16)].bpm);
				//FlxG.log.add('CHANGED BPM!');
				setOnLuas('curBpm', Conductor.bpm);
				setOnLuas('crochet', Conductor.crochet);
				setOnLuas('stepCrochet', Conductor.stepCrochet);
			}
			setOnLuas('mustHitSection', SONG.notes[Math.floor(curStep / 16)].mustHitSection);
			setOnLuas('altAnim', SONG.notes[Math.floor(curStep / 16)].altAnim);
			setOnLuas('gfSection', SONG.notes[Math.floor(curStep / 16)].gfSection);
			// else
			// Conductor.changeBPM(SONG.bpm);
		}
		// FlxG.log.add('change bpm' + SONG.notes[Std.int(curStep / 16)].changeBPM);

		if (generatedMusic && PlayState.SONG.notes[Std.int(curStep / 16)] != null && !endingSong && !isCameraOnForcedPos)
		{
			moveCameraSection(Std.int(curStep / 16));
		}
		if (camZooming && FlxG.camera.zoom < 1.35 && ClientPrefs.camZooms && curBeat % 4 == 0)
		{
			FlxG.camera.zoom += 0.015 * camZoomingMult;
			camHUD.zoom += 0.03 * camZoomingMult;
		}

		iconP1.scale.set(1.2, 1.2);
		iconP2.scale.set(1.2, 1.2);

		iconP1.updateHitbox();
		iconP2.updateHitbox();

		if (gf != null && curBeat % Math.round(gfSpeed * gf.danceEveryNumBeats) == 0 && gf.animation.curAnim != null && !gf.animation.curAnim.name.startsWith("sing") && !gf.stunned)
		{
			gf.dance();
		}
		if (curBeat % boyfriend.danceEveryNumBeats == 0 && boyfriend.animation.curAnim != null && !boyfriend.animation.curAnim.name.startsWith('sing') && !boyfriend.stunned)
		{
			boyfriend.dance();
		}
		if (curBeat % dad.danceEveryNumBeats == 0 && dad.animation.curAnim != null && !dad.animation.curAnim.name.startsWith('sing') && !dad.stunned)
		{
			dad.dance();
		}

		switch (curStage)
		{
			case 'mall':
				if(!ClientPrefs.lowQuality) {
					upperBoppers.dance(true);
				}

				if(heyTimer <= 0) bottomBoppers.dance(true);
				santa.dance(true);
		}

		if (curSong == 'Ron')
		{
			if (curBeat == 29)
				FlxTween.tween(FlxG.camera, {zoom: 1.5}, 1.3, {ease: FlxEase.expoOut,});
			else if (curBeat == 172)
				FlxTween.tween(FlxG.camera, {zoom: 1.5}, 0.4, {ease: FlxEase.expoOut,});
			//else
			//	FlxG.camera.follow(camFollowPos, LOCKON, 0.04 * (30 / (cast(Lib.current.getChildAt(0), Main)).getFPS()));
		}

		lastBeatHit = curBeat;

		setOnLuas('curBeat', curBeat); //DAWGG?????
		callOnLuas('onBeatHit', []);
	}

	public var closeLuas:Array<FunkinLua> = [];
	public function callOnLuas(event:String, args:Array<Dynamic>, ignoreStops=false, ?exclusions:Array<String>):Dynamic {
		var returnVal:Dynamic = FunkinLua.Function_Continue;
		#if LUA_ALLOWED
		if(exclusions == null) exclusions = [];
		for (i in 0...luaArray.length) {
			if(exclusions.contains(luaArray[i].scriptName)){
				continue;
			}

			var ret:Dynamic = luaArray[i].call(event, args);
			if(ret == FunkinLua.Function_StopLua) {
				if(ignoreStops)
					ret = FunkinLua.Function_Continue;
				else
					break;
			}

			if(ret != FunkinLua.Function_Continue) {
				returnVal = ret;
			}
		}

		for (i in 0...closeLuas.length) {
			luaArray.remove(closeLuas[i]);
			closeLuas[i].stop();
		}
		#end
		//trace(event, returnVal);
		return returnVal;
	}

	public function setOnLuas(variable:String, arg:Dynamic) {
		#if LUA_ALLOWED
		for (i in 0...luaArray.length) {
			luaArray[i].set(variable, arg);
		}
		#end
	}

	function StrumPlayAnim(isDad:Bool, id:Int, time:Float) {
		var spr:StrumNote = null;
		if(isDad) {
			spr = strumLineNotes.members[id];
		} else {
			spr = playerStrums.members[id];
		}

		if(spr != null) {
			spr.playAnim('confirm', true);
			spr.resetAnim = time;
		}
	}

	public var ratingName:String = '?';
	public var ratingPercent:Float;
	public var ratingFC:String;
	public function RecalculateRating() {
		setOnLuas('score', songScore);
		setOnLuas('misses', songMisses);
		setOnLuas('hits', songHits);

		var ret:Dynamic = callOnLuas('onRecalculateRating', []);
		if(ret != FunkinLua.Function_Stop)
		{
			if(totalPlayed < 1) //Prevent divide by 0
				ratingName = '?';
			else
			{
				// Rating Percent
				ratingPercent = Math.min(1, Math.max(0, totalNotesHit / totalPlayed));
				//trace((totalNotesHit / totalPlayed) + ', Total: ' + totalPlayed + ', notes hit: ' + totalNotesHit);

				// Rating Name
				if(ratingPercent >= 1)
				{
					ratingName = ratingStuff[ratingStuff.length-1][0]; //Uses last string
				}
				else
				{
					for (i in 0...ratingStuff.length-1)
					{
						if(ratingPercent < ratingStuff[i][1])
						{
							ratingName = ratingStuff[i][0];
							break;
						}
					}
				}
			}

			// Rating FC
			ratingFC = "";
			if (sicks > 0) ratingFC = "SFC";
			if (goods > 0) ratingFC = "GFC";
			if (bads > 0 || shits > 0) ratingFC = "FC";
			if (songMisses > 0 && songMisses < 10) ratingFC = "SDCB";
			else if (songMisses >= 10) ratingFC = "Clear";
		}
		setOnLuas('rating', ratingPercent);
		setOnLuas('ratingName', ratingName);
		setOnLuas('ratingFC', ratingFC);
	}

	#if ACHIEVEMENTS_ALLOWED
	private function checkForAchievement(achievesToCheck:Array<String> = null):String
	{
		if(chartingMode) return null;

		var usedPractice:Bool = (ClientPrefs.getGameplaySetting('practice', false) || ClientPrefs.getGameplaySetting('botplay', false));
		for (i in 0...achievesToCheck.length) {
			var achievementName:String = achievesToCheck[i];
			if(!Achievements.isAchievementUnlocked(achievementName) && !cpuControlled) {
				var unlock:Bool = false;
				switch(achievementName)
				{
					case 'week1_nomiss' | 'week2_nomiss' | 'week3_nomiss' | 'week4_nomiss' | 'week5_nomiss' | 'week6_nomiss' | 'week7_nomiss':
						if(isStoryMode && campaignMisses + songMisses < 1 && CoolUtil.difficultyString() == 'HARD' && storyPlaylist.length <= 1 && !changedDifficulty && !usedPractice)
						{
							var weekName:String = WeekData.getWeekFileName();
							switch(weekName) //I know this is a lot of duplicated code, but it's easier readable and you can add weeks with different names than the achievement tag
							{
								case 'week1':
									if(achievementName == 'week1_nomiss') unlock = true;
								case 'week2':
									if(achievementName == 'week2_nomiss') unlock = true;
								case 'week3':
									if(achievementName == 'week3_nomiss') unlock = true;
								case 'week4':
									if(achievementName == 'week4_nomiss') unlock = true;
								case 'week5':
									if(achievementName == 'week5_nomiss') unlock = true;
								case 'week6':
									if(achievementName == 'week6_nomiss') unlock = true;
								case 'week7':
									if(achievementName == 'week7_nomiss') unlock = true;
							}
						}
					case 'ur_bad':
						if(ratingPercent < 0.2 && !practiceMode) {
							unlock = true;
						}
					case 'ur_good':
						if(ratingPercent >= 1 && !usedPractice) {
							unlock = true;
						}
					case 'roadkill_enthusiast':
						if(Achievements.henchmenDeath >= 100) {
							unlock = true;
						}
					case 'oversinging':
						if(boyfriend.holdTimer >= 10 && !usedPractice) {
							unlock = true;
						}
					case 'hype':
						if(!boyfriendIdled && !usedPractice) {
							unlock = true;
						}
					case 'two_keys':
						if(!usedPractice) {
							var howManyPresses:Int = 0;
							for (j in 0...keysPressed.length) {
								if(keysPressed[j]) howManyPresses++;
							}

							if(howManyPresses <= 2) {
								unlock = true;
							}
						}
					case 'toastie':
						if(/*ClientPrefs.framerate <= 60 &&*/ ClientPrefs.lowQuality && !ClientPrefs.globalAntialiasing && !ClientPrefs.imagesPersist) {
							unlock = true;
						}
					case 'debugger':
						if(Paths.formatToSongPath(SONG.song) == 'test' && !usedPractice) {
							unlock = true;
						}
				}

				if(unlock) {
					Achievements.unlockAchievement(achievementName);
					return achievementName;
				}
			}
		}
		return null;
	}
	#end

	function bruh()
	{
		var bruh:FlxSprite = new FlxSprite();
		bruh.loadGraphic(Paths.image('ron/longbob'));
		bruh.antialiasing = true;
		bruh.active = false;
		bruh.scrollFactor.set();
		bruh.screenCenter();
		add(bruh);
		FlxTween.tween(bruh, {alpha: 0}, 1, {
			ease: FlxEase.cubeInOut,
			onComplete: function(twn:FlxTween)
			{
				bruh.destroy();
			}
		});
	}

	function setWindowPos(x:Int,y:Int)
	{
		Application.current.window.x = x;
		Application.current.window.y = y;
	}

	function setDefault(id)
		defaultStrumX[id] = strumLineNotes.members[id].x;

	var curLight:Int = -1;
	var curLightEvent:Int = -1;
}
