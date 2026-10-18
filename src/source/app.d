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
import pickups;
import upgrades;
import save : loadBest, loadBestProg, loadBestEndless, loadProg, deleteProg, ProgSave;

// setup

void beginRun(bool fromSave)
{
	resetTrash();
	resetParticles();
	resetPickups();
	resetUpgrades();

	bool prog = gameMode == GameMode.progressive;
	endless = prog || timeLimit <= 0;
	hitFlash = 0;
	overTimer = 0;
	toastTimer = 0;

	if (endless)
	{
		baseMaxHp = 5;
	}
	else
	{
		baseMaxHp = cast(int)(timeLimit / 20.0f);
		if (baseMaxHp < 1)
		{
			baseMaxHp = 1;
		}
	}

	ProgSave sv;
	bool loaded = prog && fromSave && loadProg(sv);
	if (loaded)
	{
		foreach (i; 0 .. N_UPG)
		{
			int l = sv.lvl[i];
			if (l < 0) l = 0;
			if (l > upgMaxLvl(i)) l = upgMaxLvl(i);
			upgLvl[i] = l;
		}
	}
	maxHp = baseMaxHp + upgLvl[Upg.hpSlot];

	resetRocket();
	initCamera();

	score = 0;
	earned = 0;
	cleared = 0;
	totalSpawned = 0;
	elapsed = 0;
	perfect = false;
	hurryPlayed = false;
	timeLeft = prog ? 0 : timeLimit;

	if (loaded)
	{
		score = sv.score < 0 ? 0 : sv.score;
		earned = sv.earned < 0 ? 0 : sv.earned;
		cleared = sv.cleared < 0 ? 0 : sv.cleared;
		elapsed = sv.elapsed < 0 ? 0 : sv.elapsed;
		rocket.hp = sv.hp < 1 ? 1 : (sv.hp > maxHp ? maxHp : sv.hp);
	}

	spawnInitialTrash();
	initialTrash = totalSpawned;
	state = State.playing;

	if (loaded) showToast("Game loaded");
}

void startGame()
{
	beginRun(false);
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

	if (gameMode == GameMode.arcade && arcadeItems) updatePickups(dt, act);

	if (trashInside() == 0)
	{
		if (gameMode == GameMode.progressive || endless)
		{
			// endless
			spawnInitialTrash();
		}
		else
		{
			score += 100;
			perfect = true;
			endGame("Perfect clear!");
		}
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

private void refreshProgSave()
{
	ProgSave sv;
	progHasSave = loadProg(sv); // disable on web
	progSaveEarned = progHasSave ? sv.earned : 0;
}

private void enterProgressiveMenu()
{
	refreshProgSave();
	menuMode = MenuMode.progressive;
	menuSubSel = progHasSave ? 0 : 1;
}

private void activatePlay(int sel)
{
	switch (sel)
	{
		case 0:
			menuMode = MenuMode.arcade;
			menuSubSel = 0;
			break;
		case 1:
			enterProgressiveMenu();
			break;
		default:
			menuMode = MenuMode.main;
			break;
	}
}

void menuPlay()
{
	if (menuDown()) menuSubSel = (menuSubSel + 1) % PLAY_ITEMS;
	if (menuUp()) menuSubSel = (menuSubSel + PLAY_ITEMS - 1) % PLAY_ITEMS;
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

// Arcade menu

private void startArcade()
{
	gameMode = GameMode.arcade;
	startGame();
}

private void activateArcade(int sel)
{
	switch (sel)
	{
		case 0: timeLimit = 60; startArcade(); break;
		case 1: timeLimit = 90; startArcade(); break;
		case 2: timeLimit = 120; startArcade(); break;
		case 3: timeLimit = customSeconds; startArcade(); break;
		case 4: timeLimit = 0; startArcade(); break;
		case 5: arcadeItems = !arcadeItems; break;
		default:
			menuMode = MenuMode.play;
			menuSubSel = 0;
			break;
	}
}

void menuArcade()
{
	if (menuDown()) menuSubSel = (menuSubSel + 1) % ARCADE_ITEMS;
	if (menuUp()) menuSubSel = (menuSubSel + ARCADE_ITEMS - 1) % ARCADE_ITEMS;
	if (menuSubSel == 3)
	{
		if (menuRight()) changeCustomSeconds(10);
		if (menuLeft()) changeCustomSeconds(-10);
	}
	if (menuSubSel == 5)
	{
		if (menuRight() || menuLeft()) arcadeItems = !arcadeItems;
	}
	if (menuCancel())
	{
		menuMode = MenuMode.play;
		menuSubSel = 0;
		return;
	}
	if (menuConfirm())
	{
		activateArcade(menuSubSel);
		return;
	}
	int clicked = drawMenuArcade();
	if (clicked >= 0) activateArcade(clicked);
}

// Progressive menu

private bool progItemEnabled(int i)
{
	return i != 0 || progHasSave;
}

private int nextProgItem(int cur, int dir)
{
	int i = cur;
	foreach (_; 0 .. PROG_ITEMS)
	{
		i = (i + dir + PROG_ITEMS) % PROG_ITEMS;
		if (progItemEnabled(i)) return i;
	}
	return cur;
}

private void startProgressiveNew()
{
	gameMode = GameMode.progressive;
	deleteProg();
	beginRun(false);
}

private void activateProgressive(int sel)
{
	switch (sel)
	{
		case 0: // Continue
			if (!progHasSave) break;
			gameMode = GameMode.progressive;
			beginRun(true);
			break;
		case 1:
			if (progHasSave)
			{
				menuMode = MenuMode.confirmNew;
				menuSubSel = 1; // default to Cancel
			}
			else startProgressiveNew();
			break;
		default:
			menuMode = MenuMode.play;
			menuSubSel = 1;
			break;
	}
}

void menuProgressive()
{
	if (menuDown()) menuSubSel = nextProgItem(menuSubSel, 1);
	if (menuUp()) menuSubSel = nextProgItem(menuSubSel, -1);
	if (menuCancel())
	{
		menuMode = MenuMode.play;
		menuSubSel = 1;
		return;
	}
	if (menuConfirm())
	{
		activateProgressive(menuSubSel);
		return;
	}
	int clicked = drawMenuProgressive();
	if (clicked >= 0) activateProgressive(clicked);
}

// "Erase saved game?" dialog
private void activateConfirm(int sel)
{
	if (sel == 0) startProgressiveNew();
	else
	{
		menuMode = MenuMode.progressive;
		menuSubSel = 1;
	}
}

void menuConfirmNew()
{
	if (menuDown() || menuUp()) menuSubSel = (menuSubSel + 1) % 2;
	if (menuCancel())
	{
		activateConfirm(1);
		return;
	}
	if (menuConfirm())
	{
		activateConfirm(menuSubSel);
		return;
	}
	int clicked = drawMenuConfirm();
	if (clicked >= 0) activateConfirm(clicked);
}

void menuScreen()
{
	final switch (menuMode)
	{
		case MenuMode.main: menuMain(); break;
		case MenuMode.play: menuPlay(); break;
		case MenuMode.arcade: menuArcade(); break;
		case MenuMode.progressive: menuProgressive(); break;
		case MenuMode.confirmNew: menuConfirmNew(); break;
		case MenuMode.about:
			drawMenuBackground();
			if (aboutUpdateDraw())
			{
				menuMode = MenuMode.main;
				aboutFocus = true;
			}
			break;
	}
}

// Progressive shop:
private void handleShop()
{
	int pick = shopKeyPressed();
	if (pick < 0) pick = shopClick;
	version (Android)
	{
		if (pick < 0) pick = touchShop;
	}
	if (pick >= 0) buyUpgrade(pick);
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

	if (gameMode == GameMode.progressive && state == State.playing) handleShop();
}

private void goToMenu()
{
	state = State.menu;
	menuMode = MenuMode.main;
	menuSel = 0;
}

private void activatePause(int sel)
{
	final switch (pauseAct(sel))
	{
		case PauseAct.cont:
			state = State.playing;
			break;
		case PauseAct.save:
			saveProgress();
			showToast("Game saved");
			break;
		case PauseAct.settings:
			settingsFromPause = true;
			state = State.settings;
			break;
		case PauseAct.exit:
			if (gameMode == GameMode.progressive && CAN_SAVE) saveProgress();
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
	int n = pauseCount();
	if (menuDown()) menuSel = (menuSel + 1) % n;
	if (menuUp()) menuSel = (menuSel + n - 1) % n;
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
			menuSel = pauseSettingsIndex();
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
		bestProg = loadBestProg();
		bestEndless = loadBestEndless();
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
