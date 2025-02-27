--Copyright (C) 2017-2022 D4KiR (https://www.gnu.org/licenses/gpl.txt)

local function safeText(text)
		return text
end

DarkRP.deLocalise = safeText

function draw.DrawNonParsedText(text, font, x, y, color, xAlign)
		return draw.DrawText(safeText(text), font, x, y, color, xAlign)
end

function draw.DrawNonParsedSimpleText(text, font, x, y, color, xAlign, yAlign)
		return draw.SimpleText(safeText(text), font, x, y, color, xAlign, yAlign)
end

function draw.DrawNonParsedSimpleTextOutlined(text, font, x, y, color, xAlign, yAlign, outlineWidth, outlineColor)
		return draw.SimpleTextOutlined(safeText(text), font, x, y, color, xAlign, yAlign, outlineWidth, outlineColor)
end

function surface.DrawNonParsedText(text)
		return surface.DrawText(safeText(text) )
end

function chat.AddNonParsedText(...)
	local tbl = {...}
	for i = 2, #tbl, 2 do
			tbl[i] = safeText(tbl[i])
	end
	return chat.AddText(unpack(tbl) )
end
