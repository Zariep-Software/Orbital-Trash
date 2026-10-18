module pickups;

import common;
import player;
import upgrades;
import assets : playSfx, sNav;
import core.stdc.math : cosf, sinf, expf;

enum int MAX_PICK = 8;
enum int MAX_ALIVE = 5; // at most this many on screen
enum float PICK_R = 14.0f;
enum float PICK_LIFE = 20.0f; //seconds before it vanishes

struct Pickup
{
	bool alive;
	int id;
	Vector2 pos, vel;
	float life;
}

__gshared Pickup[MAX_PICK] pickList;
private __gshared float pickTimer = 8;

void resetPickups()
{
	foreach (ref p; pickList) p.alive = false;
	pickTimer = frange(8, 12);
}

//  skipp upgrades that would do nothing
private int pickRandomId()
{
	for (int tries = 0; tries < 20; tries++)
	{
		int r = GetRandomValue(0, 99);
		int id = r < 25 ? Upg.pullRange
			: r < 50 ? Upg.pushForce
			: r < 70 ? Upg.brake
			: r < 85 ? Upg.extraHp : Upg.hpSlot;
		if (!upgMaxed(id)) return id;
	}
	return -1;
}

private void spawnPickup()
{
	int alive = 0;
	foreach (ref p; pickList) if (p.alive) alive++;
	if (alive >= MAX_ALIVE) return;

	int id = pickRandomId();
	if (id < 0) return;

	foreach (ref p; pickList)
	{
		if (p.alive) continue;
		p = Pickup.init;
		p.alive = true;
		p.id = id;
		p.life = PICK_LIFE;
		for (int tries = 0; tries < 40; tries++)
		{
			float a = frange(0, 2 * PI_F);
			float d = frange(EARTH_R + 90, RING_R - 90);
			p.pos = Vector2(CENTER.x + cosf(a) * d, CENTER.y + sinf(a) * d);
			if (vlen(vsub(p.pos, rocket.pos)) > 220) break;
		}
		float va = frange(0, 2 * PI_F);
		float sp = frange(8, 22);
		p.vel = Vector2(cosf(va) * sp, sinf(va) * sp);
		return;
	}
}

void updatePickups(float dt, Actions act)
{
	pickTimer -= dt;
	if (pickTimer <= 0)
	{
		pickTimer = frange(10, 16);
		spawnPickup();
	}

	foreach (ref p; pickList)
	{
		if (!p.alive) continue;
		p.life -= dt;
		if (p.life <= 0)
		{
			p.alive = false;
			continue;
		}

		Vector2 d = vsub(rocket.pos, p.pos);
		float dist = vlen(d);

		// magnet
		float range = pullRange();
		if (act.pulling && dist < range)
		{
			float f = 1.0f - dist / range;
			p.vel = vadd(p.vel, vmul(vnorm(d), PULL_FORCE * (f + f * f) * dt));
		}

		// keep inside the ring
		Vector2 fc = vsub(p.pos, CENTER);
		if (vlen(fc) > RING_R - 40)
		{
			p.vel = vadd(p.vel, vmul(vnorm(vmul(fc, -1.0f)), 160.0f * dt));
		}

		p.vel = vmul(p.vel, expf(-0.6f * dt));
		p.pos = vadd(p.pos, vmul(p.vel, dt));

		// collect
		dist = vlen(vsub(rocket.pos, p.pos));
		if (dist < PICK_R + ROCKET_R)
		{
			applyUpgrade(p.id);
			announceUpgrade(p.id);
			Color c = UPG_COLOR[p.id];
			burst(p.pos, 18, c, 200, 0.5f);
			playSfx(sNav);
			p.alive = false;
		}
	}
}
