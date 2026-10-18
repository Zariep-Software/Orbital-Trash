module display;

import common;

__gshared RenderTexture2D target;
__gshared Rectangle destRect;
__gshared float viewScale = 1.0f;

void displayInit()
{
	target = LoadRenderTexture(BASE_W, BASE_H);
	SetTextureFilter(target.texture, TextureFilter.TEXTURE_FILTER_BILINEAR);
	updateLayout();
}

void displayShutdown()
{
	UnloadRenderTexture(target);
}

private void resizeTarget(int w, int h)
{
	UnloadRenderTexture(target);
	target = LoadRenderTexture(w, h);
	SetTextureFilter(target.texture, TextureFilter.TEXTURE_FILTER_BILINEAR);
}

// Fits the design aspect to the window
private void updateLayout()
{
	float sw = cast(float) GetScreenWidth();
	float sh = cast(float) GetScreenHeight();
	if (sw < 16.0f || sh < 16.0f) return; // minimized / degenerate size

	// scale if width/height is the reference
	float scaleW = sw / BASE_W;
	float scaleH = sh / BASE_H;

	if (scaleW > scaleH)
	{
		viewScale = scaleH;
		W = cast(int)(sw / viewScale + 0.5f);
		H = BASE_H;
	}
	else
	{
		viewScale = scaleW;
		W = BASE_W;
		H = cast(int)(sh / viewScale + 0.5f);
	}
	PLAY_H = H - HUD_H;

	if (target.texture.width != W || target.texture.height != H)
	{
		resizeTarget(W, H);
	}

	destRect = Rectangle(0.0f, 0.0f, sw, sh);
	viewScale = sw / cast(float) W;
}

void displayBeginFrame()
{
	updateLayout();
	BeginTextureMode(target);
}

void displayEndFrame()
{
	EndTextureMode();
	BeginDrawing();
	ClearBackground(Color(0, 0, 0, 255));
	Rectangle src = Rectangle(0, 0, cast(float) W, -cast(float) H); // flip Y
	DrawTexturePro(target.texture, src, destRect, Vector2(0, 0), 0.0f, Color(255, 255, 255, 255));
	EndDrawing();
}

// Mouse position in game coordinates
Vector2 mouse()
{
	Vector2 m = GetMousePosition();
	return Vector2((m.x - destRect.x) / viewScale, (m.y - destRect.y) / viewScale);
}