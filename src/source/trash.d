module trash;

import common;
import player;
import assets : trashFrames, sGExplosion, playSfx;
import core.stdc.math : cosf, sinf, expf, sqrtf, fabsf;

enum int MAX_TRASH = 256;

enum Kind
{
	light,
	heavy,
	fast,
	large
}

struct Trash
{
	bool alive;
	Kind kind;
	Vector2 pos, vel;
	float radius, mass, rot, rotSpeed;
	float pulled = 0;
	int points;
	int variant;
	float pushed = 0;
}

__gshared Trash[MAX_TRASH] trash;
__gshared float spawnTimer = 0;

enum float TRASH_RESTITUTION = 0.5f; // 1 = perfect bounce, 0 = stick together
enum float TRASH_HIT_DAMP = 0.92f; // speed loss

void updateTrashCollisions()
{
	foreach (i; 0 .. MAX_TRASH)
	{
		if (!trash[i].alive) continue;
		foreach (j; i + 1 .. MAX_TRASH)
		{
			if (!trash[j].alive) continue;
			Trash* a = &trash[i];
			Trash* b = &trash[j];

			Vector2 d = vsub(b.pos, a.pos);
			float minDist = a.radius + b.radius;

			// cheap reject
			if (d.x * d.x + d.y * d.y >= minDist * minDist) continue;

			float dist = vlen(d);
			Vector2 n = dist > 0.0001f ? vmul(d, 1.0f / dist) : Vector2(1, 0);

			// push apart, lighter pieces moves more
			float overlap = minDist - dist;
			float invA = 1.0f / a.mass;
			float invB = 1.0f / b.mass;
			float total = invA + invB;
			a.pos = vsub(a.pos, vmul(n, overlap * invA / total));
			b.pos = vadd(b.pos, vmul(n, overlap * invB / total));

			// only exchange momentum if they are approaching
			float vn = vdot(vsub(a.vel, b.vel), n);
			if (vn <= 0) continue;

			float imp = (1.0f + TRASH_RESTITUTION) * vn / total;
			a.vel = vsub(a.vel, vmul(n, imp * invA));
			b.vel = vadd(b.vel, vmul(n, imp * invB));

			// speed loss
			a.vel = vmul(a.vel, TRASH_HIT_DAMP);
			b.vel = vmul(b.vel, TRASH_HIT_DAMP);

			// subtle spin
			a.rotSpeed = clampf(a.rotSpeed - vn * 0.002f, -4, 4);
			b.rotSpeed = clampf(b.rotSpeed + vn * 0.002f, -4, 4);
		}
	}
}

void spawnTrash(Kind k, bool fromEdge)
{
	foreach (ref t; trash)
	{
		if (t.alive) continue;
		t = Trash.init;
		t.pulled = 0;
		t.alive = true;
		t.kind = k;

		t.variant = GetRandomValue(0, trashFrames[cast(int) k] - 1);

		final switch (k)
		{
			case Kind.light: t.radius = 10; t.mass = 1; t.points = 10; break;
			case Kind.heavy: t.radius = 17; t.mass = 4; t.points = 25; break;
			case Kind.fast: t.radius = 8; t.mass = 1; t.points = 10; break;
			case Kind.large: t.radius = 30; t.mass = 9; t.points = 50; break;
		}
		float speed = (k == Kind.fast) ? frange(70, 140) : frange(8, 30);
		if (k == Kind.heavy || k == Kind.large) speed *= 0.5f;

		for (int tries = 0; tries < 60; tries++)
		{
			float a = frange(0, 2 * PI_F);
			float d = fromEdge ? RING_R - t.radius - 30
				: frange(EARTH_R + t.radius + 20, RING_R - t.radius - 40);
			t.pos = Vector2(CENTER.x + cosf(a) * d, CENTER.y + sinf(a) * d);
			if (vlen(vsub(t.pos, rocket.pos)) > 160 + t.radius) break;
		}
		float va = frange(0, 2 * PI_F);
		if (fromEdge)
		{
			Vector2 toC = vnorm(vsub(CENTER, t.pos));
			t.vel = vmul(toC, speed);
		}
		else t.vel = Vector2(cosf(va) * speed, sinf(va) * speed);
		t.rot = frange(0, 6.28f);
		t.rotSpeed = frange(-2, 2);
		totalSpawned++;
		return;
	}
}

int trashInside()
{
	int n = 0;
	foreach (ref t; trash) if (t.alive) n++;
	return n;
}

void resetTrash()
{
	foreach (ref t; trash) t.alive = false;
	spawnTimer = 0;
}

void spawnInitialTrash()
{
	foreach (_; 0 .. 45) spawnTrash(Kind.light, false);
	foreach (_; 0 .. 20) spawnTrash(Kind.heavy, false);
	foreach (_; 0 .. 15) spawnTrash(Kind.fast, false);
	foreach (_; 0 .. 8) spawnTrash(Kind.large, false);
}

void updateSpawning(float dt)
{
	spawnTimer += dt;
	float interval = clampf(5.0f - elapsed * 0.03f, 2.0f, 5.0f);
	if (spawnTimer >= interval)
	{
		spawnTimer = 0;
		int r = GetRandomValue(0, 99);
		Kind k = r < 45 ? Kind.light : r < 70 ? Kind.fast : r < 90 ? Kind.heavy : Kind.large;
		if (elapsed < 20 && k == Kind.large) k = Kind.light;
		spawnTrash(k, true);
	}
}

void updateTrash(float dt, Actions act)
{
	foreach (ref t; trash)
	{
		if (!t.alive) continue;
		Vector2 d = vsub(rocket.pos, t.pos);
		float dist = vlen(d);
		Vector2 n = vnorm(d);

		if (t.pulled > 0) t.pulled -= dt;
		if (t.pushed > 0) t.pushed -= dt;

		if (act.pulling && dist < PULL_RANGE)
		{
			float f = 1.0f - dist / PULL_RANGE;
			t.vel = vadd(t.vel, vmul(n, PULL_FORCE * (f + f * f) * dt / sqrtf(t.mass)));
			t.pulled = 0.8f;
		}
		if (act.pushing && dist < PUSH_RANGE)
		{
			float f = 1.0f - dist / PUSH_RANGE;
			bool combo = t.pulled > 0; // was pulled within the last 0.8s
			float boost = 1.0f;
			if (combo)
			{
				// remove the velocity heading toward rocket
				float vin = vdot(t.vel, n);
				if (vin > 0) t.vel = vsub(t.vel, vmul(n, vin));
				f = 0.5f + 0.5f * f;
				boost = 1.5f;
				t.pulled = 0;
			}
			t.vel = vadd(t.vel, vmul(n, PUSH_FORCE * f * boost / t.mass));
			t.pushed = 5.0f; // counts as "yours" for the next 5 seconds
		}

		// ring membrane: rejects trash that straddles the ring and is too slow
		Vector2 fromC = vsub(t.pos, CENTER);
		float rd = vlen(fromC);
		if (rd + t.radius > RING_R && rd - t.radius <= RING_R)
		{
			Vector2 inward = vnorm(vmul(fromC, -1.0f));
			t.vel = vadd(t.vel, vmul(inward, MEMBRANE_ACCEL * dt));
		}

		t.vel = vmul(t.vel, expf(-0.05f * dt));
		t.pos = vadd(t.pos, vmul(t.vel, dt));
		t.rot += t.rotSpeed * dt;

		// world edges
		if (t.pos.x < t.radius)
		{
			t.pos.x = t.radius;
			t.vel.x = fabsf(t.vel.x);
		}
		if (t.pos.x > WORLD_W - t.radius)
		{
			t.pos.x = WORLD_W - t.radius;
			t.vel.x = -fabsf(t.vel.x);
		}
		if (t.pos.y < t.radius)
		{
			t.pos.y = t.radius;
			t.vel.y = fabsf(t.vel.y);
		}
		if (t.pos.y > WORLD_H - t.radius)
		{
			t.pos.y = WORLD_H - t.radius;
			t.vel.y = -fabsf(t.vel.y);
		}

		// clear trash
		if (vlen(vsub(t.pos, CENTER)) - t.radius > RING_R)
		{
			float rocketDist = vlen(vsub(rocket.pos, t.pos));

			// prevent ghost destroys
			bool mine = t.pushed > 0 || rocketDist < PULL_RANGE*2.5;
			if (mine)
			{
				t.alive = false;
				cleared++;
				score += (t.pulled > 0) ? cast(int)(t.points * 1.5f) : t.points;
				burst(t.pos, 14, Color(80, 255, 140, 255), 150, 0.5f);
				playSfx(sGExplosion);
				continue;
			}

			// otherwise bounce it back inside the ring
			Vector2 outDir = vnorm(vsub(t.pos, CENTER));
			t.pos = vadd(CENTER, vmul(outDir, RING_R - t.radius));
			float vr = vdot(t.vel, outDir); // outward speed
			if (vr > 0) t.vel = vsub(t.vel, vmul(outDir, vr * 2.0f));
			t.vel = vsub(t.vel, vmul(outDir, 20.0f)); // small inward kick
		}

		// collision with rocket
		dist = vlen(vsub(rocket.pos, t.pos));
		if (dist < t.radius + ROCKET_R)
		{
			n = vnorm(vsub(rocket.pos, t.pos));
			t.pos = vsub(t.pos, vmul(n, (t.radius + ROCKET_R - dist)));
			t.vel = vsub(t.vel, vmul(n, 120.0f / t.mass));
			if (damageRocket(n)) return;
		}
	}
}

