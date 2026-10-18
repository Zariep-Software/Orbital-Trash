module touch;

import common;
import display : destRect, viewScale;
import controls : Input;
import assets: pauseIconTex;
import core.stdc.math : atan2f, fabsf;

enum float STICK_R = 90.0f; // max knob travel
enum float BTN_PULL_R = 70.0f;
enum float BTN_PUSH_R = 52.0f;
enum float BTN_BRAKE_R = 40.0f;
enum float HIT_PAD = 14.0f; // fat finger forgiveness
enum float BTN_PAUSE_R = 44.0f;


__gshared Vector2 stick = Vector2(0, 0); // -1..1, zero when idle
__gshared Vector2 stickOrigin;
__gshared int stickId = -1;

__gshared bool pullDown, brakeDown, pushPressed, pausePressedTouch;
private __gshared bool prevPush, prevPause;

// Button layout (game coordinates, bottom-right thumb arc)
Vector2 pullPos() { return Vector2(W - 120, H - 130); }
Vector2 pushPos() { return Vector2(W - 270, H - 90); }
Vector2 brakePos() { return Vector2(W - 250, H - 215); }
Vector2 pausePos() { return Vector2(W - 60, 60); }
Vector2 stickRest(){ return Vector2(160, H - 150); }

private Vector2 toGame(Vector2 p)
{
	return Vector2((p.x - destRect.x) / viewScale, (p.y - destRect.y) / viewScale);
}

private bool inCircle(Vector2 p, Vector2 c, float r)
{
	return vlen(vsub(p, c)) <= r + HIT_PAD;
}

// Call once per frame while playing
void touchUpdate()
{
	pullDown = brakeDown = false;
	bool pushHeld = false, pauseHeld = false, stickSeen = false;

	int n = GetTouchPointCount();
	foreach (k; 0 .. n)
	{
		int id = GetTouchPointId(k);
		Vector2 p = toGame(GetTouchPosition(k));

		if (id == stickId)
		{
			stickSeen = true;
			Vector2 d = vsub(p, stickOrigin);
			float len = vlen(d);
			if (len > STICK_R)
			{
				// floating stick: origin follows the thumb
				stickOrigin = vsub(p, vmul(vnorm(d), STICK_R));
				d = vsub(p, stickOrigin);
				len = STICK_R;
			}
			stick = vmul(d, 1.0f / STICK_R);
			continue;
		}
		// new touch in the left part of the screen starts the stick
		if (stickId < 0 && p.x < W * 0.45f && p.y > HUD_H)
		{
			stickId = id;
			stickOrigin = p;
			stick = Vector2(0, 0);
			stickSeen = true;
			continue;
		}
		if (inCircle(p, pullPos(), BTN_PULL_R)) pullDown = true;
		else if (inCircle(p, pushPos(), BTN_PUSH_R)) pushHeld = true;
		else if (inCircle(p, brakePos(), BTN_BRAKE_R)) brakeDown = true;
		else if (inCircle(p, pausePos(), BTN_PAUSE_R)) pauseHeld = true;
	}
	if (!stickSeen)
	{
		stickId = -1;
		stick = Vector2(0, 0);
	}
	pushPressed = pushHeld && !prevPush;
	pausePressedTouch = pauseHeld && !prevPause;
	prevPush = pushHeld;
	prevPause = pauseHeld;
}

// Turn stick to keyboard input
void applyTouchInput(ref Input i, float rocketAngle)
{
	i.pull = i.pull || pullDown;
	i.brake = i.brake || brakeDown;
	i.push = i.push || pushPressed;

	float mag = vlen(stick);
	if (mag < 0.2f) return; // deadzone

	float diff = atan2f(stick.y, stick.x) - rocketAngle;
	while (diff > PI_F) diff -= 2 * PI_F;
	while (diff < -PI_F) diff += 2 * PI_F;

	if (diff > 0.08f) i.right = true;
	else if (diff < -0.08f) i.left = true;

	// thrust only when roughly facing the target and stick is pushed out
	if (fabsf(diff) < 1.0f && mag > 0.5f) i.fwd = true;
}

private void circleBtn(Vector2 c, float r, const(char)* label, bool active)
{
	DrawCircleV(c, r, Color(255, 255, 255, active ? 90 : 40));
	DrawCircleLines(cast(int)c.x, cast(int)c.y, r, Color(255, 255, 255, 140));
	int tw = measureText(label, 18);
	drawText(label, cast(int)(c.x - tw / 2), cast(int)(c.y - 9), 18, Color(255, 255, 255, 200));
}

void drawTouchControls()
{
	// stick
	Vector2 o = stickId >= 0 ? stickOrigin : stickRest();
	DrawCircleV(o, STICK_R, Color(255, 255, 255, 30));
	DrawCircleLines(cast(int)o.x, cast(int)o.y, STICK_R, Color(255, 255, 255, 110));
	DrawCircleV(vadd(o, vmul(stick, STICK_R)), 34, Color(255, 255, 255, 110));

	circleBtn(pullPos(), BTN_PULL_R, "PULL", pullDown);
	circleBtn(pushPos(), BTN_PUSH_R, "PUSH", pushPressed);
	circleBtn(brakePos(), BTN_BRAKE_R, "BRK", brakeDown);

	if (pauseIconTex.id != 0)
	{
		float s = BTN_PAUSE_R * 2;
		Vector2 c = pausePos();
		DrawTexturePro(pauseIconTex,
			Rectangle(0, 0, pauseIconTex.width, pauseIconTex.height),
			Rectangle(c.x - s * 0.5f, c.y - s * 0.5f, s, s),
			Vector2(0, 0), 0, Color(255, 255, 255, 220));
	}
	else
	{
		circleBtn(pausePos(), BTN_PAUSE_R, "ll", false);
	}
}
