module upgrades;

import common;
import player : rocket;
import save : ProgSave, saveProg;
import assets : upgradesTex;
import core.stdc.stdio : snprintf;

// Order must match enum Upg in common.d
immutable(char)*[N_UPG] UPG_NAMES = ["Pull Range", "Push Force", "Extra HP", "HP Slot", "Brake Drag"];
immutable(char)*[N_UPG] UPG_GLYPH = ["R", "F", "+", "H", "B"]; // fallback
immutable Color[N_UPG] UPG_COLOR = [
	Color(90, 170, 255, 255), // pull range
	Color(255, 80, 200, 255), // push force
	Color(230, 70, 70, 255), // extra hp
	Color(255, 170, 60, 255), // hp slot
	Color(120, 255, 200, 255) // brake drag
];

// Tweak costs / limits
private immutable int[N_UPG] BASE_COST = [150, 150, 100, 250, 100];
private immutable int[N_UPG] STEP_COST = [100, 100, 0, 150, 75];
private immutable int[N_UPG] MAX_LVL = [20, 20, 0, 20, 10]; // Extra HP is a heal, it has no levels

int upgMaxLvl(int id)
{
	return MAX_LVL[id];
}

void resetUpgrades()
{
	foreach (ref l; upgLvl) l = 0;
}

bool upgMaxed(int id)
{
	if (id == Upg.extraHp) return rocket.hp >= maxHp;
	return upgLvl[id] >= MAX_LVL[id];
}

int upgCost(int id)
{
	return BASE_COST[id] + STEP_COST[id] * upgLvl[id];
}

bool upgCanBuy(int id)
{
	return !upgMaxed(id) && score >= upgCost(id);
}

void applyUpgrade(int id)
{
	switch (id)
	{
		case Upg.extraHp:
			if (rocket.hp < maxHp) rocket.hp++;
			break;
		case Upg.hpSlot:
			upgLvl[id]++;
			maxHp++;
			rocket.hp++;
			break;
		default:
			upgLvl[id]++;
			break;
	}
}

void announceUpgrade(int id)
{
	char[48] b;
	if (id == Upg.extraHp) snprintf(b.ptr, b.length, "+1 HP");
	else if (id == Upg.hpSlot) snprintf(b.ptr, b.length, "HP Slot +1 (max %d)", maxHp);
	else snprintf(b.ptr, b.length, "%s Lv %d", UPG_NAMES[id], upgLvl[id]);
	showToast(b.ptr);
}

// Progressive shop purchase
bool buyUpgrade(int id)
{
	if (id < 0 || id >= N_UPG) return false;
	if (upgMaxed(id))
	{
		showToast(id == Upg.extraHp ? "HP is already full" : "Already maxed");
		return false;
	}
	if (score < upgCost(id))
	{
		char[48] b;
		snprintf(b.ptr, b.length, "Need %d points", upgCost(id));
		showToast(b.ptr);
		return false;
	}
	score -= upgCost(id);
	applyUpgrade(id);
	announceUpgrade(id);
	saveProgress();
	return true;
}

void saveProgress()
{
	if (!CAN_SAVE || gameMode != GameMode.progressive) return;
	ProgSave s;
	s.score = score;
	s.earned = earned;
	s.cleared = cleared;
	s.hp = rocket.hp < 1 ? 1 : rocket.hp;
	s.elapsed = elapsed;
	s.lvl = upgLvl;
	saveProg(s);
}

void drawUpgIcon(int id, Vector2 c, float size, Color tint = Color(255, 255, 255, 255))
{
	Texture2D t = upgradesTex;
	int fs = t.height; // tile size = image height
	if (t.id != 0 && fs > 0 && (id + 1) * fs <= t.width)
	{
		Rectangle src = Rectangle(id * fs, 0, fs, fs);
		Rectangle dst = Rectangle(c.x - size * 0.5f, c.y - size * 0.5f, size, size);
		DrawTexturePro(t, src, dst, Vector2(0, 0), 0.0f, tint);
	}
	else
	{
		// fallback: old letter glyph
		float gs = size * 0.9f;
		Vector2 m = MeasureTextEx(gameFont, UPG_GLYPH[id], gs, 1);
		DrawTextEx(gameFont, UPG_GLYPH[id], Vector2(c.x - m.x * 0.5f, c.y - m.y * 0.5f), gs, 1, tint);
	}
}
