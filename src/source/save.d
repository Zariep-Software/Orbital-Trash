module save;

import core.stdc.stdio;

enum int N_BINDINGS = 7;
enum uint SETTINGS_MAGIC = 0x4F545231; // "OTR1" guards against stale/foreign files
enum uint BEST_MAGIC = 0x4F544231; // "OTB1"
enum BEST_FILE = "best.dat";
enum SETTINGS_FILE = "settings.cfg";

// Settings //

// Default bindings are raylib key codes
// A=65, D=68, W=87, S=83, Z=90, X=88, Esc=256
// Order: left, right, thrust, brake, pull, push, pause
struct SettingsData
{
	uint magic = SETTINGS_MAGIC;
	bool fullscreen = false;
	int resolutionIndex = -1;
	float masterVolume = 1.0f;
	float musicVolume = 1.0f;
	float sfxVolume = 1.0f;
	int[N_BINDINGS] bindings = [65, 68, 87, 83, 90, 88, 256];
}

SettingsData loadSettings()
{
	SettingsData s;
	FILE* f = fopen(SETTINGS_FILE, "rb");
	if (f is null) return s;
	SettingsData tmp;
	size_t n = fread(&tmp, SettingsData.sizeof, 1, f);
	fclose(f);
	if (n != 1 || tmp.magic != SETTINGS_MAGIC) return s;
	return tmp;
}

void saveSettings(ref SettingsData s)
{
	FILE* f = fopen(SETTINGS_FILE, "wb");
	if (f is null) return;
	fwrite(&s, SettingsData.sizeof, 1, f);
	fclose(f);
}

// Score //

private struct BestData
{
	uint magic = BEST_MAGIC;
	int best = 0;
}

int loadBest()
{
	FILE* f = fopen(BEST_FILE, "rb");
	if (f is null) return 0;
	BestData tmp;
	size_t n = fread(&tmp, BestData.sizeof, 1, f);
	fclose(f);
	if (n != 1 || tmp.magic != BEST_MAGIC || tmp.best < 0) return 0;
	return tmp.best;
}

void saveBest(int best)
{
	FILE* f = fopen(BEST_FILE, "wb");
	if (f is null) return;
	BestData d;
	d.best = best;
	fwrite(&d, BestData.sizeof, 1, f);
	fclose(f);
}
