module app;

import common;
import controls;
import player;
import trash;
import render;
import display;
import settings : settingsInit, settingsUpdateDraw;
import ui : centeredTextAt;
import touch;
import assets;
import about;
import save : loadBest;

// setup
void startGame()
{
	resetTrash();
	resetParticles();

	endless = timeLimit <= 0;
	hitFlash = 0;
	overTimer = 0;

	if (endless)
	{
		maxHp = 5;
	}
	else
	{
		maxHp = cast(int)(timeLimit / 20.0f);
		if (maxHp < 1)
		{
			maxHp = 1;
		}
	}

	resetRocket();
	initCamera();

	score = 0;
	cleared = 0;
	totalSpawned = 0;
	elapsed = 0;
	perfect = false;
	hurryPlayed = false;
	timeLeft = timeLimit;

	spawnInitialTrash();
	initialTrash = totalSpawned;
	state = State.playing;
}

// per frame updates
void updatePlaying(float dt)
{
	elapsed += dt;
	if (!endless)
	{
		timeLeft -= dt;
		if (!hurryPlayed && timeLeft <= 10)
		{
			hurryPlayed = true;
			playSfx(sHurry);
		}
		if (timeLeft <= 0)
		{
			timeLeft = 0;
			playSfx(sTimeLimit);
			endGame("Time up");
			return;
		}
	}

	Input inp = readInput();
	version (Android) applyTouchInput(inp, rocket.angle);
	Actions act = updateRocket(dt, inp);

	// ability / engine sounds
	loopSfx(sRocket, rocket.thrusting);
	loopSfx(sPull, act.pulling);
	if (act.pushing) playSfx(sPush);

	updateTrash(dt, act);
	if (state != State.playing) return; // rocket destroyed
	updateTrashCollisions();
	updateSpawning(dt);

	// perfect clear
	if (trashInside() == 0)
	{
		score += 100;
		perfect = true;
		endGame("Perfect clear!");
	}

	updateCamera(dt);
}

// screens //

// Quit does not exist on web, so keyboard selection must skip it there
version (WebAssembly)
	enum int MAIN_SELECTABLE = MENU_ITEMS - 1;
else
	enum int MAIN_SELECTABLE = MENU_ITEMS;

private void activateMain(int sel)
{
	switch (sel)
	{
		case 0:
			menuMode = MenuMode.play;
			menuSubSel = 0;
			break;
		case 1:
			settingsFromPause = false;
			state = State.settings;
			break;
		case 100: // about button
			aboutReset();
			menuMode = MenuMode.about;
			break;
		default:
			quitRequested = true;
			break;
	}
}

void menuMain()
{
	if (aboutFocus)
	{
		if (menuRight() || menuUp() || menuDown()) aboutFocus = false;
		if (menuConfirm())
		{
			activateMain(100);
			return;
		}
	}
	else
	{
		if (menuLeft()) aboutFocus = true;
		else
		{
			if (menuDown()) menuSel = (menuSel + 1) % MAIN_SELECTABLE;
			if (menuUp()) menuSel = (menuSel + MAIN_SELECTABLE - 1) % MAIN_SELECTABLE;
			if (menuConfirm())
			{
				activateMain(menuSel);
				return;
			}
		}
	}
	int clicked = drawMenuMain();
	if (clicked >= 0) activateMain(clicked);
}

private void activatePlay(int sel)
{
	switch (sel)
	{
		case 0: timeLimit = 60; startGame(); break;
		case 1: timeLimit = 90; startGame(); break;
		case 2: timeLimit = 120; startGame(); break;
		case 3: timeLimit = customSeconds; startGame(); break;
		case 4: timeLimit = 0; startGame(); break;
		default: menuMode = MenuMode.main; break;
	}
}

void menuPlay()
{
	if (menuDown()) menuSubSel = (menuSubSel + 1) % PLAY_ITEMS;
	if (menuUp()) menuSubSel = (menuSubSel + PLAY_ITEMS - 1) % PLAY_ITEMS;
	if (menuSubSel == 3)
	{
		if (menuRight()) changeCustomSeconds(10);
		if (menuLeft()) changeCustomSeconds(-10);
	}
	if (menuCancel())
	{
		menuMode = MenuMode.main;
		return;
	}
	if (menuConfirm())
	{
		activatePlay(menuSubSel);
		return;
	}
	int clicked = drawMenuPlay();
	if (clicked >= 0) activatePlay(clicked);
}

void menuScreen()
{
	if (menuMode == MenuMode.main) menuMain();
	else if (menuMode == MenuMode.play) menuPlay();
	else
	{
		drawMenuBackground();
		if (aboutUpdateDraw())
		{
			menuMode = MenuMode.main;
			aboutFocus = true;
		}
	}
}

void playScreen(float dt)
{
	version (Android) touchUpdate();

	if (pausePressed())
	{
		state = State.paused;
		menuSel = 0;
	}
	else
	{
		updatePlaying(dt);
	}
	updateParticles(dt);
	drawPlayScreen();
}

enum int PAUSE_ITEMS = 3; // continue, settings, menu

private void goToMenu()
{
	state = State.menu;
	menuMode = MenuMode.main;
	menuSel = 0;
}

private void activatePause(int sel)
{
	switch (sel)
	{
		case 0:
			state = State.playing;
			break;
		case 1:
			settingsFromPause = true;
			state = State.settings;
			break;
		default:
			goToMenu();
			break;
	}
}

void pauseScreen()
{
	// Pause key / Esc / Pull all resume
	if (pausePressed() || menuCancel())
	{
		state = State.playing;
		return;
	}
	if (menuDown()) menuSel = (menuSel + 1) % PAUSE_ITEMS;
	if (menuUp()) menuSel = (menuSel + PAUSE_ITEMS - 1) % PAUSE_ITEMS;
	if (menuConfirm())
	{
		activatePause(menuSel);
		return;
	}
	int clicked = drawPauseScreen();
	if (clicked >= 0) activatePause(clicked);
}

enum int OVER_ITEMS = 2; // restart, menu

private void activateOver(int sel)
{
	if (sel == 0) startGame();
	else goToMenu();
}

void overScreen(float dt)
{
	updateParticles(dt);
	overTimer += dt;
	bool interactive = overTimer >= OVER_WAIT + OVER_FADE;

	if (interactive)
	{
		if (restartPressed())
		{
			startGame();
			return;
		}
		if (toMenuPressed())
		{
			goToMenu();
			return;
		}
		if (menuDown()) menuSel = (menuSel + 1) % OVER_ITEMS;
		if (menuUp()) menuSel = (menuSel + OVER_ITEMS - 1) % OVER_ITEMS;
		if (menuConfirm())
		{
			activateOver(menuSel);
			return;
		}
		if (menuCancel())
		{
			goToMenu();
			return;
		}
	}
	int clicked = drawOverScreen();
	if (clicked >= 0 && interactive) activateOver(clicked);
}

// Settings overlay, drawn on top of any screen
void settingsScreen()
{
	drawSettingsBackground();
	if (settingsUpdateDraw())
	{
		if (settingsFromPause)
		{
			state = State.paused;
			menuSel = 1;
		}
		else
		{
			state = State.menu;
			menuMode = MenuMode.main;
			menuSel = 1;
		}
	}
}

void loadingScreen()
{
	assetsLoadStep();

	ClearBackground(Color(16, 16, 32, 255));

	float bw = 400, bh = 14;
	float bx = (BASE_W - bw) * 0.5f, by = BASE_H * 0.6f;
	centeredTextAt("Loading...", 28, BASE_W * 0.5f, by - 50, Color(200, 200, 215, 255));
	DrawRectangleRec(Rectangle(bx, by, bw, bh), Color(18, 24, 42, 255));
	DrawRectangleRec(Rectangle(bx, by, bw * loadProgress(), bh), Color(255, 230, 120, 255));
	DrawRectangleLinesEx(Rectangle(bx, by, bw, bh), 2, Color(90, 130, 190, 255));

	if (assetsLoaded())
	{
		settingsInit();
		bestScore = loadBest();
		state = State.menu;
		menuMode = MenuMode.main;
	}
}

bool frame()
{
	version (WebAssembly)
	{
		if (quitRequested) return true;
	}
	else
	{
		if (WindowShouldClose() || quitRequested) return true;
	}

	float dt = GetFrameTime();
	if (dt > 0.033f) dt = 0.033f;

	version (WebAssembly)
	{
		int pw = pageW(), ph = pageH();
		if (pw > 0 && ph > 0 && (pw != GetScreenWidth() || ph != GetScreenHeight()))
			SetWindowSize(pw, ph);
	}

	displayBeginFrame();
	final switch (state)
	{
		case State.loading: loadingScreen(); break;
		case State.menu: menuScreen(); break;
		case State.playing: playScreen(dt); break;
		case State.paused: pauseScreen(); break;
		case State.settings: settingsScreen(); break;
		case State.over: overScreen(dt); break;
	}

	if (state != State.playing && (menuDown() || menuUp() || menuLeft() || menuRight()))
	{
		playSfx(sNav);
	}
	audioUpdate();
	displayEndFrame();
	return false;
}

version (WebAssembly)
{
	extern (C) @system nothrow @nogc
	{
		int emscripten_run_script_int(const(char)* script);
	}

	private int pageW()
	{
		return emscripten_run_script_int("window.innerWidth");
	}
	private int pageH()
	{
		return emscripten_run_script_int("window.innerHeight");
	}
}

void ready()
{

	version (WebAssembly)
	{
		// No vsync hint: the browser paces frames via requestAnimationFrame
		SetConfigFlags(ConfigFlags.FLAG_WINDOW_RESIZABLE);

	}
	else
	{
		SetConfigFlags(ConfigFlags.FLAG_VSYNC_HINT | ConfigFlags.FLAG_WINDOW_RESIZABLE);
	}

	version (Android)
	{
		InitWindow(0, 0, "Orbital Trash");
	}
	else version (WebAssembly)
	{
		int pw = pageW(), ph = pageH();
		if (pw < 320) pw = BASE_W;
		if (ph < 240) ph = BASE_H;
		InitWindow(pw, ph, "Orbital Trash");
	}
	else
	{
		InitWindow(BASE_W, BASE_H, "Orbital Trash");
	}

	InitAudioDevice();
	SetExitKey(KeyboardKey.KEY_NULL);

	version (WebAssembly)
	{
		SetTargetFPS(0);
	}
	else
	{
		SetTargetFPS(60);
	}

	SetRandomSeed(1234);
	initStars();
	displayInit();
	state = State.loading;

	version (WebAssembly)
	{
		extern (C) static void webLoopFunc()
		{
			if (frame()) emscripten_cancel_main_loop();
		}
		// fps 0 = use requestAnimationFrame; true = never return
		emscripten_set_main_loop(&webLoopFunc, 0, true);
	}
	else
	{
		while (!frame()) {}
	}

	assetsShutdown();
	displayShutdown();
	CloseAudioDevice();
	CloseWindow();
}

version (WebAssembly)
{
	extern (C) @system nothrow @nogc
	void emscripten_set_main_loop(void* ptr, int fps, int simulate_infinite_loop);
	extern (C) @system nothrow @nogc
	void emscripten_cancel_main_loop();
}

// -betterC trick.
version (D_BetterC)
{
	extern (C) int main(int argc, char** argv) { ready(); return 0; }
}
else
{
	void main() { ready(); }
}