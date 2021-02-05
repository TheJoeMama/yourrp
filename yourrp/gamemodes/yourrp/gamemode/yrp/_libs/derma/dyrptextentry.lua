--Copyright (C) 2017-2021 Arno Zura (https://www.gnu.org/licenses/gpl.txt)
local PANEL = {}

function PANEL:Init()
	self.header = createD("DPanel", self, self:GetWide(), YRP.ctr(50), 0, 0)
	self.header.text = "UNNAMED"

	function self:SetHeader(text)
		self.header.text = text
	end

	function self.header:Paint(pw, ph)
		draw.RoundedBox(0, 0, 0, pw, ph, Color(255, 255, 255))
		surfaceText(SQL_STR_OUT(self.text), "Y_24_500", pw / 2, ph / 2, Color(255, 255, 255), 1, 1)
	end

	self.textentry = createD("DTextEntry", self, self:GetWide(), self:GetTall() - self.header:GetTall(), 0, YRP.ctr(50))

	function self:SetText(text)
		self.textentry:SetText(text)
	end
end

function PANEL:Think()
	if self.header:GetWide() ~= self:GetWide() then
		self.header:SetWide(self:GetWide())
	end

	if self.textentry:GetWide() ~= self:GetWide() then
		self.textentry:SetWide(self:GetWide())
	end

	if self.textentry:GetTall() ~= self:GetTall() - self.header:GetTall() then
		self.textentry:SetTall(self:GetTall() - self.header:GetTall())
	end

	if self.textentry:GetPos() ~= self:GetPos() + YRP.ctr(50) then
		self.textentry:SetPos(0, self:GetPos() + YRP.ctr(50))
	end
end

function PANEL:Paint(w, h)
	draw.RoundedBox(0, 0, 0, w, h, Color(255, 0, 0))
end

vgui.Register("DYRPTextEntry", PANEL, "Panel")
