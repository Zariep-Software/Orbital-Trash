module assets;

import common;
import settings : current;
import core.stdc.stdio : snprintf;

// Asset Root Paths
enum string ASSETS_DIR = "assets";
enum string IMAGES_DIR = ASSETS_DIR ~ "/sprites";
enum string FONTS_DIR = ASSETS_DIR ~ "/fonts";
enum string SFX_DIR = ASSETS_DIR ~ "/sfx";
enum string MUSIC_DIR = ASSETS_DIR ~ "/music";

// Tweak
enum float ROCKET_DRAW_H = 44.0f; // sprite height in world px
enum float ROCKET_SPRITE_DEG = 90.0f; // 90 = points up, 0 = points right

// Textures
__gshared Texture2D rocketTex;
__gshared Texture2D logoTex;
__gshared Texture2D explosionTex;
__gshared Texture2D pullIconTex;
__gshared Texture2D pushIconTex;
__gshared Texture2D pauseIconTex;
__gshared Texture2D[4] trashTex; // indexed by Kind
__gshared int[4] trashFrames = [1, 1, 1, 1];

// Sounds
__gshared Sound sRocket, sHit, sGExplosion, sRExplosion, sHurry,
	sTimeLimit, sGameOver, sNav, sPull, sPush;

private __gshared float[10] sfxBase = 1.0f;
private __gshared bool previewActive = false;

// Music
private enum Track
{
	none,
	menu,
	game
}

private __gshared Music musicMenu, musicGame;
private __gshared Track curTrack = Track.none;

// Path helper: builds "dir/file" into a caller-provided stack buffer.
// snprintf always null-terminates, so the result is safe to pass to C.
private const(char)* cpath(ref char[256] buf, string dir, string file)
{
	snprintf(buf.ptr, buf.length, "%.*s/%.*s",
		cast(int) dir.length, dir.ptr,
		cast(int) file.length, file.ptr);
	return buf.ptr;
}

// Asset Helpers
private Texture2D loadTex(string filename)
{
	char[256] buf;
	Texture2D t = LoadTexture(cpath(buf, IMAGES_DIR, filename));
	if (t.id != 0) SetTextureFilter(t, TextureFilter.TEXTURE_FILTER_BILINEAR);
	return t;
}

private Sound loadSfx(string filename)
{
	char[256] buf;
	return LoadSound(cpath(buf, SFX_DIR, filename));
}

private Music loadMusic(string filename)
{
	char[256] buf;
	Music m = LoadMusicStream(cpath(buf, MUSIC_DIR, filename));
	m.looping = true;
	return m;
}

private Sound*[10] sfxList()
{
	return [&sRocket, &sHit, &sGExplosion, &sRExplosion, &sHurry,
		&sTimeLimit, &sGameOver, &sNav, &sPull, &sPush];
}

void applySfxVolume(float v)
{
	auto list = sfxList();
	foreach (i, s; list)
	{
		SetSoundVolume(*s, sfxBase[i] * v);
	}
}

enum int LOAD_STEPS = 6;
private __gshared int loadStep = 0;

bool assetsLoaded()
{
	return loadStep >= LOAD_STEPS;
}

float loadProgress()
{
	return cast(float) loadStep / LOAD_STEPS;
}

void assetsLoadStep()
{
	switch (loadStep)
	{
		case 0:
			char[256] fontBuf;
			gameFont = LoadFontEx(cpath(fontBuf, FONTS_DIR, "Oxanium/Oxanium-SemiBold.ttf"), 64, null, 0);
			if (gameFont.texture.id == 0) gameFont = GetFontDefault();
			else SetTextureFilter(gameFont.texture, TextureFilter.TEXTURE_FILTER_BILINEAR);
			break;

		case 1: // images
			rocketTex = loadTex("rocket.png");
			logoTex = loadTex("logo.png");
			explosionTex = loadTex("explosion.png");
			trashTex[0] = loadTex("light.png");
			trashTex[1] = loadTex("heavy.png");
			trashTex[2] = loadTex("fast.png");
			trashTex[3] = loadTex("large.png");
			pullIconTex = loadTex("pull.png");
			pushIconTex = loadTex("push.png");
			pauseIconTex = loadTex("ui_pause.png");
			foreach (i; 0 .. 4)
			{
				if (trashTex[i].id != 0 && trashTex[i].height > 0)
				{
					int f = trashTex[i].width / trashTex[i].height;
					trashFrames[i] = f < 1 ? 1 : f;
				}
			}
			break;

		case 2:
			sRocket = loadSfx("Rocket.ogg");
			sHit = loadSfx("hit.ogg");
			sGExplosion = loadSfx("g_explosion.ogg");
			sRExplosion = loadSfx("r_explosion.ogg");
			sHurry = loadSfx("hurryup.ogg");
			break;

		case 3:
			sTimeLimit = loadSfx("timeup.ogg");
			sGameOver = loadSfx("gameover.ogg");
			sNav = loadSfx("navmenu.ogg");
			sPull = loadSfx("pull.ogg");
			sPush = loadSfx("push.ogg");
			sfxBase[0] = 0.5f;
			sfxBase[4] = 1.0f;
			sfxBase[7] = 0.6f;
			sfxBase[8] = 0.6f;
			break;

		case 4: musicMenu = loadMusic("menu.ogg"); break;
		case 5: musicGame = loadMusic("space.ogg"); break;
		default: break;
	}
	loadStep++;
}

void assetsShutdown()
{
	UnloadTexture(rocketTex);
	UnloadTexture(logoTex);
	UnloadTexture(explosionTex);
	UnloadTexture(pushIconTex);
	UnloadTexture(pullIconTex);
	UnloadTexture(pauseIconTex);

	foreach (ref t; trashTex)
	{
		UnloadTexture(t);
	}

	UnloadSound(sRocket); UnloadSound(sHit); UnloadSound(sGExplosion);
	UnloadSound(sRExplosion); UnloadSound(sHurry); UnloadSound(sTimeLimit);
	UnloadSound(sGameOver); UnloadSound(sNav); UnloadSound(sPull); UnloadSound(sPush);

	UnloadMusicStream(musicMenu);
	UnloadMusicStream(musicGame);
}

// SFX Helpers
void playSfx(Sound s)
{
	if (s.frameCount > 0) PlaySound(s);
}

void loopSfx(Sound s, bool on)
{
	if (s.frameCount == 0) return;
	if (on)
	{
		if (!IsSoundPlaying(s)) PlaySound(s);
	}
	else if (IsSoundPlaying(s))
	{
		StopSound(s);
	}
}

// Music

void playMusicPreview(float musicVol)
{
	if (sTimeLimit.frameCount == 0) return;
	SetSoundVolume(sTimeLimit, sfxBase[5] * musicVol);
	PlaySound(sTimeLimit);
	previewActive = true;
}

private void setTrack(Track t)
{
	if (t == curTrack) return;
	if (curTrack == Track.menu) StopMusicStream(musicMenu);
	if (curTrack == Track.game) StopMusicStream(musicGame);
	curTrack = t;
	if (t == Track.menu) PlayMusicStream(musicMenu);
	if (t == Track.game) PlayMusicStream(musicGame);
}

void audioUpdate()
{
	if (previewActive && !IsSoundPlaying(sTimeLimit))
	{
		SetSoundVolume(sTimeLimit, sfxBase[5] * current.sfxVolume);
		previewActive = false;
	}
	Track want;
	final switch (state)
	{
		case State.menu: want = Track.menu; break;
		case State.settings: want = settingsFromPause ? Track.game : Track.menu; break;
		case State.playing:
		case State.paused: want = Track.game; break;
		case State.loading:
		case State.over: want = Track.none; break;
	}
	setTrack(want);

	// Stop music while paused
	float vol = (state == State.paused || (state == State.settings && settingsFromPause)) ? 0.35f : 1.0f;
	vol *= current.musicVolume;
	if (curTrack == Track.menu)
	{
		SetMusicVolume(musicMenu, vol);
		UpdateMusicStream(musicMenu);
	}
	else if (curTrack == Track.game)
	{
		SetMusicVolume(musicGame, vol);
		SetMusicPitch(musicGame, 1.0f + 0.25f * urgency());
		UpdateMusicStream(musicGame);
	}

	if (state != State.playing)
	{
		loopSfx(sRocket, false);
		loopSfx(sPull, false);
	}
}