module player;

import common;
import controls;
import assets : sHit, sRExplosion, sGameOver, playSfx;
import upgrades : saveProgress;
import core.stdc.math : cosf, sinf, expf, fabsf;

// rocket //
enum float ROCKET_R = 12.0f;
enum float ROCKET_ACCEL = 260.0f;
enum float ROCKET_TURN = 4.0f;
enum float ROCKET_MAXV = 420.0f;
enum float BRAKE_DRAG = 2.8f;

// magnets //
enum float PULL_RANGE = 160.0f;
enum float PUSH_RANGE = 120.0f;
enum float PUSH_COOLDOWN = 1.0f;
enum float PULL_DRAIN = 0.40f;
enum float PULL_REGEN = 0.35f;
enum float PULL_FORCE = 1600.0f;
enum float PUSH_FORCE = -750.0f;

float pullRange()
{
	return PULL_RANGE * pullRangeMul();
}

// Animation
__gshared float pullFxAmt = 0; // 0..1, eases in/out
__gshared float pullPhase = 0;

struct Rocket
{
	Vector2 pos, vel;
	float angle = 0;
	int hp;
	float invuln = 0;
	float pullEnergy = 1;
	float pushCd = 0;
	bool thrusting;
}

// frame magnet action
struct Actions
{
	bool pulling, pushing;
}

__gshared Rocket rocket;
__gshared float pushFx = 0;
private __gshared bool wasInside = true;

void resetRocket()
{
	rocket = Rocket.init;
	rocket.pos = Vector2(CENTER.x, CENTER.y + RING_R * 0.72f);
	rocket.vel = Vector2(0, 0);
	rocket.angle = -PI_F / 2;
	rocket.hp = maxHp;
	rocket.pullEnergy = 1.0f;
	rocket.pushCd = 0;
	pushFx = 0;
	pullFxAmt = 0;
	pullPhase = 0;
	deathFx = 0;
	shakeAmt = 0;
	wasInside = true;
}

bool rocketInsideRing()
{
	return vlen(vsub(rocket.pos, CENTER)) <= RING_R;
}

Actions updateRocket(float dt, Input inp)
{
	if (inp.left) rocket.angle -= ROCKET_TURN * dt;
	if (inp.right) rocket.angle += ROCKET_TURN * dt;
	Vector2 nose = Vector2(cosf(rocket.angle), sinf(rocket.angle));
	rocket.thrusting = inp.fwd;
	if (inp.fwd)
	{
		rocket.vel = vadd(rocket.vel, vmul(nose, ROCKET_ACCEL * dt));
		burst(vsub(rocket.pos, vmul(nose, 14)), 1, Color(255, 170, 40, 255), 90, 0.35f);
	}
	if (inp.brake) rocket.vel = vmul(rocket.vel, expf(-BRAKE_DRAG * brakeMul() * dt));
	float sp = vlen(rocket.vel);
	if (sp > ROCKET_MAXV) rocket.vel = vmul(rocket.vel, ROCKET_MAXV / sp);
	rocket.pos = vadd(rocket.pos, vmul(rocket.vel, dt));

	// bounce on world edges
	if (rocket.pos.x < ROCKET_R)
	{
		rocket.pos.x = ROCKET_R; rocket.vel.x = fabsf(rocket.vel.x) * 0.5f;
	}
	if (rocket.pos.x > WORLD_W - ROCKET_R)
	{
		rocket.pos.x = WORLD_W - ROCKET_R;
		rocket.vel.x = -fabsf(rocket.vel.x) * 0.5f;
	}

	if (rocket.pos.y < ROCKET_R)
	{
		rocket.pos.y = ROCKET_R;
		rocket.vel.y = fabsf(rocket.vel.y) * 0.5f;
	}
	if (rocket.pos.y > WORLD_H - ROCKET_R)
	{
		rocket.pos.y = WORLD_H - ROCKET_R;
		rocket.vel.y = -fabsf(rocket.vel.y) * 0.5f;
	}

	if (rocket.invuln > 0) rocket.invuln -= dt;
	if (pushFx > 0) pushFx -= dt;

	// push cooldown always recharges
	if (rocket.pushCd > 0)
	{
		rocket.pushCd -= dt;
		if (rocket.pushCd < 0) rocket.pushCd = 0;
	}

	bool inside = rocketInsideRing();

	if (inside != wasInside)
	{
		wasInside = inside;
		burst(rocket.pos, 60, Color(80, 255, 140, 255), 320, 0.9f);
		burst(rocket.pos, 20, Color(80, 255, 140, 255), 200, 0.4f);
	}

	// pull energy
	Actions a;
	a.pulling = inp.pull && inside && rocket.pullEnergy > 0.02f;
	pullFxAmt = clampf(pullFxAmt + (a.pulling ? 7.0f : -7.0f) * dt, 0, 1);
	pullPhase += dt;
	if (a.pulling)
	{
		rocket.pullEnergy = clampf(rocket.pullEnergy - PULL_DRAIN * dt, 0, 1);
	}
	else
	{
		rocket.pullEnergy = clampf(rocket.pullEnergy + PULL_REGEN * dt, 0, 1);
	}

	a.pushing = inp.push && inside && rocket.pushCd <= 0;
	if (a.pushing)
	{
		rocket.pushCd = PUSH_COOLDOWN;
		pushFx = 0.3f;
		burst(rocket.pos, 30, Color(255, 80, 200, 255), 220, 0.5f);
	}
	return a;
}

bool damageRocket(Vector2 n)
{
	if (rocket.invuln > 0) return false;

	rocket.hp--;
	hitFlash = 0.35f;
	shakeAmt = 5;
	rocket.invuln = 1.5f;
	rocket.vel = vadd(rocket.vel, vmul(n, 160.0f));
	score -= 5; if (score < 0) score = 0;
	burst(rocket.pos, 16, Color(255, 255, 255, 255), 200, 0.4f);
	if (rocket.hp <= 0)
	{
		burst(rocket.pos, 90, Color(255, 140, 30, 255), 380, 1.1f);
		playSfx(sRExplosion);
		playSfx(sGameOver);

		deathFx = DEATH_FX_TIME;
		shakeAmt = 12;

		endGame("Rocket destroyed");
		return true;
	}
	// Progressive: losing HP is saved right away, so quitting can't undo it
	if (gameMode == GameMode.progressive) saveProgress();
	playSfx(sHit);
	return false;
}

