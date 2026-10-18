module ui;

import common;
import display : mouse;
import assets : sNav, playSfx;

bool button(Rectangle rect, const(char)* label, int fontSize = 20, bool focused = false)
{
	Vector2 m = mouse();
	bool hovered = CheckCollisionPointRec(m, rect);
	bool down = hovered && IsMouseButtonDown(MouseButton.MOUSE_BUTTON_LEFT);
	bool pressed = hovered && IsMouseButtonReleased(MouseButton.MOUSE_BUTTON_LEFT);

	Color bg = down ? Color(30, 32, 48, 255)
		: (hovered || focused) ? Color(90, 95, 130, 255) : Color(50, 54, 78, 255);
	DrawRectangleRounded(rect, 0.25f, 8, bg);
	DrawRectangleRoundedLines(rect, 0.25f, 8, Color(160, 170, 210, 255));
	if (focused)
	{
		DrawRectangleRoundedLines(Rectangle(rect.x - 3, rect.y - 3, rect.width + 6, rect.height + 6),
			0.25f, 8, Color(255, 230, 120, 255));
	}

	int tw = measureText(label, fontSize);
	drawText(label,
		cast(int)(rect.x + (rect.width - tw) * 0.5f),
		cast(int)(rect.y + (rect.height - fontSize) * 0.5f),
		fontSize, Color(255, 255, 255, 255));
	return pressed;
}

void centeredTextAt(const(char)* text, int fontSize, float centerX, float y, Color c)
{
	int w = measureText(text, fontSize);
	drawText(text, cast(int)(centerX - w * 0.5f), cast(int) y, fontSize, c);
}

bool mouseMoved()
{
	Vector2 d = GetMouseDelta();
	return d.x != 0 || d.y != 0;
}

void hoverSelect(Rectangle r, ref int sel, int i)
{
	if (techHovered(r) && sel != i)
	{
		sel = i;
		playSfx(sNav);
	}
}

bool techHovered(Rectangle rect)
{
	return mouseMoved() && CheckCollisionPointRec(mouse(), rect);
}

// Rectangle with only top-left and bottom-right corners rounded
void drawTechShape(Rectangle r, float rad, Color fill, Color line)
{
	float x = r.x, y = r.y, w = r.width, h = r.height;
	if (rad > h * 0.5f) rad = h * 0.5f;
	if (rad > w * 0.5f) rad = w * 0.5f;

	// base rectangle
	DrawRectangleRec(Rectangle(x + rad, y, w - rad, h - rad), fill);
	DrawRectangleRec(Rectangle(x, y + rad, w - rad, h - rad), fill);

	// diagonal corner wedges
	DrawTriangle(
		Vector2(x + rad, y),
		Vector2(x, y + rad),
		Vector2(x + rad, y + rad),
		fill
	);
	DrawTriangle(
		Vector2(x + w - rad, y + h),
		Vector2(x + w, y + h - rad),
		Vector2(x + w - rad, y + h - rad),
		fill
	);

	// Outline (direct diagonals)
	DrawLineEx(Vector2(x + rad, y), Vector2(x + w, y), 2, line); // Top edge
	DrawLineEx(Vector2(x + w, y), Vector2(x + w, y + h - rad), 2, line); // Right edge
	DrawLineEx(Vector2(x + w, y + h - rad), Vector2(x + w - rad, y + h), 2, line); // Bottom-right diagonal
	DrawLineEx(Vector2(x + w - rad, y + h), Vector2(x, y + h), 2, line); // Bottom edge
	DrawLineEx(Vector2(x, y + h), Vector2(x, y + rad), 2, line); // Left edge
	DrawLineEx(Vector2(x, y + rad), Vector2(x + rad, y), 2, line); // Top-left diagonal
}

private void triBoth(Vector2 a, Vector2 b, Vector2 c, Color col)
{
	DrawTriangle(a, b, c, col);
	DrawTriangle(a, c, b, col);
}

void drawCutRect(Rectangle r, float rad, bool cutTL, bool cutBR, Color col)
{
	float x = r.x, y = r.y, w = r.width, h = r.height;
	if (w <= 0 || h <= 0) return;
	if (rad > w) rad = w;
	if (cutBR && rad > h * 0.5f) rad = h * 0.5f;

	Vector2[6] p;
	int n = 0;
	bool shallow = cutTL && rad > h;

	if (cutTL)
	{
		if (shallow)
		{
			p[n++] = Vector2(x + rad - h, y + h);
			p[n++] = Vector2(x + rad, y);
		}
		else
		{
			p[n++] = Vector2(x, y + rad);
			p[n++] = Vector2(x + rad, y);
		}
	}
	else p[n++] = Vector2(x, y);

	p[n++] = Vector2(x + w, y);

	if (cutBR)
	{
		p[n++] = Vector2(x + w, y + h - rad);
		p[n++] = Vector2(x + w - rad, y + h);
	}
	else p[n++] = Vector2(x + w, y + h);

	if (!shallow) p[n++] = Vector2(x, y + h);

	foreach (i; 1 .. n - 1) triBoth(p[0], p[i], p[i + 1], col);
}

Color fadeColor(Color c, float k)
{
	c.a = cast(ubyte)(c.a * clampf(k, 0, 1));
	return c;
}

bool techButton(Rectangle rect, const(char)* label, int fontSize, bool selected, float alpha = 1.0f)
{
	Vector2 m = mouse();
	bool hovered = CheckCollisionPointRec(m, rect);
	bool down = hovered && IsMouseButtonDown(MouseButton.MOUSE_BUTTON_LEFT);
	bool pressed = hovered && IsMouseButtonReleased(MouseButton.MOUSE_BUTTON_LEFT);

	Color fill = down ? Color(20, 40, 60, 255)
		: selected ? Color(40, 60, 95, 255) : Color(18, 24, 42, 230);
	Color line = selected ? Color(255, 230, 120, 255) : Color(90, 130, 190, 255);
	Color text = selected ? Color(255, 230, 120, 255) : Color(200, 200, 215, 255);

	if (alpha < 1.0f)
	{
		fill = fadeColor(fill, alpha);
		line = fadeColor(line, alpha);
		text = fadeColor(text, alpha);
	}

	drawTechShape(rect, 16, fill, line);

	int tw = measureText(label, fontSize);
	drawText(label,
		cast(int)(rect.x + (rect.width - tw) * 0.5f),
		cast(int)(rect.y + (rect.height - fontSize) * 0.5f),
		fontSize, text);
	return pressed;
}
