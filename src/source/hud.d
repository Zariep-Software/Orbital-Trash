module hud;

import common;
import assets;
import player;
import ui;
import upgrades;
import display : mouse;
import settings : bindName, Bind;
import core.stdc.stdio : snprintf;


private enum Color HUD_PANEL = Color(14, 18, 34, 240);
private enum Color HUD_FILL = Color(10, 14, 26, 240);
private enum Color HUD_LINE = Color(90, 130, 190, 255);
private enum Color HUD_TEXT = Color(200, 200, 215, 255);
private enum Color HUD_ICON = Color(35, 38, 48, 255);

// one cell per HP
// First cell: TL, last cell: BR
void drawLifeBar(Rectangle r, int hp, int mh)
{
	drawTechShape(r, 14, HUD_FILL, HUD_LINE);
	if (mh <= 0) return;

	enum float PAD = 5, GAP = 3;
	Rectangle inner = Rectangle(r.x + PAD, r.y + PAD, r.width - 2 * PAD, r.height - 2 * PAD);
	float cw = (inner.width - GAP * (mh - 1)) / mh;

	foreach (i; 0 .. mh)
	{
		Rectangle c = Rectangle(inner.x + i * (cw + GAP), inner.y, cw, inner.height);
		Color col = i < hp ? Color(220, 60, 60, 255) : Color(60, 30, 42, 255);
		drawCutRect(c, 9, i == 0, i == mh - 1, col);
	}
}

void drawProgressBar(Rectangle r, float frac, Color c)
{
	drawTechShape(r, 14, HUD_FILL, HUD_LINE);
	enum float PAD = 5;
	Rectangle inner = Rectangle(r.x + PAD, r.y + PAD, r.width - 2 * PAD, r.height - 2 * PAD);
	frac = clampf(frac, 0, 1);
	Rectangle f = Rectangle(inner.x, inner.y, inner.width * frac, inner.height);
	drawCutRect(f, 9, true, frac >= 0.999f, c);
}

// Ability buttons
void drawAbility(Rectangle r, Texture2D icon, bool pullGlyph, const(char)* label,
	float charge, bool avail, bool active, Color accent)
{
	enum float ROUND = 0.25f; // same roundness as the settings buttons (ui.button)

	ubyte a = avail ? 255 : 110;
	Color line = Color(accent.r, accent.g, accent.b, a);
	Color fill = active ? Color(40, 60, 95, 255) : Color(18, 24, 42, avail ? 240 : 170);
	DrawRectangleRounded(r, ROUND, 8, fill);

	// icon
	float pad = 9;
	Rectangle box = Rectangle(r.x + pad, r.y + pad, r.width - 2 * pad, r.height - 2 * pad);
	Color tint = Color(255, 255, 255, a);
	if (icon.id != 0)
	{
		float s = box.width / icon.width;
		float s2 = box.height / icon.height;
		if (s2 < s) s = s2;
		float dw = icon.width * s, dh = icon.height * s;
		DrawTexturePro(icon,
			Rectangle(0, 0, icon.width, icon.height),
			Rectangle(box.x + (box.width - dw) * 0.5f, box.y + (box.height - dh) * 0.5f, dw, dh),
			Vector2(0, 0), 0, tint);
	}
	else
	{
		// fallback glyph
		Vector2 c = Vector2(r.x + r.width * 0.5f, r.y + r.height * 0.5f);
		float rr = box.width * 0.42f;
		DrawCircleLines(cast(int) c.x, cast(int) c.y, rr, tint);
		float d = pullGlyph ? -1.0f : 1.0f;
		Vector2 t0 = Vector2(c.x + d * rr * 0.55f, c.y);
		Vector2 t1 = Vector2(c.x + d * rr * 0.05f, c.y - rr * 0.4f);
		Vector2 t2 = Vector2(c.x + d * rr * 0.05f, c.y + rr * 0.4f);
		DrawTriangle(t0, t1, t2, tint);
		DrawTriangle(t0, t2, t1, tint);
	}

	// load filter (clipped to the rounded shape)
	if (!avail)
	{
		DrawRectangleRounded(r, ROUND, 8, Color(0, 0, 0, 140));
	}
	else
	{
		float hh = r.height * (1.0f - clampf(charge, 0, 1));
		if (hh > 0.5f)
		{
			BeginScissorMode(cast(int) r.x, cast(int) r.y, cast(int) r.width + 1, cast(int) hh + 1);
			DrawRectangleRounded(r, ROUND, 8, Color(0, 0, 0, 150));
			EndScissorMode();
		}
	}

	// outline on top so the overlay never covers it
	DrawRectangleRoundedLines(r, ROUND, 8, line);

	// label under the button
	int tw = measureText(label, 14);
	drawText(label, cast(int)(r.x + (r.width - tw) * 0.5f), cast(int)(r.y + r.height + 4), 14,
		avail ? HUD_TEXT : Color(120, 120, 140, 255));
}

// Progressive shop
private void drawShopButton(int i, bool live)
{
	Rectangle r = shopRect(i);
	bool maxed = upgMaxed(i);
	bool can = upgCanBuy(i);
	Color ac = UPG_COLOR[i];

	bool hovered = live && CheckCollisionPointRec(mouse(), r);
	Color fill = (hovered && can) ? Color(40, 60, 95, 255) : Color(18, 24, 42, 240);
	Color line = can ? ac : Color(ac.r, ac.g, ac.b, 90);
	drawTechShape(r, 12, fill, line);

	version (Android) {}
	else
	{
		if (hovered && IsMouseButtonReleased(MouseButton.MOUSE_BUTTON_LEFT)) shopClick = i;
	}

	char[32] buf;

	// icon (circle + tile)
	bool lit = can || maxed;
	Vector2 ic = Vector2(r.x + r.width * 0.5f, r.y + 15);
	DrawCircleV(ic, 10, lit ? ac : Color(ac.r, ac.g, ac.b, 90));
	drawUpgIcon(i, ic, 14, Color(HUD_ICON.r, HUD_ICON.g, HUD_ICON.b, lit ? 255 : 110));

	// level / hp line
	if (i == Upg.extraHp)
	{
		version (Android) snprintf(buf.ptr, buf.length, "HP %d/%d", rocket.hp, maxHp);
		else snprintf(buf.ptr, buf.length, "[%d] HP %d/%d", i + 1, rocket.hp, maxHp);
	}
	else
	{
		version (Android) snprintf(buf.ptr, buf.length, "Lv %d/%d", upgLvl[i], upgMaxLvl(i));
		else snprintf(buf.ptr, buf.length, "[%d] Lv %d/%d", i + 1, upgLvl[i], upgMaxLvl(i));
	}
	int tw = measureText(buf.ptr, 14);
	drawText(buf.ptr, cast(int)(r.x + (r.width - tw) * 0.5f), cast(int)(r.y + 26), 14,
		Color(170, 180, 205, 255));

	// cost
	const(char)* costText;
	Color costC;
	if (maxed)
	{
		costText = (i == Upg.extraHp) ? "FULL" : "MAX";
		costC = Color(120, 255, 170, 255);
	}
	else
	{
		snprintf(buf.ptr, buf.length, "%d", upgCost(i));
		costText = buf.ptr;
		costC = can ? Color(255, 230, 120, 255) : Color(200, 110, 110, 255);
	}
	tw = measureText(costText, 18);
	drawText(costText, cast(int)(r.x + (r.width - tw) * 0.5f), cast(int)(r.y + 45), 18, costC);
}

// Arcade temporary upgrades
private void drawUpgradeChips()
{
	char[16] buf;
	int slot = 0;
	foreach (i; 0 .. N_UPG)
	{
		if (i == Upg.extraHp || upgLvl[i] <= 0) continue;
		Rectangle r = shopRect(slot++);
		drawTechShape(r, 12, HUD_FILL, UPG_COLOR[i]);

		// icon (circle + tile)
		Vector2 ic = Vector2(r.x + r.width * 0.5f, r.y + 20);
		DrawCircleV(ic, 13, UPG_COLOR[i]);
		drawUpgIcon(i, ic, 18, HUD_ICON);

		snprintf(buf.ptr, buf.length, "Lv %d", upgLvl[i]);
		int tw = measureText(buf.ptr, 18);
		drawText(buf.ptr, cast(int)(r.x + (r.width - tw) * 0.5f), cast(int)(r.y + 38), 18,
			Color(255, 230, 120, 255));
	}
}

void drawHUD()
{
	bool prog = gameMode == GameMode.progressive;
	bool live = prog && state == State.playing;
	shopClick = -1;

	// panel + accent line
	DrawRectangle(0, hudY(), W, HUD_H, HUD_PANEL);
	version (Android) DrawRectangle(0, hudY() + HUD_H - 3, W, 3, HUD_LINE);
	else DrawRectangle(0, hudY(), W, 3, HUD_LINE);

	char[16] keyBuf;
	char[32] label;
	char[64] buf;

	enum float PAD = 14;
	float top = hudY() + PAD + 2;
	float inner = HUD_H - 2 * PAD - 2;

	// left column: life + trash progress
	float barH = (inner - 8) * 0.5f;
	drawLifeBar(Rectangle(20, top, 300, barH), rocket.hp, cast(int) maxHp);

	if (prog || endless)
	{
		Rectangle cr = Rectangle(20, top + barH + 8, 300, barH);
		drawTechShape(cr, 14, HUD_FILL, HUD_LINE);
		snprintf(buf.ptr, buf.length, "Cleared: %d", cleared);
		drawText(buf.ptr, cast(int)(cr.x + 14), cast(int)(cr.y + (barH - 18) * 0.5f), 18,
			Color(220, 230, 255, 255));
	}
	else
	{
		int total = initialTrash;
		int done = cleared < 0 ? 0 : (cleared > total ? total : cleared);
		float frac = total > 0 ? cast(float) done / total : 0;
		drawProgressBar(Rectangle(20, top + barH + 8, 190, barH), frac, Color(80, 255, 140, 255));
		snprintf(buf.ptr, buf.length, "%d/%d (%.0f%%)", done, total, frac * 100.0f);
		drawText(buf.ptr, 220, cast(int)(top + barH + 8 + (barH - 18) * 0.5f), 18, Color(220, 230, 255, 255));
	}

	// abilities
	float bs = inner - 18; // room for the label underneath
	bool avail = rocketInsideRing();
	float ax = 350;

	snprintf(label.ptr, label.length, "Pull (%s)", bindName(Bind.pull, keyBuf[]));
	drawAbility(Rectangle(ax, top, bs, bs), pullIconTex, true, label.ptr,
		rocket.pullEnergy, avail, pullFxAmt > 0.5f, Color(90, 170, 255, 255));

	float pf = 1.0f - clampf(rocket.pushCd / PUSH_COOLDOWN, 0, 1);
	snprintf(label.ptr, label.length, "Push (%s)", bindName(Bind.push, keyBuf[]));
	drawAbility(Rectangle(ax + bs + 30, top, bs, bs), pushIconTex, false, label.ptr,
		pf, avail, false, Color(255, 80, 200, 255));

	// middle: shop / upgrades
	if (prog)
	{
		foreach (i; 0 .. N_UPG) drawShopButton(i, live);
	}
	else if (arcadeItems)
	{
		drawUpgradeChips();
	}

	// right: time + score panel
	Rectangle pr = Rectangle(W - 190, top, 170, inner);
	drawTechShape(pr, 14, HUD_FILL, HUD_LINE);

	if (prog)
	{
		int s = cast(int) elapsed;
		snprintf(buf.ptr, buf.length, "Time: %d:%02d", s / 60, s % 60);
	}
	else if (endless)
	{
		int s = cast(int) elapsed;
		snprintf(buf.ptr, buf.length, "Time: %d:%02d", s / 60, s % 60);
	}
	else snprintf(buf.ptr, buf.length, "Time: %d", cast(int)(timeLeft + 0.99f));
	Color tc = (!endless && timeLeft <= 10 && (cast(int)(timeLeft * 3)) % 2 == 0)
		? Color(255, 80, 80, 255) : Color(255, 255, 255, 255);
	drawText(buf.ptr, cast(int)(pr.x + 16), cast(int)(pr.y + inner * 0.5f - 28), 26, tc);

	if (prog) snprintf(buf.ptr, buf.length, "Pts: %d", score);
	else snprintf(buf.ptr, buf.length, "Score: %d", score);
	drawText(buf.ptr, cast(int)(pr.x + 16), cast(int)(pr.y + inner * 0.5f + 4), 26, Color(255, 230, 120, 255));
}
