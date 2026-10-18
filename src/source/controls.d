module controls;

import raylib;
import settings : keyFor, Bind;
import touch : pausePressedTouch;
import common: Input;

// Rebindable keys come from the settings screen; arrows / O / P stay as fixed alternates.
Input readInput()
{
	Input i;
	i.left = IsKeyDown(keyFor(Bind.left)) || IsKeyDown(KeyboardKey.KEY_LEFT);
	i.right = IsKeyDown(keyFor(Bind.right)) || IsKeyDown(KeyboardKey.KEY_RIGHT);
	i.fwd = IsKeyDown(keyFor(Bind.fwd)) || IsKeyDown(KeyboardKey.KEY_UP);
	i.brake = IsKeyDown(keyFor(Bind.brake)) || IsKeyDown(KeyboardKey.KEY_DOWN);
	i.pull = pullHeld();
	i.push = IsKeyPressed(keyFor(Bind.push)) || IsKeyPressed(KeyboardKey.KEY_P);
	return i;
}

bool pullHeld()
{
	return IsKeyDown(keyFor(Bind.pull)) || IsKeyDown(KeyboardKey.KEY_O);
}

int shopKeyPressed()
{
	foreach (i; 0 .. 5)
	{
		if (IsKeyPressed(cast(KeyboardKey)(KeyboardKey.KEY_ONE + i))
			|| IsKeyPressed(cast(KeyboardKey)(KeyboardKey.KEY_KP_1 + i)))
			return i;
	}
	return -1;
}

// Navigation //
bool pausePressed()
{
	version (Android)
	{
		if (pausePressedTouch)
		{
			pausePressedTouch = false; // consume
			return true;
		}
	}
	return IsKeyPressed(keyFor(Bind.pause)) || IsKeyPressed(KeyboardKey.KEY_ESCAPE);
}

bool menuDown()
{
	return IsKeyPressed(KeyboardKey.KEY_DOWN) || IsKeyPressed(KeyboardKey.KEY_S);
}

bool menuUp()
{
	return IsKeyPressed(KeyboardKey.KEY_UP) || IsKeyPressed(KeyboardKey.KEY_W);
}

bool menuRight()
{
	return IsKeyPressed(KeyboardKey.KEY_RIGHT) || IsKeyPressed(KeyboardKey.KEY_D);
}

bool menuLeft()
{
	return IsKeyPressed(KeyboardKey.KEY_LEFT) || IsKeyPressed(KeyboardKey.KEY_A);
}

// Accept: Enter, Space, or the push key
bool menuConfirm()
{
	return IsKeyPressed(KeyboardKey.KEY_ENTER)
		|| IsKeyPressed(KeyboardKey.KEY_SPACE)
		|| IsKeyPressed(keyFor(Bind.push))
		|| IsKeyPressed(KeyboardKey.KEY_P);
}

// Cancel: pull key or Escape
bool menuCancel()
{
	return IsKeyPressed(keyFor(Bind.pull))
		|| IsKeyPressed(KeyboardKey.KEY_O)
		|| IsKeyPressed(KeyboardKey.KEY_ESCAPE);
}

bool pauseConfirm()
{
	return IsKeyPressed(KeyboardKey.KEY_ENTER)
		|| IsKeyPressed(keyFor(Bind.push))
		|| IsKeyPressed(KeyboardKey.KEY_P);
}

bool restartPressed()
{
	return IsKeyPressed(KeyboardKey.KEY_R);
}

bool toMenuPressed()
{
	return IsKeyPressed(KeyboardKey.KEY_M);
}
