module save;

import core.stdc.stdio;

enum int N_BINDINGS = 7;
enum int N_UPG = 5; // number of upgrades
enum uint SETTINGS_MAGIC = 0x4F545231; // "OTR1" guards against stale/foreign files
enum uint BEST_MAGIC = 0x4F544231; // "OTB1"
enum uint PBEST_MAGIC = 0x4F545032; // "OTP2" progressive best
enum uint PROG_MAGIC = 0x4F545031; // "OTP1" progressive save game
enum uint EBEST_MAGIC = 0x4F544533; // "OTE3" endless best time
enum EBEST_FILE = "endless_best.dat";
enum BEST_FILE = "best.dat";
enum PBEST_FILE = "progressive_best.dat";
enum PROG_FILE = "progressive.dat";
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

int loadBestProg()
{
	FILE* f = fopen(PBEST_FILE, "rb");
	if (f is null) return 0;
	BestData tmp;
	size_t n = fread(&tmp, BestData.sizeof, 1, f);
	fclose(f);
	if (n != 1 || tmp.magic != PBEST_MAGIC || tmp.best < 0) return 0;
	return tmp.best;
}

void saveBestProg(int best)
{
	FILE* f = fopen(PBEST_FILE, "wb");
	if (f is null) return;
	BestData d;
	d.magic = PBEST_MAGIC;
	d.best = best;
	fwrite(&d, BestData.sizeof, 1, f);
	fclose(f);
}

int loadBestEndless()
{
	FILE* f = fopen(EBEST_FILE, "rb");
	if (f is null) return 0;
	BestData tmp;
	size_t n = fread(&tmp, BestData.sizeof, 1, f);
	fclose(f);
	if (n != 1 || tmp.magic != EBEST_MAGIC || tmp.best < 0) return 0;
	return tmp.best;
}

void saveBestEndless(int best)
{
	FILE* f = fopen(EBEST_FILE, "wb");
	if (f is null) return;
	BestData d;
	d.magic = EBEST_MAGIC;
	d.best = best;
	fwrite(&d, BestData.sizeof, 1, f);
	fclose(f);
}

// Progressive save game //

struct ProgSave
{
	uint magic = PROG_MAGIC;
	int score = 0;
	int earned = 0;
	int cleared = 0;
	int hp = 1;
	float elapsed = 0;
	int[N_UPG] lvl;
}

bool loadProg(out ProgSave s)
{
	s = ProgSave.init;
	version (WebAssembly)
	{
		return false;
	}
	else
	{
		FILE* f = fopen(PROG_FILE, "rb");
		if (f is null) return false;
		ProgSave tmp;
		size_t n = fread(&tmp, ProgSave.sizeof, 1, f);
		fclose(f);
		if (n != 1 || tmp.magic != PROG_MAGIC || tmp.hp < 1) return false;
		s = tmp;
		return true;
	}
}

void saveProg(ref ProgSave s)
{
	version (WebAssembly)
	{
	}
	else
	{
		FILE* f = fopen(PROG_FILE, "wb");
		if (f is null) return;
		fwrite(&s, ProgSave.sizeof, 1, f);
		fclose(f);
	}
}

void deleteProg()
{
	version (WebAssembly)
	{
	}
	else
	{
		remove(PROG_FILE);
	}
}
