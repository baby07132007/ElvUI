﻿local E, L, V, P, G = unpack(select(2, ...));
local NP = E:NewModule("NamePlates", "AceHook-3.0", "AceEvent-3.0", "AceTimer-3.0");
local LSM = LibStub("LibSharedMedia-3.0");

local _G = _G;
local GetTime = GetTime;
local tonumber, pairs, select, tostring, unpack = tonumber, pairs, select, tostring, unpack;
local twipe, tsort, tinsert, wipe = table.wipe, table.sort, table.insert, wipe;
local band = bit.band;
local floor = math.floor;
local gsub, format, strsplit = string.gsub, format, strsplit;

local CreateFrame = CreateFrame;
local GetTime = GetTime;
local UnitGUID = UnitGUID;
local UnitName = UnitName;
local InCombatLockdown = InCombatLockdown;
local UnitExists = UnitExists;
local SetCVar = SetCVar;
local IsAddOnLoaded = IsAddOnLoaded;
local GetComboPoints = GetComboPoints;
local UnitHasVehicleUI = UnitHasVehicleUI;
local GetSpellInfo = GetSpellInfo;
local GetSpellTexture = GetSpellTexture;
local UnitBuff, UnitDebuff = UnitBuff, UnitDebuff;
local UnitPlayerControlled = UnitPlayerControlled;
local GetRaidTargetIndex = GetRaidTargetIndex;
local WorldFrame = WorldFrame;
local RAID_CLASS_COLORS = RAID_CLASS_COLORS;
local CUSTOM_CLASS_COLORS = CUSTOM_CLASS_COLORS;
local UNKNOWN = UNKNOWN;
local MAX_COMBO_POINTS = MAX_COMBO_POINTS;
local COMBATLOG_OBJECT_CONTROL_PLAYER = COMBATLOG_OBJECT_CONTROL_PLAYER;

local numChildren = -1;
local targetIndicator;
local targetAlpha = 1;

local OVERLAY = [=[Interface\TargetingFrame\UI-TargetingFrame-Flash]=];

--Pattern to remove cross realm label added to the end of plate names
--Taken from http://www.wowace.com/addons/libnameplateregistry-1-0/
local FSPAT = "%s*"..((_G.FOREIGN_SERVER_LABEL:gsub("^%s", "")):gsub("[%*()]", "%%%1")).."$";

NP.NumTargetChecks = -1;
NP.CreatedPlates = {};
NP.ComboPoints = {};
NP.ByRaidIcon = {};
NP.ByName = {};
NP.AuraList = {};
NP.AuraSpellID = {};
NP.AuraExpiration = {};
NP.AuraStacks = {};
NP.AuraCaster = {};
NP.AuraDuration = {};
NP.AuraTexture = {};
NP.AuraType = {};
NP.AuraTarget = {};
NP.CachedAuraDurations = {};
NP.BuffCache = {};
NP.DebuffCache = {};

NP.RaidTargetReference = {
	["STAR"] = 0x00000001,
	["CIRCLE"] = 0x00000002,
	["DIAMOND"] = 0x00000004,
	["TRIANGLE"] = 0x00000008,
	["MOON"] = 0x00000010,
	["SQUARE"] = 0x00000020,
	["CROSS"] = 0x00000040,
	["SKULL"] = 0x00000080
};

NP.RaidIconCoordinate = {
	[0] =		{[0] = "STAR",		[0.25] = "MOON"},
	[0.25] =	{[0] = "CIRCLE",	[0.25] = "SQUARE"},
	[0.5] =		{[0] = "DIAMOND",	[0.25] = "CROSS"},
	[0.75] =	{[0] = "TRIANGLE",	[0.25] = "SKULL"}
};

NP.ComboColors = {
	[1] = {0.69, 0.31, 0.31},
	[2] = {0.69, 0.31, 0.31},
	[3] = {0.65, 0.63, 0.35},
	[4] = {0.65, 0.63, 0.35},
	[5] = {0.33, 0.59, 0.33}
};

NP.RaidMarkColors = {
	["STAR"] = {r = 0.85, g = 0.81, b = 0.27},
	["MOON"] = {r = 0.60,g = 0.75,b = 0.85},
	["CIRCLE"] = {r = 0.93,g = 0.51,b = 0.06},
	["SQUARE"] = {r = 0,g = 0.64,b = 1},
	["DIAMOND"] = {r = 0.7,g = 0.06,b = 0.84},
	["CROSS"] = {r = 0.82,g = 0.18,b = 0.18},
	["TRIANGLE"] = {r = 0.14,g = 0.66,b = 0.14},
	["SKULL"] = {r = 0.89,g = 0.83,b = 0.74}
};

local AURA_UPDATE_INTERVAL = 0.1;
local AURA_TARGET_HOSTILE = 1;
local AURA_TARGET_FRIENDLY = 2;
local AuraList, AuraGUID = {}, {}

local RaidIconIndex = {
	"STAR",
	"CIRCLE",
	"DIAMOND",
	"TRIANGLE",
	"MOON",
	"SQUARE",
	"CROSS",
	"SKULL",
}

local TimeColors = {
	[0] = "|cffeeeeee",
	[1] = "|cffeeeeee",
	[2] = "|cffeeeeee",
	[3] = "|cffFFEE00",
	[4] = "|cfffe0000",
}

function NP:SetTargetIndicatorDimensions()
	if(self.db.targetIndicator.style == "arrow") then
		targetIndicator.arrow:SetHeight(self.db.targetIndicator.height);
		targetIndicator.arrow:SetWidth(self.db.targetIndicator.width);
	elseif(self.db.targetIndicator.style == "doubleArrow" or self.db.targetIndicator.style == "doubleArrowInverted") then
		targetIndicator.left:SetHeight(self.db.targetIndicator.height);
		targetIndicator.left:SetWidth(self.db.targetIndicator.width);
		targetIndicator.right:SetWidth(self.db.targetIndicator.width);
		targetIndicator.right:SetHeight(self.db.targetIndicator.height);
	end
end

function NP:PositionTargetIndicator(myPlate)
	targetIndicator:SetParent(myPlate);
	if(self.db.targetIndicator.style == "arrow") then
		targetIndicator.arrow:ClearAllPoints();
		targetIndicator.arrow:SetPoint("BOTTOM", myPlate.HealthBar, "TOP", 0, 30 + self.db.targetIndicator.yOffset);
	elseif(self.db.targetIndicator.style == "doubleArrow") then
		targetIndicator.left:SetPoint("RIGHT", myPlate.HealthBar, "LEFT", -self.db.targetIndicator.xOffset, 0);
		targetIndicator.right:SetPoint("LEFT", myPlate.HealthBar, "RIGHT", self.db.targetIndicator.xOffset, 0);
		targetIndicator:SetFrameLevel(0);
		targetIndicator:SetFrameStrata("BACKGROUND");
	elseif(self.db.targetIndicator.style == "doubleArrowInverted") then
		targetIndicator.right:SetPoint("RIGHT", myPlate.HealthBar, "LEFT", -self.db.targetIndicator.xOffset, 0);
		targetIndicator.left:SetPoint("LEFT", myPlate.HealthBar, "RIGHT", self.db.targetIndicator.xOffset, 0);
		targetIndicator:SetFrameLevel(0);
		targetIndicator:SetFrameStrata("BACKGROUND");
	elseif(self.db.targetIndicator.style == "glow") then
		targetIndicator:SetOutside(myPlate.HealthBar, 3, 3);
		targetIndicator:SetFrameLevel(0);
		targetIndicator:SetFrameStrata("BACKGROUND");
	end
	
	targetIndicator:Show();
end

function NP:ColorTargetIndicator(r, g, b)
	if(self.db.targetIndicator.style == "arrow") then
		targetIndicator.arrow:SetVertexColor(r, g, b);
	elseif(self.db.targetIndicator.style == "doubleArrow" or self.db.targetIndicator.style == "doubleArrowInverted") then
		targetIndicator.left:SetVertexColor(r, g, b);
		targetIndicator.right:SetVertexColor(r, g, b);
	elseif(self.db.targetIndicator.style == "glow") then
		targetIndicator:SetBackdropBorderColor(r, g, b);
	end
end

function NP:SetTargetIndicator()
	if(self.db.targetIndicator.style == "arrow") then
		targetIndicator = self.arrowIndicator;
		self.glowIndicator:Hide();
		self.doubleArrowIndicator:Hide();
	elseif(self.db.targetIndicator.style == "doubleArrow" or self.db.targetIndicator.style == "doubleArrowInverted") then
		targetIndicator = self.doubleArrowIndicator;
		targetIndicator.left:ClearAllPoints();
		targetIndicator.right:ClearAllPoints();
		self.arrowIndicator:Hide();
		self.glowIndicator:Hide();
	elseif(self.db.targetIndicator.style == "glow") then
		targetIndicator = self.glowIndicator;
		self.arrowIndicator:Hide();
		self.doubleArrowIndicator:Hide();
	end
	
	self:SetTargetIndicatorDimensions();
end

function NP:OnUpdate(elapsed)
	local count = WorldFrame:GetNumChildren();
	if(count ~= numChildren) then
		numChildren = count;
		NP:ScanFrames(WorldFrame:GetChildren());
	end

	--NP.PlateParent:Hide()
	for blizzPlate, plate in pairs(NP.CreatedPlates) do
		if(blizzPlate:IsShown()) then
			if(not self.viewPort) then
				plate:SetPoint("CENTER", WorldFrame, "BOTTOMLEFT", blizzPlate:GetCenter());
			end
			NP.SetAlpha(blizzPlate, plate);
		elseif(plate:IsShown()) then
			plate:Hide();
		end
	end
	--NP.PlateParent:Show();

	if(self.elapsed and self.elapsed > 0.2) then
		for blizzPlate, plate in pairs(NP.CreatedPlates) do
			if(blizzPlate:IsShown() and plate:IsShown()) then
				NP.SetUnitInfo(blizzPlate, plate);
				NP.ColorizeAndScale(blizzPlate, plate);
				NP.UpdateLevelAndName(blizzPlate, plate);
				plate:SetDepth(25);
			end
		end

		self.elapsed = 0;
	else
		self.elapsed = (self.elapsed or 0) + elapsed;
	end
end

function NP:CheckFilter(myPlate)
	local name = gsub(self.Name:GetText(), FSPAT, "");
	local db = E.global.nameplate["filter"][name];

	if(db and db.enable) then
		if(db.hide) then
			myPlate:Hide();
			return;
		else
			if(not myPlate:IsShown()) then
				myPlate:Show();
			end

			if(db.customColor) then
				self.customColor = db.color;
				myPlate.HealthBar:SetStatusBarColor(db.color.r, db.color.g, db.color.b);
			else
				self.customColor = nil;
			end

			if(db.customScale and db.customScale ~= 1) then
				myPlate.HealthBar:Height(NP.db.healthBar.height * db.customScale);
				myPlate.HealthBar:Width(NP.db.healthBar.width * db.customScale);
				self.customScale = true;
			else
				self.customScale = nil;
			end
		end
	elseif(not myPlate:IsShown()) then
		myPlate:Show();
	end

	return true;
end

function NP:UpdateLevelAndName(myPlate)
	if(not NP.db.showLevel) then
		myPlate.Level:SetText("");
		myPlate.Level:Hide();
	else
		local level, elite, boss = self.Level:GetObjectType() == "FontString" and tonumber(self.Level:GetText()) or nil, self.eliteIcon:IsShown(), self.bossIcon:IsShown();
		if(boss) then
			myPlate.Level:SetText("??");
			myPlate.level:SetTextColor(0.8, 0.05, 0);
		elseif(level) then
			myPlate.Level:SetText(level .. (elite and "+" or ""));
			myPlate.Level:SetTextColor(self.Level:GetTextColor());
		end
		
		if(not myPlate.Level:IsShown()) then
			myPlate.Level:Show();
		end
	end

	if(NP.db.showName) then
		myPlate.Name:SetText(self.Name:GetText());
		if(not myPlate.Name:IsShown()) then myPlate.Name:Show(); end
	elseif(myPlate.Name:IsShown()) then
		myPlate.Name:SetText("");
		myPlate.Name:Hide();
	end

	if(self.RaidIcon:IsShown()) then
		local ux, uy = self.RaidIcon:GetTexCoord();
		if((ux ~= myPlate.RaidIcon.ULx or uy ~= myPlate.RaidIcon.ULy)) then
			myPlate.RaidIcon:Show();
			myPlate.RaidIcon:SetTexCoord(self.RaidIcon:GetTexCoord());
			myPlate.RaidIcon.ULx, myPlate.RaidIcon.ULy = ux, uy;
		end
	elseif(myPlate.RaidIcon:IsShown()) then
		myPlate.RaidIcon:Hide();
	end
end

function NP:GetReaction(frame)
	local r, g, b = NP:RoundColors(frame.HealthBar:GetStatusBarColor());
	
	for class, _ in pairs(RAID_CLASS_COLORS) do
		if(RAID_CLASS_COLORS[class].r == r and RAID_CLASS_COLORS[class].g == g and RAID_CLASS_COLORS[class].b == b) then
			return class;
		end
	end
	
	if((r + b + b) == 1.59) then
		return "TAPPED_NPC";
	elseif(g + b == 0) then
		return "HOSTILE_NPC";
	elseif(r + b == 0) then
		return "FRIENDLY_NPC";
	elseif(r + g > 1.95) then
		return "NEUTRAL_NPC";
	elseif(r + g == 0) then
		return "FRIENDLY_PLAYER";
	else
		return "HOSTILE_PLAYER";
	end
end

function NP:GetThreatReaction(frame)
	if(frame.threat:IsShown()) then
		local r, g, b = frame.threat:GetVertexColor();
		if(g + b == 0) then
			return "FULL_THREAT";
		else
			if(self.threatReaction == "FULL_THREAT") then
				return "GAINING_THREAT";
			else
				return "LOSING_THREAT";
			end
		end
	else
		return "NO_THREAT";
	end
end

local color, scale;
function NP:ColorizeAndScale(myPlate)
	local unitType = NP:GetReaction(self);
	local scale = 1;
	local canAttack = false;
	
	self.unitType = unitType;
	if(CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[unitType]) then
		color = CUSTOM_CLASS_COLORS[unitType]
	elseif(RAID_CLASS_COLORS[unitType]) then
		color = RAID_CLASS_COLORS[unitType];
	elseif(unitType == "TAPPED_NPC") then
		color = NP.db.reactions.tapped;
	elseif(unitType == "HOSTILE_NPC" or unitType == "NEUTRAL_NPC") then
		local classRole = E.Role;
		local threatReaction = NP:GetThreatReaction(self);
		canAttack = true;
		if(not NP.db.threat.useThreatColor) then
			if(unitType == "NEUTRAL_NPC") then
				color = NP.db.reactions.neutral;
			else
				color = NP.db.reactions.enemy;
			end
		elseif(threatReaction == "FULL_THREAT") then
			if(classRole == "Tank") then
				color = NP.db.threat.goodColor;
				scale = NP.db.threat.goodScale;
			else
				color = NP.db.threat.badColor;
				scale = NP.db.threat.badScale;
			end
		elseif(threatReaction == "GAINING_THREAT") then
			if(classRole == "Tank") then
				color = NP.db.threat.goodTransition;
			else
				color = NP.db.threat.badTransition;
			end
		elseif(threatReaction == "LOSING_THREAT") then
			if(classRole == "Tank") then
				color = NP.db.threat.badTransition;
			else
				color = NP.db.threat.goodTransition;
			end
		elseif(InCombatLockdown()) then
			if(classRole == "Tank") then
				color = NP.db.threat.badColor;
				scale = NP.db.threat.badScale;
			else
				color = NP.db.threat.goodColor;
				scale = NP.db.threat.goodScale;
			end
		else
			if(unitType == "NEUTRAL_NPC") then
				color = NP.db.reactions.neutral;
			else
				color = NP.db.reactions.enemy;
			end
		end
		
		self.threatReaction = threatReaction;
	elseif(unitType == "FRIENDLY_NPC") then
		color = NP.db.reactions.friendlyNPC;
	elseif(unitType == "FRIENDLY_PLAYER") then
		color = NP.db.reactions.friendlyPlayer;
	else
		color = NP.db.reactions.enemy;
	end
	
	if(self.RaidIcon:IsShown() and NP.db.healthBar.colorByRaidIcon) then
		NP:CheckRaidIcon(self);
		local raidColor = NP.RaidMarkColors[self.raidIconType];
		color = raidColor or color;
	end
	
	if(NP.db.healthBar.lowHPScale.enable and NP.db.healthBar.lowHPScale.changeColor and myPlate.Glow:IsShown() and canAttack) then
		color = NP.db.healthBar.lowHPScale.color;
	end
	
	if(not self.customColor) then
		myPlate.HealthBar:SetStatusBarColor(color.r, color.g, color.b);

		if(NP.db.targetIndicator.enable and NP.db.targetIndicator.colorMatchHealthBar and self.unit == "target") then
			NP:ColorTargetIndicator(color.r, color.g, color.b);
		end
	elseif(self.unit == "target" and NP.db.targetIndicator.colorMatchHealthBar and NP.db.targetIndicator.enable) then
		NP:ColorTargetIndicator(self.customColor.r, self.customColor.g, self.customColor.b);
	end
	
	local w = NP.db.healthBar.width * scale;
	local h = NP.db.healthBar.height * scale;
	if(NP.db.healthBar.lowHPScale.enable) then
		if(myPlate.Glow:IsShown()) then
			w = NP.db.healthBar.lowHPScale.width * scale;
			h = NP.db.healthBar.lowHPScale.height * scale;
			if(NP.db.healthBar.lowHPScale.toFront) then
				myPlate:SetFrameStrata("HIGH");
			end
		else
			if(NP.db.healthBar.lowHPScale.toFront) then
				myPlate:SetFrameStrata("BACKGROUND");
			end
		end
	end
	if(not self.customScale and myPlate.HealthBar:GetWidth() ~= w) then
		myPlate.HealthBar:SetSize(w, h);
		myPlate.CastBar.Icon:SetSize(NP.db.castBar.height + h + 5, NP.db.castBar.height + h + 5);
	end
end

function NP:SetAlpha(myPlate)
	if(self:GetAlpha() < 1) then
		myPlate:SetAlpha(NP.db.nonTargetAlpha);
	else
		myPlate:SetAlpha(targetAlpha);
	end
end

function NP:SetUnitInfo(myPlate)
	local plateName = gsub(self.Name:GetText(), FSPAT,"");
	if(self:GetAlpha() == 1 and NP.targetName and (NP.targetName == plateName)) then
		self.guid = UnitGUID("target");
		self.unit = "target";
		myPlate:SetFrameLevel(2);
		myPlate.overlay:Hide();
		
		if(NP.db.targetIndicator.enable) then
			targetIndicator:Show();
			NP:PositionTargetIndicator(myPlate);
			targetIndicator:SetDepth(myPlate:GetDepth());
		end

		if((NP.NumTargetChecks > -1) or self.allowCheck) then
			NP.NumTargetChecks = NP.NumTargetChecks + 1;
			if NP.NumTargetChecks > 0 then
				NP.NumTargetChecks = -1;
			end

			NP:UpdateAurasByUnitID("target");
			NP:UpdateElement_CPointsByUnitID("target");
			self.allowCheck = nil;
		end
	elseif self.highlight:IsShown() and UnitExists("mouseover") and (UnitName("mouseover") == plateName) then
		if(self.unit ~= "mouseover") then
			myPlate:SetFrameLevel(1);
			myPlate.overlay:Show();
			NP:UpdateAurasByUnitID("mouseover");
			NP:UpdateElement_CPointsByUnitID("mouseover");
		end
		self.guid = UnitGUID("mouseover");
		self.unit = "mouseover";
		NP:UpdateAurasByUnitID("mouseover");
	else
		myPlate:SetFrameLevel(0);
		myPlate.overlay:Hide();
		self.unit = nil;
	end
end

function NP:PLAYER_ENTERING_WORLD()
	twipe(self.ComboPoints);
end

function NP:UPDATE_MOUSEOVER_UNIT()
	WorldFrame.elapsed = 0.1;
end

function NP:PLAYER_TARGET_CHANGED()
	targetIndicator:Hide();
	if(UnitExists("target")) then
		self.targetName = UnitName("target");
		WorldFrame.elapsed = 0.1;
		NP.NumTargetChecks = 0;
		targetAlpha = E.db.nameplate.targetAlpha;
	else
		targetIndicator:Hide();
		self.targetName = nil;
		targetAlpha = 1;
	end
end

function NP:PLAYER_REGEN_DISABLED()
	SetCVar("nameplateShowEnemies", 1);
end

function NP:PLAYER_REGEN_ENABLED()
	SetCVar("nameplateShowEnemies", 0);
end

function NP:UNIT_COMBO_POINTS(event, unit)
	if(unit == "player" or unit == "vehicle") then
		self:UpdateElement_CPointsByUnitID("target");
	end
end

function NP:CombatToggle(noToggle)
	if(self.db.combatHide) then
		self:RegisterEvent("PLAYER_REGEN_DISABLED");
		self:RegisterEvent("PLAYER_REGEN_ENABLED");
		if(not noToggle) then
			SetCVar("nameplateShowEnemies", 0);
		end
	else
		self:UnregisterEvent("PLAYER_REGEN_DISABLED");
		self:UnregisterEvent("PLAYER_REGEN_ENABLED");
		if(not noToggle) then
			SetCVar("nameplateShowEnemies", 1);
		end
	end
end

function NP:Initialize()
	self.db = E.db["nameplate"];
	if(E.private["nameplate"].enable ~= true) then return; end
	E.NamePlates = NP;
	
	self.PlateParent = CreateFrame("Frame", nil, WorldFrame);
	self.PlateParent:SetFrameStrata("BACKGROUND");
	self.PlateParent:SetFrameLevel(0);
	WorldFrame:HookScript("OnUpdate", NP.OnUpdate);
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
	self:RegisterEvent("UNIT_AURA");
	self:RegisterEvent("PLAYER_TARGET_CHANGED");
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT");
	self:RegisterEvent("UNIT_COMBO_POINTS");
	
	self.arrowIndicator = CreateFrame("Frame", nil, WorldFrame);
	self.arrowIndicator.arrow = self.arrowIndicator:CreateTexture(nil, "BORDER");
	self.arrowIndicator.arrow:SetTexture([[Interface\AddOns\ElvUI\media\textures\nameplateTargetIndicator.tga]]);
	self.arrowIndicator:Hide();
	
	self.doubleArrowIndicator = CreateFrame("Frame", nil, WorldFrame);
	self.doubleArrowIndicator.left = self.doubleArrowIndicator:CreateTexture(nil, "BORDER");
	self.doubleArrowIndicator.left:SetTexture([[Interface\AddOns\ElvUI\media\textures\nameplateTargetIndicatorLeft.tga]]);
	self.doubleArrowIndicator.right = self.doubleArrowIndicator:CreateTexture(nil, "BORDER");
	self.doubleArrowIndicator.right:SetTexture([[Interface\AddOns\ElvUI\media\textures\nameplateTargetIndicatorRight.tga]]);
	self.doubleArrowIndicator:Hide();
	
	self.glowIndicator = CreateFrame("Frame", nil, WorldFrame);
	self.glowIndicator:SetFrameLevel(0);
	self.glowIndicator:SetFrameStrata("BACKGROUND");
	self.glowIndicator:SetBackdrop( {	
 		edgeFile = LSM:Fetch("border", "ElvUI GlowBorder"), edgeSize = 3,
 		insets = {left = 5, right = 5, top = 5, bottom = 5}
 	});
	self.glowIndicator:SetBackdropColor(0, 0, 0, 0);
	self.glowIndicator:SetScale(E.PixelMode and 2.5 or 3);
	self.glowIndicator:Hide();
	
	self:SetTargetIndicator();
	self.viewPort = IsAddOnLoaded("SunnArt");
	self:CombatToggle(true);
end

function NP:UpdateAllPlates()
	if(E.private["nameplate"].enable ~= true) then return; end
	NP:ForEachPlate("UpdateSettings");
end

function NP:ForEachPlate(functionToRun, ...)
	for blizzPlate, plate in pairs(self.CreatedPlates) do
		if(blizzPlate) then
			self[functionToRun](blizzPlate, plate, ...);
		end
	end
end

function NP:RoundColors(r, g, b)	
	return floor(r*100+.5)/100, floor(g*100+.5)/100, floor(b*100+.5)/100;
end

function NP:OnSizeChanged(width, height)
	local myPlate = NP.CreatedPlates[self];
	myPlate:SetSize(width, height);
end

function NP:OnShow()
	local myPlate = NP.CreatedPlates[self];
	local objectType;
	for object in pairs(self.queue) do		
		objectType = object:GetObjectType();
		if(objectType == "Texture") then
			object.OldTexture = object:GetTexture();
			object:SetTexture("");
			object:SetTexCoord(0, 0, 0, 0)
		elseif(objectType == "FontString") then
			object:SetWidth(0.001);
		elseif(objectType == "StatusBar") then
			object:SetStatusBarTexture("");
		end
		object:Hide();
	end
	
	if(not NP.CheckFilter(self, myPlate)) then return; end
	myPlate:SetSize(self:GetSize());
	
	NP.UpdateLevelAndName(self, myPlate);
	NP.ColorizeAndScale(self, myPlate);
	
	NP.UpdateElement_HealthOnValueChanged(self.HealthBar, self.HealthBar:GetValue());
	myPlate.nameText = gsub(self.Name:GetText(), FSPAT,"");
	
	NP:CheckRaidIcon(self);

	if(NP.db.buffs.enable) then
		NP:UpdateAuraIcons(myPlate.Buffs);
	end

	if(NP.db.debuffs.enable) then
		NP:UpdateAuraIcons(myPlate.Debuffs);
	end

	if(NP.db.buffs.enable or NP.db.debuffs.enable) then
		NP:UpdateElement_Auras(self);
	end
	
	NP:UpdateElement_CPoints(self);
	
	if(not NP.db.targetIndicator.colorMatchHealthBar) then
		NP:ColorTargetIndicator(NP.db.targetIndicator.color.r, NP.db.targetIndicator.color.g, NP.db.targetIndicator.color.b);
	end
end

function NP:OnHide()
	local myPlate = NP.CreatedPlates[self];
	self.threatReaction = nil;
	self.unitType = nil;
	self.guid = nil;
	self.unit = nil;
	self.raidIconType = nil;
	self.customColor = nil;
	self.customScale = nil;
	self.allowCheck = nil;

	if(targetIndicator:GetParent() == myPlate) then
		targetIndicator:Hide();
	end

	myPlate.RaidIcon.ULx, myPlate.RaidIcon.ULy = nil, nil;
	myPlate.Glow.r, myPlate.Glow.g, myPlate.Glow.b = nil, nil, nil;
	myPlate.Glow:Hide();

	myPlate:SetAlpha(0);

	if(myPlate.Buffs) then
		for index = 1, #myPlate.Buffs.icons do 
			NP.PolledHideIn(myPlate.Buffs.icons[index], 0);
		end
	end

	if(myPlate.Debuffs) then
		for index = 1, #myPlate.Debuffs.icons do 
			NP.PolledHideIn(myPlate.Debuffs.icons[index], 0);
		end
	end

	NP:HideComboPoints(myPlate);

	--UIFrameFadeOut(myPlate, 0.1, myPlate:GetAlpha(), 0)
	--myPlate:Hide()

	--myPlate:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT") --Prevent nameplate being in random location on screen when first shown
end

function NP:UpdateSettings()
	local myPlate = NP.CreatedPlates[self];

	NP:ConfigureElement_HealthBar(myPlate, self.customScale);
	NP:ConfigureElement_Level(myPlate);
	NP:ConfigureElement_Name(myPlate);
	NP:ConfigureElement_CastBar(myPlate);
	NP:ConfigureElement_RaidIcon(myPlate);
	NP:ConfigureElement_CPoints(myPlate);

	NP.OnShow(self);
end

function NP:CreatePlate(frame)
	frame.HealthBar, frame.CastBar = frame:GetChildren();
	frame.threat, frame.border, frame.CastBar.Shield, frame.CastBar.Border, frame.CastBar.Icon, frame.highlight, frame.Name, frame.Level, frame.bossIcon, frame.RaidIcon, frame.eliteIcon = frame:GetRegions();
	local myPlate = CreateFrame("Frame", nil, self.PlateParent);
	
	myPlate.hiddenFrame = CreateFrame("Frame", nil, myPlate);
	myPlate.hiddenFrame:Hide();
	
	myPlate.HealthBar = self:ConstructElement_HealthBar(myPlate);
	frame.CastBar.Icon:SetParent(myPlate.hiddenFrame);
	myPlate.CastBar = self:ConstructElement_CastBar(myPlate);
	myPlate.Level = self:ConstructElement_Level(myPlate);
	myPlate.Name = self:ConstructElement_Name(myPlate);
	frame.RaidIcon:SetAlpha(0);
	myPlate.RaidIcon = self:ConstructElement_RaidIcon(myPlate);

	myPlate.overlay = myPlate:CreateTexture(nil, "OVERLAY");
	myPlate.overlay:SetAllPoints(myPlate.HealthBar);
	myPlate.overlay:SetTexture(1, 1, 1, 0.3);
	myPlate.overlay:Hide();

	myPlate.Glow = self:ConstructElement_Glow(myPlate);
	myPlate.Buffs = self:ConstructElement_Auras(myPlate, 5, "RIGHT");
	myPlate.Buffs.db = self.db.buffs;
	myPlate.Debuffs = self:ConstructElement_Auras(myPlate, 5, "LEFT");
	myPlate.Debuffs.db = self.db.debuffs;

	myPlate.CPoints = self:ConstructElement_CPoints(myPlate);

	frame:HookScript("OnShow", NP.OnShow);
	frame:HookScript("OnHide", NP.OnHide);
	frame:HookScript("OnSizeChanged", NP.OnSizeChanged);
	frame.HealthBar:HookScript("OnValueChanged", self.UpdateElement_HealthOnValueChanged);
	frame.CastBar:HookScript("OnShow", self.UpdateElement_CastBarOnShow);
	frame.CastBar:HookScript("OnHide", self.UpdateElement_CastBarOnHide);
	frame.CastBar:HookScript("OnValueChanged", self.UpdateElement_CastBarOnValueChanged);

	NP:QueueObject(frame, frame.HealthBar);
	NP:QueueObject(frame, frame.CastBar);
	NP:QueueObject(frame, frame.Level);
	NP:QueueObject(frame, frame.Name);
	NP:QueueObject(frame, frame.threat);
	NP:QueueObject(frame, frame.border);
	NP:QueueObject(frame, frame.CastBar.Shield);
	NP:QueueObject(frame, frame.CastBar.Border);
	NP:QueueObject(frame, frame.highlight);
	NP:QueueObject(frame, frame.bossIcon);
	NP:QueueObject(frame, frame.eliteIcon);
	NP:QueueObject(frame, frame.CastBar.Icon);

	self.CreatedPlates[frame] = myPlate;
	NP.UpdateSettings(frame);
	if(not frame.CastBar:IsShown()) then
		myPlate.CastBar:Hide();
	else
		self.UpdateElement_CastBarOnShow(frame.CastBar);
	end
end

function NP:QueueObject(frame, object)
	frame.queue = frame.queue or {};
	frame.queue[object] = true;
	
	if(object.OldTexture) then
		object:SetTexture(object.OldTexture);
	end
end

function NP:ScanFrames(...)
	for index = 1, select("#", ...) do
		local frame = select(index, ...);
		local region = frame:GetRegions();
		
		if(not NP.CreatedPlates[frame] and not frame:GetName() and region and region:GetObjectType() == "Texture" and region:GetTexture() == OVERLAY) then
			NP:CreatePlate(frame);
		end
	end
end

function NP:CreateBackdrop(parent, point)
	point = point or parent
	local noscalemult = E.mult * UIParent:GetScale()
	
	if point.bordertop then return end
	
	point.backdrop = parent:CreateTexture(nil, "BACKGROUND");
	point.backdrop:SetAllPoints(point);
	point.backdrop:SetTexture(unpack(E["media"].backdropfadecolor));
	
	if(E.PixelMode) then 
		point.bordertop = parent:CreateTexture(nil, "BORDER");
		point.bordertop:SetPoint("TOPLEFT", point, "TOPLEFT", -noscalemult, noscalemult);
		point.bordertop:SetPoint("TOPRIGHT", point, "TOPRIGHT", noscalemult, noscalemult);
		point.bordertop:SetHeight(noscalemult);
		point.bordertop:SetTexture(unpack(E["media"].bordercolor));
		
		point.borderbottom = parent:CreateTexture(nil, "BORDER");
		point.borderbottom:SetPoint("BOTTOMLEFT", point, "BOTTOMLEFT", -noscalemult, -noscalemult);
		point.borderbottom:SetPoint("BOTTOMRIGHT", point, "BOTTOMRIGHT", noscalemult, -noscalemult)
		point.borderbottom:SetHeight(noscalemult);
		point.borderbottom:SetTexture(unpack(E["media"].bordercolor));
		
		point.borderleft = parent:CreateTexture(nil, "BORDER");
		point.borderleft:SetPoint("TOPLEFT", point, "TOPLEFT", -noscalemult, noscalemult);
		point.borderleft:SetPoint("BOTTOMLEFT", point, "BOTTOMLEFT", noscalemult, -noscalemult);
		point.borderleft:SetWidth(noscalemult);
		point.borderleft:SetTexture(unpack(E["media"].bordercolor));
		
		point.borderright = parent:CreateTexture(nil, "BORDER");
		point.borderright:SetPoint("TOPRIGHT", point, "TOPRIGHT", noscalemult, noscalemult);
		point.borderright:SetPoint("BOTTOMRIGHT", point, "BOTTOMRIGHT", -noscalemult, -noscalemult);
		point.borderright:SetWidth(noscalemult);
		point.borderright:SetTexture(unpack(E["media"].bordercolor));
	else
		point.bordertop = parent:CreateTexture(nil, "OVERLAY");
		point.bordertop:SetPoint("TOPLEFT", point, "TOPLEFT", -noscalemult*2, noscalemult*2);
		point.bordertop:SetPoint("TOPRIGHT", point, "TOPRIGHT", noscalemult*2, noscalemult*2);
		point.bordertop:SetHeight(noscalemult);
		point.bordertop:SetTexture(unpack(E.media.bordercolor));
		
		point.bordertop.backdrop = parent:CreateTexture(nil, "BORDER")
		point.bordertop.backdrop:SetPoint("TOPLEFT", point.bordertop, "TOPLEFT", -noscalemult, noscalemult);
		point.bordertop.backdrop:SetPoint("TOPRIGHT", point.bordertop, "TOPRIGHT", noscalemult, noscalemult);
		point.bordertop.backdrop:SetHeight(noscalemult * 3);
		point.bordertop.backdrop:SetTexture(0, 0, 0);
		
		point.borderbottom = parent:CreateTexture(nil, "OVERLAY");
		point.borderbottom:SetPoint("BOTTOMLEFT", point, "BOTTOMLEFT", -noscalemult*2, -noscalemult*2);
		point.borderbottom:SetPoint("BOTTOMRIGHT", point, "BOTTOMRIGHT", noscalemult*2, -noscalemult*2);
		point.borderbottom:SetHeight(noscalemult);
		point.borderbottom:SetTexture(unpack(E.media.bordercolor));
		
		point.borderbottom.backdrop = parent:CreateTexture(nil, "BORDER");
		point.borderbottom.backdrop:SetPoint("BOTTOMLEFT", point.borderbottom, "BOTTOMLEFT", -noscalemult, -noscalemult);
		point.borderbottom.backdrop:SetPoint("BOTTOMRIGHT", point.borderbottom, "BOTTOMRIGHT", noscalemult, -noscalemult);
		point.borderbottom.backdrop:SetHeight(noscalemult * 3);
		point.borderbottom.backdrop:SetTexture(0, 0, 0);
		
		point.borderleft = parent:CreateTexture(nil, "OVERLAY");
		point.borderleft:SetPoint("TOPLEFT", point, "TOPLEFT", -noscalemult*2, noscalemult*2);
		point.borderleft:SetPoint("BOTTOMLEFT", point, "BOTTOMLEFT", noscalemult*2, -noscalemult*2);
		point.borderleft:SetWidth(noscalemult);
		point.borderleft:SetTexture(unpack(E.media.bordercolor));
		
		point.borderleft.backdrop = parent:CreateTexture(nil, "BORDER");
		point.borderleft.backdrop:SetPoint("TOPLEFT", point.borderleft, "TOPLEFT", -noscalemult, noscalemult);
		point.borderleft.backdrop:SetPoint("BOTTOMLEFT", point.borderleft, "BOTTOMLEFT", -noscalemult, -noscalemult);
		point.borderleft.backdrop:SetWidth(noscalemult * 3);
		point.borderleft.backdrop:SetTexture(0, 0, 0);
		
		point.borderright = parent:CreateTexture(nil, "OVERLAY");
		point.borderright:SetPoint("TOPRIGHT", point, "TOPRIGHT", noscalemult*2, noscalemult*2);
		point.borderright:SetPoint("BOTTOMRIGHT", point, "BOTTOMRIGHT", -noscalemult*2, -noscalemult*2);
		point.borderright:SetWidth(noscalemult);
		point.borderright:SetTexture(unpack(E.media.bordercolor));
		
		point.borderright.backdrop = parent:CreateTexture(nil, "BORDER");
		point.borderright.backdrop:SetPoint("TOPRIGHT", point.borderright, "TOPRIGHT", noscalemult, noscalemult);
		point.borderright.backdrop:SetPoint("BOTTOMRIGHT", point.borderright, "BOTTOMRIGHT", noscalemult, -noscalemult);
		point.borderright.backdrop:SetWidth(noscalemult * 3);
		point.borderright.backdrop:SetTexture(0, 0, 0);
	end
end

---------------------------------------------
--Auras
---------------------------------------------
do
	local PolledHideIn
	local Framelist = {}
	local Watcherframe = CreateFrame("Frame")
	local WatcherframeActive = false
	local select = select
	local timeToUpdate = 0
	
	local function CheckFramelist(self)
		local curTime = GetTime()
		if curTime < timeToUpdate then return end
		local framecount = 0
		timeToUpdate = curTime + AURA_UPDATE_INTERVAL

		for frame, expiration in pairs(Framelist) do
			if expiration < curTime then 
				frame:Hide(); 
				Framelist[frame] = nil
			else 
				if frame.Poll then 
					frame.Poll(NP, frame, expiration) 
				end
				framecount = framecount + 1 
			end
		end

		if framecount == 0 then 
			Watcherframe:SetScript("OnUpdate", nil); 
			WatcherframeActive = false 
		end
	end
	
	function PolledHideIn(frame, expiration)
		if(not frame) then return end
		if expiration == 0 then 
			frame:Hide()
			Framelist[frame] = nil
		else
			Framelist[frame] = expiration
			frame:Show()
			
			if not WatcherframeActive then 
				Watcherframe:SetScript("OnUpdate", CheckFramelist)
				WatcherframeActive = true
			end
		end
	end
	
	NP.PolledHideIn = PolledHideIn
end

function NP:GetSpellDuration(spellID)
	if(spellID) then return NP.CachedAuraDurations[spellID]; end
end

function NP:SetSpellDuration(spellID, duration)
	if(spellID) then NP.CachedAuraDurations[spellID] = duration; end
end

function NP:UpdateAuraTime(frame, expiration)
	local timeleft = expiration - GetTime();
	local timervalue, formatid = E:GetTimeInfo(timeleft, 4);
	local format = E.TimeFormats[3][2];
	if(timervalue < 4) then
		format = E.TimeFormats[4][2];
	end
	frame.timeLeft:SetFormattedText(("%s%s|r"):format(TimeColors[formatid], format), timervalue);
end

function NP:ClearAuraContext(frame)
	AuraList[frame] = nil
end

function NP:RemoveAuraInstance(guid, spellID, caster)
	if guid and spellID and NP.AuraList[guid] then
		local instanceID = tostring(guid)..tostring(spellID)..(tostring(caster or "UNKNOWN_CASTER"))
		local auraID = spellID..(tostring(caster or "UNKNOWN_CASTER"))
		if NP.AuraList[guid][auraID] then
			NP.AuraSpellID[instanceID] = nil
			NP.AuraExpiration[instanceID] = nil
			NP.AuraStacks[instanceID] = nil
			NP.AuraCaster[instanceID] = nil
			NP.AuraDuration[instanceID] = nil
			NP.AuraTexture[instanceID] = nil
			NP.AuraType[instanceID] = nil
			NP.AuraTarget[instanceID] = nil
			NP.AuraList[guid][auraID] = nil
		end
	end
end

function NP:GetAuraList(guid)
	if guid and self.AuraList[guid] then return self.AuraList[guid] end
end

function NP:GetAuraInstance(guid, auraID)
	if guid and auraID then
		local instanceID = guid..auraID
		return self.AuraSpellID[instanceID], self.AuraExpiration[instanceID], self.AuraStacks[instanceID], self.AuraCaster[instanceID], self.AuraDuration[instanceID], self.AuraTexture[instanceID], self.AuraType[instanceID], self.AuraTarget[instanceID]
	end
end

function NP:SetAuraInstance(guid, spellID, expiration, stacks, caster, duration, texture, auraType, auraTarget)
	local filter = false;
	local db = self.db.buffs;
	if(auraType == AURA_TYPE_DEBUFF) then
		db = self.db.debuffs;
	end

	if(db.filters.personal and caster == UnitGUID("player")) then
		filter = true;
	end

	local trackFilter = E.global["unitframe"]["aurafilters"][db.filters.filter];
	if(db.filters.filter and trackFilter) then
		local name = GetSpellInfo(spellID);
		local spellList = trackFilter.spells;
		local type = trackFilter.type;
		if(type == "Blacklist") then
			if(spellList[name] and spellList[name].enable) then
				filter = false;
			end
		else
			if(spellList[name] and spellList[name].enable) then
				filter = true;
			end
		end
	end

	if(E.global.unitframe.InvalidSpells[spellID]) then
		filter = false;
	end

	if(filter ~= true) then
		return;
	end

	if(guid and spellID and caster and texture) then
		local auraID = spellID .. (tostring(caster or "UNKNOWN_CASTER"));
		local instanceID = guid .. auraID;
		NP.AuraList[guid] = NP.AuraList[guid] or {};
		NP.AuraList[guid][auraID] = instanceID;
		NP.AuraSpellID[instanceID] = spellID;
		NP.AuraExpiration[instanceID] = expiration;
		NP.AuraStacks[instanceID] = stacks;
		NP.AuraCaster[instanceID] = caster;
		NP.AuraDuration[instanceID] = duration;
		NP.AuraTexture[instanceID] = texture;
		NP.AuraType[instanceID] = auraType;
		NP.AuraTarget[instanceID] = auraTarget;
	end
end

function NP:UNIT_AURA(event, unit)
	if(unit == "target") then
		self:UpdateAurasByUnitID("target");
	elseif(unit == "focus") then
		self:UpdateAurasByUnitID("focus");
	end
end

function NP:COMBAT_LOG_EVENT_UNFILTERED(_, _, event, ...)
	local sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellID, spellName, _, auraType, stackCount = ...;
	if(event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH" or event == "SPELL_AURA_APPLIED_DOSE" or event == "SPELL_AURA_REMOVED_DOSE" or event == "SPELL_AURA_BROKEN" or event == "SPELL_AURA_BROKEN_SPELL" or event == "SPELL_AURA_REMOVED") then
		if(event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH") then
			local duration = self:GetSpellDuration(spellID);
			local texture = GetSpellTexture(spellID);
			self:SetAuraInstance(destGUID, spellID, GetTime() + (duration or 0), 1, sourceGUID, duration, texture, auraType, AURA_TARGET_HOSTILE);
		elseif event == "SPELL_AURA_APPLIED_DOSE" or event == "SPELL_AURA_REMOVED_DOSE" then
			local duration = self:GetSpellDuration(spellID);
			local texture = GetSpellTexture(spellID);
			self:SetAuraInstance(destGUID, spellID, GetTime() + (duration or 0), stackCount, sourceGUID, duration, texture, auraType, AURA_TARGET_HOSTILE);
		elseif(event == "SPELL_AURA_BROKEN" or event == "SPELL_AURA_BROKEN_SPELL" or event == "SPELL_AURA_REMOVED") then
			self:RemoveAuraInstance(destGUID, spellID, sourceGUID);
		end

		local name, raidIcon;
		if(band(destFlags, COMBATLOG_OBJECT_CONTROL_PLAYER) > 0 and destName) then
			local rawName = strsplit("-", destName);
			self.ByName[rawName] = destGUID;
			name = rawName;
		end

		for iconName, bitmask in pairs(self.RaidTargetReference) do
			if(band(destFlags, bitmask) > 0) then
				self.ByRaidIcon[iconName] = destGUID;
				raidIcon = iconName;
				break;
			end
		end

		local frame = self:SearchForFrame(destGUID, raidIcon, name);
		if(frame) then
			self:UpdateElement_Auras(frame);
		end
	end
end

function NP:WipeAuraList(guid)
	if(guid and self.AuraList[guid]) then
		local unitAuraList = self.AuraList[guid];
		for auraID, instanceID in pairs(unitAuraList) do
			self.AuraSpellID[instanceID] = nil;
			self.AuraExpiration[instanceID] = nil;
			self.AuraStacks[instanceID] = nil;
			self.AuraCaster[instanceID] = nil;
			self.AuraDuration[instanceID] = nil;
			self.AuraTexture[instanceID] = nil;
			self.AuraType[instanceID] = nil;
			self.AuraTarget[instanceID] = nil;
			unitAuraList[auraID] = nil;
		end
	end
end

function NP:UpdateAurasByUnitID(unit)
	local guid = UnitGUID(unit);
	self:WipeAuraList(guid);

	local index = 1;
	local name, _, texture, count, _, duration, expirationTime, unitCaster, _, _, spellID = UnitDebuff(unit, index);
	while(name) do
		NP:SetSpellDuration(spellID, duration);
		NP:SetAuraInstance(guid, spellID, expirationTime, count, UnitGUID(unitCaster or ""), duration, texture, AURA_TYPE_DEBUFF);
		index = index + 1;
		name , _, texture, count, _, duration, expirationTime, unitCaster, _, _, spellID = UnitDebuff(unit, index);
	end

	index = 1;
	local name, _, texture, count, _, duration, expirationTime, unitCaster, _, _, spellID = UnitBuff(unit, index);
	while(name) do
		NP:SetSpellDuration(spellID, duration);
		NP:SetAuraInstance(guid, spellID, expirationTime, count, UnitGUID(unitCaster or ""), duration, texture, AURA_TYPE_BUFF);
		index = index + 1;
		name, _, texture, count, _, duration, expirationTime, unitCaster, _, _, spellID = UnitBuff(unit, index);
	end
	
	local raidIcon, name;
	if(UnitPlayerControlled(unit)) then name = UnitName(unit); end
	raidIcon = RaidIconIndex[GetRaidTargetIndex(unit) or ""];
	if(raidIcon) then self.ByRaidIcon[raidIcon] = guid; end

	local frame = self:SearchForFrame(guid, raidIcon, name);
	if(frame) then
		NP:UpdateElement_Auras(frame);
	end
end

function NP:UpdateElement_Auras(frame)
	local guid = frame.guid;
	local myPlate = NP.CreatedPlates[frame];

	if(not guid) then
		if(RAID_CLASS_COLORS[frame.unitType]) then
			local name = gsub(frame.Name:GetText(), "%s%(%*%)","");
			guid = NP.ByName[name];
		elseif(frame.RaidIcon:IsShown()) then
			guid = NP.ByRaidIcon[frame.raidIconType];
		end

		if(guid) then
			frame.guid = guid;
		else
			myPlate.Debuffs:Hide();
			myPlate.Buffs:Hide();
			return;
		end
	end

	local hasBuffs = false;
	local hasDebuffs = false;
	local buffs = myPlate.Buffs;
	local debuffs = myPlate.Debuffs;
	local aurasOnUnit = self:GetAuraList(guid);
	local BuffSlotIndex = 1;
	local DebuffSlotIndex = 1;

	if(aurasOnUnit) then
		for instanceid in pairs(aurasOnUnit) do
			local aura = {};
			aura.spellID, aura.expirationTime, aura.count, aura.caster, aura.duration, aura.icon, aura.type, aura.target = self:GetAuraInstance(guid, instanceid);
			if(tonumber(aura.spellID)) then
				aura.name = GetSpellInfo(tonumber(aura.spellID));
				aura.unit = frame.unit;
				if(aura.expirationTime > GetTime()) then
					if(aura.type == "BUFF") then
						tinsert(self.BuffCache, aura);
					else
						tinsert(self.DebuffCache, aura);
					end
				end
			end
		end
	end

	if(self.db.buffs.enable) then
		buffs:Show();
		for index = 1, #self.BuffCache do
			local cachedaura = self.BuffCache[index];
			if(cachedaura and cachedaura.spellID and cachedaura.expirationTime) then
				self:SetAura(buffs.icons[BuffSlotIndex], cachedaura.icon, cachedaura.count, cachedaura.duration, cachedaura.expirationTime);
				BuffSlotIndex = BuffSlotIndex + 1;
				hasBuffs = true;
			end

			if(BuffSlotIndex > NP.db.buffs.numAuras) then
				break;
			end
		end
	else
		buffs:Hide();
	end

	if(self.db.debuffs.enable) then
		debuffs:Show();
		for index = 1, #self.DebuffCache do
			local cachedaura = self.DebuffCache[index];
			if(cachedaura.spellID and cachedaura.expirationTime) then
				self:SetAura(debuffs.icons[DebuffSlotIndex], cachedaura.icon, cachedaura.count, cachedaura.duration, cachedaura.expirationTime);
				DebuffSlotIndex = DebuffSlotIndex + 1;
				hasDebuffs = true;
			end

			if(DebuffSlotIndex > NP.db.debuffs.numAuras) then
				break;
			end
		end
	else
		debuffs:Hide();
	end
	
	if(buffs.icons[BuffSlotIndex]) then
		NP.PolledHideIn(buffs.icons[BuffSlotIndex], 0);
	end

	if(debuffs.icons[DebuffSlotIndex]) then
		NP.PolledHideIn(debuffs.icons[DebuffSlotIndex], 0);
	end

	self.BuffCache = wipe(self.BuffCache);
	self.DebuffCache = wipe(self.DebuffCache);

	local TopLevel = myPlate.HealthBar;
	local TopOffset = select(2, myPlate.Name:GetFont()) + 5 or 0;
	if(hasDebuffs) then
		TopOffset = TopOffset + 3;
		debuffs:SetPoint("BOTTOMLEFT", TopLevel, "TOPLEFT", 0, TopOffset);
		debuffs:SetPoint("BOTTOMRIGHT", TopLevel, "TOPRIGHT", 0, TopOffset);
		TopLevel = debuffs;
		TopOffset = 3;
	end

	if(hasBuffs) then
		if(not hasDebuffs) then
			TopOffset = TopOffset + 3;
		end
		buffs:SetPoint("BOTTOMLEFT", TopLevel, "TOPLEFT", 0, TopOffset);
		buffs:SetPoint("BOTTOMRIGHT", TopLevel, "TOPRIGHT", 0, TopOffset);
		TopLevel = buffs;
		TopOffset = 3;
	end
end

function NP:UpdateAuraByLookup(guid)
 	if(guid == UnitGUID("target")) then
		NP:UpdateAurasByUnitID("target");
	elseif(guid == UnitGUID("mouseover")) then
		NP:UpdateAurasByUnitID("mouseover");
	end
end

function NP:CheckRaidIcon(frame)
	if(frame.RaidIcon:IsShown()) then
		local ux, uy = frame.RaidIcon:GetTexCoord();
		frame.raidIconType = NP.RaidIconCoordinate[ux][uy];
	else
		frame.raidIconType = nil;
	end
end

function NP:SearchNameplateByGUID(guid)
	for frame, _ in pairs(NP.CreatedPlates) do
		if(frame and frame:IsShown() and frame.guid == guid) then
			return frame;
		end
	end
end

function NP:SearchNameplateByName(sourceName)
	if(not sourceName) then return; end
	local SearchFor = strsplit("-", sourceName)
	for frame, myPlate in pairs(NP.CreatedPlates) do
		if(frame and frame:IsShown() and myPlate.nameText == SearchFor and RAID_CLASS_COLORS[frame.unitType]) then
			return frame;
		end
	end
end

function NP:SearchNameplateByIconName(raidIcon)
	for frame, _ in pairs(NP.CreatedPlates) do
		NP:CheckRaidIcon(frame)
		if(frame and frame:IsShown() and frame.RaidIcon:IsShown() and (frame.raidIconType == raidIcon)) then
			return frame
		end
	end
end

function NP:SearchForFrame(guid, raidIcon, name)
	local frame;
	if(guid) then frame = self:SearchNameplateByGUID(guid); end
	if((not frame) and name) then frame = self:SearchNameplateByName(name); end
	if((not frame) and raidIcon) then frame = self:SearchNameplateByIconName(raidIcon); end

	return frame;
end

E:RegisterModule(NP:GetName());