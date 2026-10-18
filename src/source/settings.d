module settings;

import common;
import ui;
import display : mouse;
import save;
import assets;
import controls : menuUp, menuDown, menuLeft, menuRight, menuConfirm, menuCancel;
import core.stdc.stdio : snprintf;

enum Bind
{
	left, right, fwd, brake, pull, push, pause
}
static assert(Bind.max + 1 == N_BINDINGS);

private struct Res { int w; int h; }
private immutable Res[11] COMMON_RES =
[
	Res(640, 360), Res(854, 480), Res(1024, 600), Res(1280, 720), Res(1280, 800),
	Res(1366, 768), Res(1440, 900), Res(1600, 900), Res(1920, 1080),
	Res(2560, 1440), Res(3840, 2160)
];

private immutable(char)*[N_BINDINGS] ACTION_LABELS =
	["Turn left", "Turn right", "Thrust", "Brake", "Pull (hold)", "Push", "Pause"];

private __gshared Res[COMMON_RES.length] validRes;
private __gshared int validCount = 1;
private __gshared int selectedRes = 0;
private __gshared int waitingFor = -1;
private __gshared int draggingSlider = -1;

__gshared SettingsData current;

// keyboard focus
private enum int F_RES = 0, F_APPLY = 1, F_FULL = 2, F_VOL = 3, F_MUSIC = 4, F_SFX = 5, F_BIND = 6;
private enum int F_RESET = F_BIND + N_BINDINGS;
private enum int F_CLOSE = F_RESET + 1;
private enum int F_COUNT = F_CLOSE + 1;
private __gshared int focus = 0;
private __gshared bool act = false; // Enter/Space this frame
private __gshared int adj = 0; // Left/Right this frame

//Accept + focus = fire
private bool hit(int id, bool clicked)
{
	if (clicked) focus = id;
	return clicked || (act && focus == id);
}

private void applyResolutionSetting()
{
	current.resolutionIndex = selectedRes;
	applyResolution();
	saveSettings(current);
}

private void toggleFullscreenSetting()
{
	current.fullscreen = !current.fullscreen;
	ToggleFullscreen();
	if (!current.fullscreen) applyResolution();
	saveSettings(current);
}

// Key lookup (used by controls)

KeyboardKey keyFor(Bind b)
{
	return cast(KeyboardKey) current.bindings[b];
}

// Human readable key name. `buf` is used for names that need formatting.
const(char)* keyName(int k, char[] buf)
{
	if ((k >= 'A' && k <= 'Z') || (k >= '0' && k <= '9'))
	{
		buf[0] = cast(char) k;
		buf[1] = 0;
		return buf.ptr;
	}
	if (k >= KeyboardKey.KEY_F1 && k <= KeyboardKey.KEY_F12)
	{
		snprintf(buf.ptr, buf.length, "F%d", k - cast(int) KeyboardKey.KEY_F1 + 1);
		return buf.ptr;
	}
	switch (k)
	{
		case KeyboardKey.KEY_SPACE: return "Space";
		case KeyboardKey.KEY_ENTER: return "Enter";
		case KeyboardKey.KEY_KP_ENTER: return "Enter";
		case KeyboardKey.KEY_ESCAPE: return "Esc";
		case KeyboardKey.KEY_TAB: return "Tab";
		case KeyboardKey.KEY_BACKSPACE: return "Backspace";
		case KeyboardKey.KEY_LEFT: return "Left";
		case KeyboardKey.KEY_RIGHT: return "Right";
		case KeyboardKey.KEY_UP: return "Up";
		case KeyboardKey.KEY_DOWN: return "Down";
		case KeyboardKey.KEY_LEFT_SHIFT: return "L-Shift";
		case KeyboardKey.KEY_RIGHT_SHIFT: return "R-Shift";
		case KeyboardKey.KEY_LEFT_CONTROL: return "L-Ctrl";
		case KeyboardKey.KEY_RIGHT_CONTROL: return "R-Ctrl";
		case KeyboardKey.KEY_LEFT_ALT: return "L-Alt";
		case KeyboardKey.KEY_RIGHT_ALT: return "R-Alt";
		case KeyboardKey.KEY_COMMA: return ",";
		case KeyboardKey.KEY_PERIOD: return ".";
		case KeyboardKey.KEY_SLASH: return "/";
		case KeyboardKey.KEY_SEMICOLON: return ";";
		default: break;
	}
	snprintf(buf.ptr, buf.length, "Key %d", k);
	return buf.ptr;
}

const(char)* bindName(Bind b, char[] buf)
{
	return keyName(current.bindings[b], buf);
}

// Init / apply

void settingsInit()
{
	current = loadSettings();

	SettingsData defaults;
	foreach (i; 0 .. N_BINDINGS)
	{
		if (current.bindings[i] <= 0) current.bindings[i] = defaults.bindings[i];
	}
	current.masterVolume = clampf(current.masterVolume, 0.0f, 1.0f);

	// Only offer resolutions that fit the monitor
	int monitor = GetCurrentMonitor();
	int maxW = GetMonitorWidth(monitor);
	int maxH = GetMonitorHeight(monitor);

	int count = 0;
	foreach (r; COMMON_RES)
	{
		if (maxW > 0 && (r.w > maxW || r.h > maxH)) continue;
		validRes[count++] = r;
	}
	if (count == 0)
	{
		validRes[0] = Res(W, H);
		count = 1;
	}
	validCount = count;

	if (current.resolutionIndex < 0 || current.resolutionIndex >= validCount)
	{
		// default to the game's native resolution when available
		current.resolutionIndex = 0;
		foreach (i; 0 .. validCount)
		{
			if (validRes[i].w == W && validRes[i].h == H) current.resolutionIndex = i;
		}
	}
	selectedRes = current.resolutionIndex;

	current.musicVolume = clampf(current.musicVolume, 0.0f, 1.0f);
	current.sfxVolume = clampf(current.sfxVolume, 0.0f, 1.0f);
	SetMasterVolume(current.masterVolume);
	applySfxVolume(current.sfxVolume);

	if (current.fullscreen) ToggleFullscreen();
	else applyResolution();

}

private void applyResolution()
{
	if (IsWindowFullscreen()) return;
	Res r = validRes[current.resolutionIndex];
	SetWindowSize(r.w, r.h);

	int monitor = GetCurrentMonitor();
	int mw = GetMonitorWidth(monitor);
	int mh = GetMonitorHeight(monitor);
	if (mw > 0 && mh > 0)
	{
		Vector2 mp = GetMonitorPosition(monitor);
		SetWindowPosition(cast(int) mp.x + (mw - r.w) / 2, cast(int) mp.y + (mh - r.h) / 2);
	}
}

// Drawing helpers

private void drawResolutionSelector(float x, float y)
{
	drawText("Resolution", cast(int) x, cast(int) y, 18, Color(220, 225, 245, 255));
	y += 28;

	if (button(Rectangle(x, y, 40, 40), "<", 24) && selectedRes > 0) { selectedRes--; focus = F_RES; }

	Rectangle center = Rectangle(x + 45, y, 150, 40);
	DrawRectangleRec(center, Color(40, 42, 60, 255));
	if (focus == F_RES)
	{
		DrawRectangleLinesEx(center, 2, Color(255, 230, 120, 255));
	}
	Res r = validRes[selectedRes];
	char[32] text;
	snprintf(text.ptr, text.length, "%d x %d", r.w, r.h);
	int tw = measureText(text.ptr, 18);
	drawText(text.ptr, cast(int)(center.x + (center.width - tw) * 0.5f),
		cast(int)(center.y + (center.height - 18) * 0.5f), 18, Color(255, 255, 255, 255));

	if (button(Rectangle(x + 200, y, 40, 40), ">", 24) && selectedRes < validCount - 1) { selectedRes++; focus = F_RES; }

	y += 52;
	if (hit(F_APPLY, button(Rectangle(x, y, 240, 40), "Apply Resolution", 18, focus == F_APPLY)))
	{
		applyResolutionSetting();
	}
	if (IsWindowFullscreen())
	{
		drawText("(applies when windowed)", cast(int) x, cast(int)(y + 46), 14, Color(150, 160, 190, 255));
	}
}

private void previewSound(int id)
{
	if (id == F_SFX) playSfx(sHit);
	else if (id == F_MUSIC) playMusicPreview(current.musicVolume);
}

private void drawSlider(float x, float y, const(char)* name, float* value, int id)
{
	enum float TRACK_W = 260.0f;
	char[48] buf;
	snprintf(buf.ptr, buf.length, "%s: %d%%", name, cast(int)(*value * 100.0f + 0.5f));
	drawText(buf.ptr, cast(int) x, cast(int) y, 18, Color(220, 225, 245, 255));
	if (focus == id)
	{
		DrawRectangleLines(cast(int)(x - 8), cast(int)(y - 4), cast(int)(TRACK_W + 16), 62, Color(255, 230, 120, 255));
	}

	Vector2 m = mouse();
	Rectangle hitRect = Rectangle(x - 8, y + 22, TRACK_W + 16, 34);

	if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT) && CheckCollisionPointRec(m, hitRect))
	{
		draggingSlider = id;
		focus = id;
	}
	if (draggingSlider == id)
	{
		if (IsMouseButtonDown(MouseButton.MOUSE_BUTTON_LEFT))
		{
			*value = clampf((m.x - x) / TRACK_W, 0.0f, 1.0f);
			applyVolumes();
		}
		else
		{
			draggingSlider = -1;
			saveSettings(current);
			previewSound(id);
		}
	}

	DrawRectangleRec(Rectangle(x, y + 34, TRACK_W, 10), Color(60, 62, 85, 255));
	DrawRectangleRec(Rectangle(x, y + 34, TRACK_W * *value, 10), Color(0, 180, 90, 255));
	DrawRectangleRec(Rectangle(x + TRACK_W * *value - 6, y + 28, 12, 22), Color(255, 255, 255, 255));
}

private void applyVolumes()
{
	SetMasterVolume(current.masterVolume);
	applySfxVolume(current.sfxVolume);
	// music volume is applied each frame in audioUpdate
}

private void captureKey()
{
	int key = GetKeyPressed();
	if (key == 0) return;
	if (key == KeyboardKey.KEY_ESCAPE)
	{
		waitingFor = -1;
		return;
	}
	foreach (j; 0 .. N_BINDINGS)
	{
		if (j != waitingFor && current.bindings[j] == key)
		{
			current.bindings[j] = current.bindings[waitingFor];
		}
	}
	current.bindings[waitingFor] = key;
	waitingFor = -1;
	saveSettings(current);
}

bool settingsUpdateDraw()
{
	bool wasWaiting = waitingFor >= 0;
	if (wasWaiting) captureKey();

	// keyboard navigation (suspended while rebinding a key)
	act = false;
	adj = 0;
	if (!wasWaiting)
	{
		if (menuDown()) focus = (focus + 1) % F_COUNT;
		if (menuUp()) focus = (focus + F_COUNT - 1) % F_COUNT;
		if (menuRight()) adj = 1;
		if (menuLeft()) adj = -1;
		act = menuConfirm();

		if (focus == F_RES && adj != 0)
		{
			selectedRes += adj;
			if (selectedRes < 0) selectedRes = 0;
			if (selectedRes > validCount - 1) selectedRes = validCount - 1;
		}
		float* sel = null;
		if (focus == F_VOL) sel = &current.masterVolume;
		else if (focus == F_MUSIC) sel = &current.musicVolume;
		else if (focus == F_SFX) sel = &current.sfxVolume;

		if (sel !is null && adj != 0)
		{
			*sel = clampf(*sel + adj * 0.05f, 0.0f, 1.0f);
			applyVolumes();
			saveSettings(current);
			previewSound(focus);
		}
	}

	DrawRectangle(0, 0, W, H, Color(0, 0, 0, 170));
	Rectangle panel = Rectangle(140, 30, 1000, 660);
	DrawRectangleRounded(panel, 0.04f, 8, Color(16, 18, 32, 245));
	DrawRectangleRoundedLines(panel, 0.04f, 8, Color(120, 130, 170, 255));

	centeredTextAt("SETTINGS", 40, W * 0.5f, 52, Color(120, 255, 170, 255));

	float colX = 200;
	float col2X = 700;
	Color header = Color(255, 230, 120, 255);


version (WebAssembly) {}
else version (Android) {}
else
{
	// Video
	drawText("VIDEO", cast(int) colX, 130, 26, header);
	drawResolutionSelector(colX, 175);
}

version (Android) {}
else
{

	if (hit(F_FULL, button(Rectangle(colX, 330, 240, 40),
		current.fullscreen ? "Fullscreen: ON" : "Fullscreen: OFF", 18, focus == F_FULL)))
	{
		toggleFullscreenSetting();
	}
}

	// Audio
	drawText("AUDIO", cast(int) colX, 395, 26, header);
	drawSlider(colX, 435, "Master volume", &current.masterVolume, F_VOL);
	drawSlider(colX, 500, "Music volume", &current.musicVolume, F_MUSIC);
	drawSlider(colX, 565, "SFX volume", &current.sfxVolume, F_SFX);

	// Controls
	drawText("CONTROLS", cast(int) col2X, 130, 26, header);
	float cy = 175;
	foreach (i; 0 .. N_BINDINGS)
	{
		char[16] nameBuf;
		char[64] label;
		if (waitingFor == i)
		{
			snprintf(label.ptr, label.length, "%s : press a key...", ACTION_LABELS[i]);
		}
		else
		{
			snprintf(label.ptr, label.length, "%s : %s", ACTION_LABELS[i], keyName(current.bindings[i], nameBuf[]));
		}
		if (hit(F_BIND + i, button(Rectangle(col2X, cy, 300, 40), label.ptr, 18, focus == F_BIND + i)))
		{
			while (GetKeyPressed() != 0) {} // drop keys queued before the click / Enter
			waitingFor = i;
		}
		cy += 48;
	}

	if (hit(F_RESET, button(Rectangle(col2X, cy + 6, 300, 40), "Reset Controls", 18, focus == F_RESET)))
	{
		SettingsData defaults;
		current.bindings = defaults.bindings;
		waitingFor = -1;
		saveSettings(current);
	}

	bool close = false;
	if (hit(F_CLOSE, button(Rectangle(W * 0.5f - 80, 625, 160, 48), "Close", 22, focus == F_CLOSE))) close = true;
	if (!wasWaiting && menuCancel()) close = true;

	if (close)
	{
		waitingFor = -1;
		draggingSlider = -1;
		focus = 0;
		saveSettings(current);
	}
	return close;
}
