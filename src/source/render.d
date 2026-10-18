module render;

import common;
import assets;
import player;
import trash;
import ui;
import hud;
import touch: drawTouchControls;
import core.stdc.stdio : snprintf;
import core.stdc.math : cosf, sinf;

enum int N_STARS = 500;

__gshared Vector2[N_STARS] stars;
__gshared Camera2D cam;

void initStars()
{
	foreach (ref s; stars) s = Vector2(frange(0, WORLD_W), frange(0, WORLD_H));
}

void initCamera()
{
	cam = Camera2D(Vector2(W / 2.0f, PLAY_H / 2.0f), rocket.pos, 0, 3);
}

void updateCamera(float dt)
{
	float INITIAL_ZOOM = 1.4f;
	float URGENCY_ADD = 1.0f;

	// Real initial zoom | Urgency zoom
	float targetZoom = INITIAL_ZOOM + URGENCY_ADD * urgency();
	cam.zoom += (targetZoom - cam.zoom) * clampf(4.0f * dt, 0, 1);

	float hw = W / (2.0f * cam.zoom);
	float hh = PLAY_H / (2.0f * cam.zoom);

	Vector2 t = cam.target;
	t = vadd(t, vmul(vsub(rocket.pos, t), clampf(7.0f * dt, 0, 1)));
	t.x = hw * 2 >= WORLD_W ? CENTER.x : clampf(t.x, hw, WORLD_W - hw);
	t.y = hh * 2 >= WORLD_H ? CENTER.y : clampf(t.y, hh, WORLD_H - hh);
	cam.target = t;
}

// World Objects
void drawParticles()
{
	foreach (ref pt; parts)
	{
		if (pt.life <= 0) continue;
		Color c = pt.color;
		c.a = cast(ubyte)(255 * clampf(pt.life / pt.maxLife, 0, 1));
		DrawCircleV(pt.pos, pt.size, c);
	}
}

void drawDeathExplosion()
{
	if (deathFx <= 0 || explosionTex.id == 0) return;
	float t = 1.0f - deathFx / DEATH_FX_TIME;// 0..1
	float a = sinf(t * PI_F); // fade
	float h = 110.0f * (0.6f + 0.8f * t); // grows while fading
	float w = h * explosionTex.width / explosionTex.height;
	DrawTexturePro(explosionTex,
		Rectangle(0, 0, explosionTex.width, explosionTex.height),
		Rectangle(rocket.pos.x, rocket.pos.y, w, h),
		Vector2(w / 2, h / 2), 0,
		Color(255, 255, 255, cast(ubyte)(255 * clampf(a, 0, 1))));
}

void drawRocket()
{
	if (rocket.invuln > 0 && (cast(int)(rocket.invuln * 14)) % 2 == 0) return;
	Vector2 n = Vector2(cosf(rocket.angle), sinf(rocket.angle));
	Vector2 s = Vector2(-n.y, n.x);

	// flame first, so it sits behind the body (always code-generated)
	if (rocket.thrusting)
	{
		Vector2 f1 = vadd(vsub(rocket.pos, vmul(n, 12)), vmul(s, 5));
		Vector2 f2 = vsub(vsub(rocket.pos, vmul(n, 12)), vmul(s, 5));
		Vector2 f3 = vsub(rocket.pos, vmul(n, frange(22, 34)));
		Color fc = Color(255, 160, 30, 255);
		DrawTriangle(f1, f2, f3, fc);
		DrawTriangle(f2, f1, f3, fc);
	}

	if (rocketTex.id != 0)
	{
		float h = ROCKET_DRAW_H;
		float w = h * rocketTex.width / rocketTex.height;
		DrawTexturePro(rocketTex,
			Rectangle(0, 0, rocketTex.width, rocketTex.height),
			Rectangle(rocket.pos.x, rocket.pos.y, w, h),
			Vector2(w / 2, h / 2),
			rocket.angle * 57.2958f + ROCKET_SPRITE_DEG,
			Color(255, 255, 255, 255));
		return;
	}

	// fallback: original triangle rocket
	Vector2 tip = vadd(rocket.pos, vmul(n, 18));
	Vector2 bl = vadd(vsub(rocket.pos, vmul(n, 12)), vmul(s, 11));
	Vector2 br = vsub(vsub(rocket.pos, vmul(n, 12)), vmul(s, 11));
	Color body = Color(240, 245, 255, 255);
	DrawTriangle(tip, bl, br, body);
	DrawTriangle(tip, br, bl, body);
	DrawTriangleLines(tip, bl, br, Color(80, 200, 255, 255));
}

void drawTrash()
{
	foreach (ref t; trash.trash)
	{
		if (!t.alive) continue;
		int k = cast(int) t.kind;
		Texture2D tex = trashTex[k];

		if (tex.id != 0)
		{
			float tw = cast(float) tex.width / trashFrames[k];
			float th = cast(float) tex.height;
			float d = t.radius * 2;
			float dh = d * th / tw;
			DrawTexturePro(tex,
				Rectangle(t.variant * tw, 0, tw, th),
				Rectangle(t.pos.x, t.pos.y, d, dh),
				Vector2(d / 2, dh / 2),
				t.rot * 57.2958f,
				Color(255, 255, 255, 255));
			continue;
		}

		// fallback: original colored polygons
		Color c;
		final switch (t.kind)
		{
			case Kind.light: c = Color(200, 200, 210, 255); break;
			case Kind.heavy: c = Color(170, 110, 70, 255); break;
			case Kind.fast:c = Color(255, 90, 90, 255); break;
			case Kind.large: c = Color(150, 130, 200, 255); break;
		}
		int sides = t.kind == Kind.light ? 5 : t.kind == Kind.heavy ? 6 : t.kind == Kind.fast ? 3 : 8;
		DrawPoly(t.pos, sides, t.radius, t.rot * 57.2958f, c);
		DrawPolyLinesEx(t.pos, sides, t.radius, t.rot * 57.2958f, 2, Color(30, 30, 40, 255));
	}
}

// HUD //
void drawBar(int x, int y, int w, int h, float frac, Color c, const(char)* label)
{
	DrawRectangle(x, y, w, h, Color(40, 40, 55, 255));
	DrawRectangle(x, y, cast(int)(w * clampf(frac, 0, 1)), h, c);
	DrawRectangleLines(x, y, w, h, Color(160, 160, 180, 255));
	drawText(label, x + 4, y + 2, 12, Color(255, 255, 255, 255));
}

void drawMinimap()
{
	enum float S = 0.045f;
	int mw = cast(int)(WORLD_W * S), mh = cast(int)(WORLD_H * S);
	int mx = W - mw - 10, my = 10;
	DrawRectangle(mx, my, mw, mh, Color(0, 0, 0, 140));
	DrawRectangleLines(mx, my, mw, mh, Color(120, 130, 170, 255));
	Vector2 c = Vector2(mx + CENTER.x * S, my + CENTER.y * S);
	DrawCircleV(c, EARTH_R * S, Color(30, 90, 170, 255));
	DrawCircleLines(cast(int)c.x, cast(int)c.y, RING_R * S, Color(80, 255, 140, 255));
	foreach (ref t; trash.trash)
	{
		if (t.alive)
		{
			DrawPixel(mx + cast(int)(t.pos.x * S), my + cast(int)(t.pos.y * S), Color(255, 200, 120, 255));
		}
	}
	DrawCircle(mx + cast(int)(rocket.pos.x * S), my + cast(int)(rocket.pos.y * S), 3, Color(255, 255, 255, 255));
}

// scene
void drawWorld()
{
	ClearBackground(Color(16, 16, 32, 255));
	// BeginMode2D(cam);

	Camera2D c = cam;
	if (shakeAmt > 0 && (state == State.playing || state == State.over))
	{
		c.offset.x += frange(-1, 1) * shakeAmt;
		c.offset.y += frange(-1, 1) * shakeAmt;
	}
	BeginMode2D(c);

	foreach (ref s; stars)
	{
		DrawCircleV(s, 1.5f, Color(180, 190, 220, 160));
	}

	DrawRectangleLinesEx(Rectangle(0, 0, WORLD_W, WORLD_H), 6, Color(120, 60, 60, 255));

	DrawCircleV(CENTER, EARTH_R + 60, Color(33, 47, 64, 255)); // Out
	DrawCircleV(CENTER, EARTH_R + 28, Color(37, 58, 85, 255)); // Middle
	DrawCircleV(CENTER, EARTH_R, Color(34, 65, 106, 255)); // Core
	DrawCircleV(Vector2(CENTER.x - 60, CENTER.y - 45), 85, Color(43, 109, 62, 255)); // Continents
	DrawCircleV(Vector2(CENTER.x + 85, CENTER.y + 65), 55, Color(43, 109, 62, 255)); // Continents

	DrawRing(CENTER, RING_R - 3, RING_R + 3, 0, 360, 240, Color(80, 255, 140, 220));
	DrawRing(CENTER, RING_R - 40, RING_R, 0, 360, 240, Color(80, 255, 140, 25));

	if (pullFxAmt > 0.01f)
	{
		float e = 1.0f - (1.0f - pullFxAmt) * (1.0f - pullFxAmt); // ease-out
		float outer = PULL_RANGE * e;// grows on activate, shrinks on release
		DrawCircleV(rocket.pos, outer, Color(60, 140, 255, cast(ubyte)(28 * pullFxAmt)));
		enum int RINGS = 4;
		foreach (i; 0 .. RINGS)
		{
			float ph = pullPhase * 1.1f + cast(float) i / RINGS;
			ph -= cast(int) ph;// 0..1
			float r = outer * (1.0f - ph) + 6; // rings travel inward
			float a = 200.0f * pullFxAmt * clampf(ph * 3.0f, 0, 1) * (1.0f - ph * 0.3f);
			DrawRing(rocket.pos, r - 2.5f, r, 0, 360, 48, Color(90, 170, 255, cast(ubyte) a));
		}
	}
	if (pushFx > 0)
	{
		float fk = pushFx / 0.3f;
		float pr = PUSH_RANGE * (1.0f - fk);
		DrawCircleV(rocket.pos, pr, Color(255, 80, 200, cast(ubyte)(45 * fk)));
		DrawCircleLines(cast(int)rocket.pos.x, cast(int)rocket.pos.y, pr, Color(255, 80, 200, 220));
	}

	drawTrash();
	drawParticles();
	drawDeathExplosion();
	if (state != State.over || rocket.hp > 0) drawRocket();
	EndMode2D();
}

void drawScene()
{
	drawWorld();
	drawHUD();
	// drawMinimap();
	if (hitFlash > 0)
	{
		float k = clampf(hitFlash / 0.35f, 0, 1);
		DrawRectangle(0, 0, W, H, Color(255, 0, 20, cast(ubyte)(150 * k * k)));
	}
}

void centerText(const(char)* s, int y, int size, Color c)
{
	int w = measureText(s, size);
	drawText(s, (W - w) / 2, y, size, c);
}

// Screens //
void drawMenuBackground()
{
	ClearBackground(Color(16, 16, 32, 255));
	// DrawCircleV(Vector2(W / 2.0f, 480), 160, Color(30, 90, 170, 255));
	foreach (ref s; stars)
	{
		float screenX = s.x * (cast(float) W / WORLD_W);
		float screenY = s.y * (cast(float) H / WORLD_H);
		DrawCircleV(Vector2(screenX, screenY), 1.5f, Color(180, 190, 220, 160));
	}
}

void drawMenuTitle()
{
	if (logoTex.id == 0)
	{
		centerText("ORBITAL TRASH", 70, 64, Color(120, 255, 170, 255));
		return;
	}

	float sc = 900.0f / logoTex.width;
	float sy = 450.0f / logoTex.height;
	if (sy < sc) sc = sy;
	float w = logoTex.width * sc;
	DrawTextureEx(logoTex, Vector2((W - w) * 0.5f, 15), 0, sc, Color(255, 255, 255, 255));
}

int drawMenuMain()
{
	drawMenuBackground();
	drawMenuTitle();

	const(char)*[MENU_ITEMS] items = ["Play", "Settings", "Quit"];
	int clicked = -1;

	version (WebAssembly)
	{
		enum limit = MENU_ITEMS - 1;
	}
	else
	{
		enum limit = MENU_ITEMS;
	}


	float y0 = H - 40 - (limit * 56 - 8);
	foreach (i; 0 .. limit)
	{
		Rectangle r = Rectangle(W * 0.5f - 160, y0 + i * 56, 320, 48);
		if (techHovered(r)) aboutFocus = false;
		hoverSelect(r, menuSel, cast(int) i);
		if (techButton(r, items[i], 30, !aboutFocus && i == menuSel))
		{
			menuSel = cast(int) i;
			aboutFocus = false;
			clicked = cast(int) i;
		}
	}

	// About button
	Rectangle ar = Rectangle(20, H - 68, 48, 48);
	if (techHovered(ar)) aboutFocus = true;
	if (techButton(ar, "i", 28, aboutFocus))
	{
		aboutFocus = true; clicked = 100;
	}
	return clicked;
}

int drawMenuPlay()
{
	drawMenuBackground();
	drawMenuTitle();

	char[48] buf;
	const(char)*[PLAY_ITEMS] items = ["60 Seconds", "90 Seconds", "120 Seconds", "Custom", "Endless", "Back"];

	enum float STEP = 44;
	enum float BTN_H = 38;
	float y0 = H - 40 - (PLAY_ITEMS * STEP - (STEP - BTN_H));

	int clicked = -1;
	foreach (i; 0 .. PLAY_ITEMS)
	{
		Rectangle r = Rectangle(W * 0.5f - 160, y0 + i * STEP, 320, BTN_H);
		if (i == 3)
		{
			snprintf(buf.ptr, buf.length, "Custom: %ds", customSeconds);

			// -/+ buttons for the mouse; Left/Right keys still work
			if (techButton(Rectangle(r.x - 52, r.y, 44, BTN_H), "-", 26, menuSubSel == 3))
			{
				menuSubSel = 3;
				changeCustomSeconds(-10);
			}
			if (techButton(Rectangle(r.x + r.width + 8, r.y, 44, BTN_H), "+", 26, menuSubSel == 3))
			{
				menuSubSel = 3;
				changeCustomSeconds(10);
			}
		}
		else
		{
			snprintf(buf.ptr, buf.length, "%s", items[i]);
		}
		hoverSelect(r, menuSubSel, cast(int) i);
		if (techButton(r, buf.ptr, 26, i == menuSubSel))
		{
			menuSubSel = cast(int) i;
			clicked = cast(int) i;
		}
	}
	return clicked;
}

private int techList(const(char)*[] items, int y0, int step, float alpha = 1.0f)
{
	int clicked = -1;
	foreach (i; 0 .. items.length)
	{
		int idx = cast(int) i;
		Rectangle r = Rectangle(W * 0.5f - 160, y0 + idx * step, 320, 48);
		hoverSelect(r, menuSel, idx);
		if (techButton(r, items[i], 30, idx == menuSel, alpha))
		{
			menuSel = idx;
			clicked = idx;
		}
	}
	return clicked;
}

// settings overlay background
void drawSettingsBackground()
{
	if (settingsFromPause) drawScene();
	else drawMenuBackground();
}

void drawPlayScreen()
{
	drawScene();
	version (Android) drawTouchControls();
}

int drawPauseScreen()
{
	drawScene();
	DrawRectangle(0, 0, W, H, Color(0, 0, 0, 150));
	centerText("PAUSED", 200, 56, Color(255, 255, 255, 255));
	const(char)*[3] items = ["Continue", "Settings", "Go to menu"];
	return techList(items[], 300, 60);
}

int drawOverScreen()
{
	drawScene();

	float k = clampf((overTimer - OVER_WAIT) / OVER_FADE, 0, 1);
	if (k <= 0) return -1;

	DrawRectangle(0, 0, W, H, fadeColor(Color(0, 0, 0, 170), k));
	char[64] buf;

	centerText("GAME OVER", 110, 56, fadeColor(Color(255, 120, 120, 255), k));
	centerText(endReason, 180, 30,
		fadeColor(perfect ? Color(120, 255, 170, 255) : Color(230, 230, 240, 255), k));
	snprintf(buf.ptr, buf.length, "Final score: %d", score);
	centerText(buf.ptr, 245, 32, fadeColor(Color(255, 230, 120, 255), k));
	snprintf(buf.ptr, buf.length, "Trash cleared: %d / %d", cleared, totalSpawned);
	centerText(buf.ptr, 295, 28, fadeColor(Color(220, 230, 255, 255), k));
	snprintf(buf.ptr, buf.length, "Best score: %d", bestScore);
	centerText(buf.ptr, 338, 28, fadeColor(Color(220, 230, 255, 255), k));

	const(char)*[2] items = ["Restart", "Menu"];
	return techList(items[], 410, 60, k);
}
