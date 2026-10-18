module about;

import common;
import assets : logoTex;
import ui;
import controls : menuUp, menuDown, menuConfirm, menuCancel;

private enum string VERSION_TEXT = "Version: 1.0";
private enum const(char)* URL_AUTHOR = "https://zariep.com";
private enum const(char)* URL_SOURCE = "https://github.com/Zariep-Software/Orbital-Trash";
private enum const(char)* URL_RAYLIB = "https://www.raylib.com";

private enum int ITEMS = 5;
private __gshared int sel = 0;
private __gshared bool showFonts = false;

void aboutReset()
{
	sel = 0;
	showFonts = false;
}

bool aboutUpdateDraw()
{
	DrawRectangle(0, 0, W, H, Color(0, 0, 0, 170));
	Rectangle panel = Rectangle(W * 0.5f - 250, 40, 500, 600);
	DrawRectangleRounded(panel, 0.04f, 8, Color(16, 18, 32, 245));
	DrawRectangleRoundedLines(panel, 0.04f, 8, Color(120, 130, 170, 255));

	float bx = W * 0.5f - 200;

	if (showFonts)
	{
		if (menuCancel() || menuConfirm())
		{
			showFonts = false;
			return false;
		}
		centeredTextAt("FONTS", 36, W * 0.5f, 90, Color(255, 230, 120, 255));
		centeredTextAt("Oxanium by The Oxanium Project Authors", 20, W * 0.5f, 200, Color(220, 225, 245, 255));
		if (techButton(Rectangle(bx, 560, 400, 48), "Close", 24, true)) showFonts = false;
		return false;
	}

	// logo
	if (logoTex.id != 0)
	{
		float sc = 360.0f / logoTex.width;
		float sy = 130.0f / logoTex.height;
		if (sy < sc) sc = sy;
		float w = logoTex.width * sc;
		DrawTextureEx(logoTex, Vector2(W * 0.5f - w * 0.5f, 60), 0, sc, Color(255, 255, 255, 255));
	}
	else centeredTextAt("ORBITAL TRASH", 40, W * 0.5f, 100, Color(120, 255, 170, 255));

	centeredTextAt(VERSION_TEXT.ptr, 22, W * 0.5f, 205, Color(200, 200, 215, 255));

	if (menuDown()) sel = (sel + 1) % ITEMS;
	if (menuUp()) sel = (sel + ITEMS - 1) % ITEMS;

	const(char)*[ITEMS] labels = ["ItsZariep (Code+Sprites+Audio)", "Fonts credits",
		"Source Code", "Made with Raylib", "Close"];

	int clicked = -1;
	foreach (i; 0 .. ITEMS)
	{
		float y = i < 4 ? 255 + i * 60 : 560;
		Rectangle r = Rectangle(bx, y, 400, 48);
		hoverSelect(r, sel, cast(int) i);
		if (techButton(r, labels[i], 22, i == sel))
		{
			sel = cast(int) i;
			clicked = cast(int) i;
		}
	}
	if (menuConfirm() && clicked < 0) clicked = sel;

	switch (clicked)
	{
		case 0: OpenURL(URL_AUTHOR); break;
		case 1: showFonts = true; break;
		case 2: OpenURL(URL_SOURCE); break;
		case 3: OpenURL(URL_RAYLIB); break;
		case 4: aboutReset(); return true;
		default: break;
	}
	if (menuCancel())
	{
		aboutReset();
		return true;
	}
	return false;
}
