module common;

public import raylib;
public import save : N_UPG;
import core.stdc.math : sqrtf, cosf, sinf;
import core.stdc.stdio : snprintf;

import save : saveBest, saveBestProg, saveBestEndless, deleteProg;

// screen / world //
enum int BASE_W = 1280;
enum int BASE_H = 720;
enum int HUD_H = 100;

__gshared int W = BASE_W;
__gshared int H = BASE_H;
__gshared int PLAY_H = BASE_H - HUD_H;
__gshared float overDelay = 0;
__gshared Font gameFont;
__gshared bool hurryPlayed = false;
__gshared float hitFlash = 0;
__gshared float shakeAmt = 0;
__gshared float deathFx = 0; // seconds left of the explosion sprite
__gshared float overTimer = 0;

enum float DEATH_FX_TIME = 0.6f;
enum float OVER_WAIT = 1.0f;
enum float OVER_FADE = 0.6f;

enum float PI_F = 3.14159265f;

enum float WORLD_W = 3000.0f;
enum float WORLD_H = 3000.0f;
enum Vector2 CENTER = Vector2(WORLD_W / 2.0f, WORLD_H / 2.0f);
enum float RING_R = 1250.0f;
enum float EARTH_R = 260.0f;

// Slow trash is rejected
enum float MEMBRANE_ACCEL = 90.0f;

enum int MAX_PART = 400;
enum int MENU_ITEMS = 3; // main: play, settings, quit
enum int PLAY_ITEMS = 3; // play: Arcade, Progressive, Back
enum int ARCADE_ITEMS = 7; // arcade: 60, 90, 120, custom, endless, items toggle, Back
enum int PROG_ITEMS = 3; // progressive: Continue, New Game / demo, Back

enum State
{
	loading,
	menu,
	playing,
	paused,
	settings,
	over
}

// Which level of the menu we are on
enum MenuMode
{
	main,
	play,
	arcade,
	progressive,
	confirmNew,
	about
}

enum GameMode
{
	arcade,
	progressive
}

// Order must match the tables in upgrades.d
enum Upg
{
	pullRange,
	pushForce,
	extraHp,
	hpSlot,
	brake
}
static assert(Upg.max + 1 == N_UPG);

enum PauseAct
{
	cont,
	save,
	settings,
	exit
}

struct Particle
{
	Vector2 pos, vel;
	float life, maxLife, size;
	Color color;
}

struct Input
{
	bool left, right, fwd, brake, pull, push;
}

// Saving is not available on the web build
version (WebAssembly) enum bool CAN_SAVE = false;
else enum bool CAN_SAVE = true;

// game state //
__gshared State state = State.menu;
__gshared Particle[MAX_PART] parts;

__gshared int menuSel = 0;
__gshared MenuMode menuMode = MenuMode.main;
__gshared int menuSubSel = 0;
__gshared int customSeconds = 45;
__gshared float timeLimit = 60;// 0 = endless
__gshared float timeLeft = 0;
__gshared float elapsed = 0;
__gshared int score = 0; // arcade: score. progressive: spendable points
__gshared int earned = 0; // progressive: points earned in total (never spent)
__gshared int bestScore = 0;
__gshared int bestEndless = 0;
__gshared int bestProg = 0;
__gshared int cleared = 0;
__gshared int totalSpawned = 0;
__gshared int initialTrash = 0;
__gshared int maxHp = 5;
__gshared int baseMaxHp = 5;
__gshared bool perfect = false;
__gshared const(char)* endReason = "";
__gshared bool endless = false;
__gshared bool quitRequested = false;
__gshared bool settingsFromPause = false; // where the settings overlay returns to
__gshared bool aboutFocus = false;

// modes / upgrades
__gshared GameMode gameMode = GameMode.arcade;
__gshared bool arcadeItems = false; // arcade: upgrade pickups enabled
__gshared int[N_UPG] upgLvl; // current upgrade levels
__gshared bool progHasSave = false;
__gshared int progSaveEarned = 0;
__gshared int shopClick = -1;

// Notifications
__gshared char[48] toastText;
__gshared float toastTimer = 0;

void showToast(const(char)* s)
{
	snprintf(toastText.ptr, toastText.length, "%s", s);
	toastTimer = 2.0f;
}

// Upgrade multipliers
float pullRangeMul()
{
	return 1.0f + 0.20f * upgLvl[Upg.pullRange];
}

float pushForceMul()
{
	return 1.0f + 0.25f * upgLvl[Upg.pushForce];
}

float brakeMul()
{
	return 1.0f + 0.35f * upgLvl[Upg.brake];
}

// Pause menu layout depends on the mode
int pauseCount()
{
	return (gameMode == GameMode.progressive && CAN_SAVE) ? 4 : 3;
}

PauseAct pauseAct(int i)
{
	if (i == 0) return PauseAct.cont;
	if (gameMode == GameMode.progressive && CAN_SAVE)
	{
		if (i == 1) return PauseAct.save;
		if (i == 2) return PauseAct.settings;
		return PauseAct.exit;
	}
	if (i == 1) return PauseAct.settings;
	return PauseAct.exit;
}

int pauseSettingsIndex()
{
	return (gameMode == GameMode.progressive && CAN_SAVE) ? 2 : 1;
}

// Math //
Vector2 vadd(Vector2 a, Vector2 b)
{
	return Vector2(a.x + b.x, a.y + b.y);
}

Vector2 vsub(Vector2 a, Vector2 b)
{
	return Vector2(a.x - b.x, a.y - b.y);
}

Vector2 vmul(Vector2 a, float s)
{
	return Vector2(a.x * s, a.y * s);
}

float vlen(Vector2 a)
{
	return sqrtf(a.x * a.x + a.y * a.y);
}

float vdot(Vector2 a, Vector2 b)
{
	return a.x * b.x + a.y * b.y;
}

Vector2 vnorm(Vector2 a)
{
	float l = vlen(a);
	return l > 0.0001f ? Vector2(a.x / l, a.y / l) : Vector2(0, 0);
}

float frand()
{
	return GetRandomValue(0, 10000) / 10000.0f;
}

float frange(float a, float b)
{
	return a + (b - a) * frand();
}

float clampf(float v, float lo, float hi)
{
	return v < lo ? lo : (v > hi ? hi : v);
}

// Particles //
void burst(Vector2 p, int n, Color c, float speed, float life)
{
	foreach (_; 0 .. n)
	{
		foreach (ref pt; parts)
		{
			if (pt.life > 0) continue;
			float a = frange(0, 2 * PI_F);
			float s = frange(speed * 0.2f, speed);
			pt.pos = p;
			pt.vel = Vector2(cosf(a) * s, sinf(a) * s);
			pt.maxLife = pt.life = frange(life * 0.5f, life);
			pt.size = frange(1.5f, 3.5f);
			pt.color = c;
			break;
		}
	}
}

void resetParticles()
{
	foreach (ref p; parts) p.life = 0;
}

void updateParticles(float dt)
{
	if (hitFlash > 0) hitFlash -= dt;
	if (deathFx > 0) deathFx -= dt;
	shakeAmt -= 30.0f * dt; if (shakeAmt < 0) shakeAmt = 0;

	foreach (ref pt; parts)
	{
		if (pt.life <= 0) continue;
		pt.life -= dt;
		pt.pos = vadd(pt.pos, vmul(pt.vel, dt));
	}
}

float urgency()
{
	if (endless || timeLeft >= 10.0f) return 0;
	return clampf((10.0f - timeLeft) / 10.0f, 0, 1);
}

// buttons //
void changeCustomSeconds(int delta)
{
	customSeconds += delta;
	if (customSeconds < 10) customSeconds = 10;
	if (customSeconds > 300) customSeconds = 300;
}


version (Android)
{
	int hudY() { return 0; }
	int playTop() { return HUD_H; }

}
else
{
	int hudY() { return PLAY_H; }
	int playTop() { return 0; }
}

Rectangle shopRect(int i)
{
	enum float BW = 108, GAP = 8;
	return Rectangle(498.0f + i * (BW + GAP), hudY() + 16.0f, BW, 70.0f);
}

void drawText(const(char)* text, int x, int y, int size, Color c)
{
	DrawTextEx(gameFont, text, Vector2(x, y), size, size * 0.04f, c);
}

int measureText(const(char)* text, int size)
{
	return cast(int) MeasureTextEx(gameFont, text, size, size * 0.04f).x;
}

// End //
void endGame(const(char)* reason)
{
	endReason = reason;
	if (gameMode == GameMode.progressive)
	{
		deleteProg();
		if (earned > bestProg)
		{
			bestProg = earned;
			saveBestProg(bestProg);
		}
	}
	else
	{
		if (score > bestScore)
		{
			bestScore = score;
			saveBest(bestScore);
		}
		if (timeLimit <= 0 && cast(int) elapsed > bestEndless)
		{
			bestEndless = cast(int) elapsed;
			saveBestEndless(bestEndless);
		}
	}
	state = State.over;
	menuSel = 0;
	overDelay = 0.6f;
}
