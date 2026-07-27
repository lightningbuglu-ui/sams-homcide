if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_base"
SWEP.PrintName = "Radar"
SWEP.Instructions = "A radar that detects heartbeats. Left click to scan. 2 charges, no recharge."
SWEP.Category = "ZCity Other"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.HoldType = "slam"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/bandages.mdl"

if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_walkietalkie")
	SWEP.IconOverride = "vgui/wep_jack_hmcd_walkietalkie.png"
	SWEP.BounceWeaponIcon = false
end

SWEP.ScrappersSlot = "Medicine"
SWEP.Weight = 0
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.Slot = 3
SWEP.SlotPos = 1

SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(4, -3.5, 0)
SWEP.offsetAng = Angle(90, 90, 0)

SWEP.MaxCharges = 3  -- max possible (actual charges randomized 2-3 on spawn)
SWEP.ScanRadius = 1500      -- Hammer units
SWEP.DetectionDuration = 8  -- seconds markers stay visible after scan
SWEP.HudLingerTime = 5      -- seconds the HUD stays visible after unequipping

modelshuy = modelshuy or {}

-- ============================================================
-- World Model Drawing
-- ============================================================

function SWEP:DrawWorldModel()
	if not IsValid(self:GetOwner()) then
		self:DrawWorldModel2()
	end
end

function SWEP:DrawWorldModel2(nodraw)
	if self.Color then
		render.SetColorModulation(self.Color.r/255, self.Color.g/255, self.Color.b/255)
	end

	local mdl = self.Model or self.WorldModel
	modelshuy[mdl] = IsValid(modelshuy[mdl]) and modelshuy[mdl] or ClientsideModel(mdl)
	modelshuy[mdl]:SetNoDraw(true)
	local WorldModel = modelshuy[mdl]
	local owner = self:GetOwner()
	local ownerChar = hg.GetCurrentCharacter(owner)
	if not IsValid(WorldModel) then return end

	for i = 1, #self:GetBodyGroups() do
		WorldModel:SetBodygroup(i, self:GetBodygroup(i))
	end

	if self.ModelScale then WorldModel:SetModelScale(self.ModelScale or 1) end
	if self.Color then WorldModel:SetColor(self.Color or color_white) end

	if IsValid(ownerChar) then
		local boneid = ownerChar:LookupBone(
			((ownerChar.organism and ownerChar.organism.rarmamputated) or
			(ownerChar.zmanipstart ~= nil and ownerChar.zmanipseq == "interact" and not ownerChar.organism.larmamputated))
			and "ValveBiped.Bip01_L_Hand" or "ValveBiped.Bip01_R_Hand"
		)
		if not boneid then return end
		local matrix = ownerChar:GetBoneMatrix(boneid)
		if not matrix then return end
		local newPos, newAng = LocalToWorld(self.offsetVec, self.offsetAng, matrix:GetTranslation(), matrix:GetAngles())
		WorldModel:SetPos(newPos)
		WorldModel:SetAngles(newAng)
		WorldModel:SetupBones()
	else
		WorldModel:SetPos(self:GetPos())
		WorldModel:SetAngles(self:GetAngles())
	end

	WorldModel:SetupBones()
	if not nodraw then WorldModel:DrawModel() end
	if self.Color then render.SetColorModulation(1, 1, 1) end
end

-- ============================================================
-- Network Setup
-- ============================================================

function SWEP:SetupDataTables()
	self:NetworkVar("Float", 0, "Charges")
	self:NetworkVar("Float", 1, "MaxRolledCharges")  -- the rolled max (2 or 3) for pip display
	if self.SetupDataTablesAdd then
		self:SetupDataTablesAdd()
	end
end

if SERVER then
	util.AddNetworkString("radar_scan_result")
	util.AddNetworkString("radar_hud_linger")
	util.AddNetworkString("radar_electric_fx")
end

-- ============================================================
-- Initialize
-- ============================================================

SWEP.DeploySnd = "physics/body/body_medium_impact_soft5.wav"
SWEP.HolsterSnd = ""
SWEP.FallSnd = "physics/body/body_medium_impact_soft5.wav"

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)

	if SERVER then
		-- Random 2 or 3 charges each time
		local rolled = math.random(2, 3)
		self:SetCharges(rolled)
		self:SetMaxRolledCharges(rolled)
	end

	util.PrecacheSound(self.DeploySnd)
	util.PrecacheSound(self.HolsterSnd)
	util.PrecacheSound(self.FallSnd)
	util.PrecacheSound("buttons/blip1.wav")
	util.PrecacheSound("buttons/lightswitch2.wav")
	util.PrecacheSound("ambient/energy/zap1.wav")
	util.PrecacheSound("ambient/energy/zap2.wav")
	util.PrecacheSound("ambient/energy/zap3.wav")

	self:AddCallback("PhysicsCollide", function(ent, data)
		if data.Speed > 200 then
			ent:EmitSound(self.FallSnd or self.DeploySnd, 65, math.random(90, 110))
		end
	end)
end

-- ============================================================
-- Think - no recharge
-- ============================================================

function SWEP:Think()
	-- No recharge. Charges spent are gone.
end

-- ============================================================
-- Primary Attack - Radar Scan
-- ============================================================

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 1)

	if SERVER then
		local charges = self:GetCharges()
		if charges <= 0 then
			self:GetOwner():EmitSound("buttons/blip1.wav", 60, 80)
			return
		end

		self:SetCharges(charges - 1)

		local owner = self:GetOwner()
		local ownerPos = owner:GetPos()

		-- Electric zap sounds (random pick from HL2 set)
		local zapSounds = {"ambient/energy/zap1.wav","ambient/energy/zap2.wav","ambient/energy/zap3.wav"}
		owner:EmitSound(zapSounds[math.random(#zapSounds)], 75, math.random(90, 110))

		-- Send electric particle effect to all nearby clients
		net.Start("radar_electric_fx")
		net.WriteVector(ownerPos + Vector(0,0,40))
		net.WriteEntity(owner)
		net.Broadcast()

		-- Detect nearby players only, skip the radar holder
		local detected = {}
		for _, ply in ipairs(player.GetAll()) do
			if ply == owner then continue end
			if not IsValid(ply) then continue end
			if not ply:Alive() then continue end

			local dist = ply:GetPos():Distance(ownerPos)
			if dist <= self.ScanRadius then
				table.insert(detected, {
					entindex = ply:EntIndex(),
					pos      = ply:GetPos(),
					name     = ply:GetName(),
					dist     = math.Round(dist / 52.49)
				})
			end
		end

		-- Send results to owner only
		net.Start("radar_scan_result")
		net.WriteUInt(#detected, 8)
		for _, d in ipairs(detected) do
			net.WriteUInt(d.entindex, 16)
			net.WriteVector(d.pos)
			net.WriteString(d.name)
			net.WriteUInt(d.dist, 16)
		end
		net.WriteFloat(CurTime() + self.DetectionDuration)
		net.Send(owner)

		-- If out of charges: drop the prop world model, then remove weapon
		if self:GetCharges() <= 0 then
			-- Spawn a physics prop at the player's hand position as a dropped item
			local ent = ents.Create("prop_physics")
			ent:SetModel(self.WorldModel)
			ent:SetPos(ownerPos + owner:GetAimVector() * 20 + Vector(0,0,40))
			ent:SetAngles(AngleRand(-30, 30))
			ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
			ent:Spawn()
			ent:Activate()

			local phys = ent:GetPhysicsObject()
			if IsValid(phys) then
				phys:SetVelocity(owner:GetAimVector() * 100 + VectorRand(-30, 30))
				phys:AddAngleVelocity(VectorRand(-80, 80))
			end

			-- Tell client to keep the HUD lingering
			net.Start("radar_hud_linger")
			net.WriteFloat(CurTime() + self.HudLingerTime)
			net.Send(owner)

			timer.Simple(0.1, function()
				if IsValid(self) then
					local o = self:GetOwner()
					if IsValid(o) then
						o:SelectWeapon("weapon_hands_sh")
					end
					self:Remove()
				end
			end)
		end
	end
end

function SWEP:SecondaryAttack() end
function SWEP:Reload() end

-- ============================================================
-- Holster: tell client to linger the HUD
-- ============================================================

function SWEP:Holster(wep)
	if not IsValid(wep) or wep == self then return true end

	if SERVER then
		local owner = self:GetOwner()
		if IsValid(owner) and owner:IsPlayer() then
			net.Start("radar_hud_linger")
			net.WriteFloat(CurTime() + self.HudLingerTime)
			net.Send(owner)
		end
	end

	if CLIENT and self:IsLocal() then
		self:EmitSound(self.HolsterSnd, 50)
	end

	return true
end

-- ============================================================
-- HUD + Red Outline Rendering
-- ============================================================

if CLIENT then
	local radarDetected  = {}   -- {entindex, pos, name, dist, expireTime}
	local hudLingerUntil = 0    -- timestamp: keep drawing HUD until this time
	local lastCharges    = 0
	local lastChargeSwep = nil  -- last known swep ref for linger charge display

	net.Receive("radar_scan_result", function()
		radarDetected = {}
		local count = net.ReadUInt(8)
		local entries = {}
		for i = 1, count do
			entries[i] = {
				entindex = net.ReadUInt(16),
				pos      = net.ReadVector(),
				name     = net.ReadString(),
				dist     = net.ReadUInt(16),
			}
		end
		local expire = net.ReadFloat()
		for _, e in ipairs(entries) do
			e.expireTime = expire
			table.insert(radarDetected, e)
		end
	end)

	net.Receive("radar_hud_linger", function()
		hudLingerUntil = net.ReadFloat()
	end)

	-- Electric particle effect on scan
	net.Receive("radar_electric_fx", function()
		local pos    = net.ReadVector()
		local owner  = net.ReadEntity()

		-- HL2 electric/energy particles
		local effect = EffectData()
		effect:SetOrigin(pos)
		effect:SetEntity(IsValid(owner) and owner or NULL)
		effect:SetScale(1.5)
		effect:SetMagnitude(2)
		util.Effect("ElectricSpark", effect)

		-- Also dispatch a bigger sparks burst
		local effect2 = EffectData()
		effect2:SetOrigin(pos)
		effect2:SetScale(2)
		effect2:SetMagnitude(3)
		util.Effect("Sparks", effect2)

		-- And a dynamic light flash
		local dlight = DynamicLight(0)
		if dlight then
			dlight.pos      = pos
			dlight.r        = 100
			dlight.g        = 180
			dlight.b        = 255
			dlight.brightness = 6
			dlight.size     = 300
			dlight.decay    = 1200
			dlight.dietime  = CurTime() + 0.35
		end
	end)

	local colRed   = Color(255, 40,  40,  255)
	local colWhite = Color(255, 255, 255, 255)
	local colBlack = Color(0,   0,   0,   200)
	local colGray  = Color(60,  60,  60,  200)

	-- Draw a red bounding box outline around an on-screen player
	-- Returns true if entity was on screen
	local function DrawOutlineAroundPlayer(ent, alpha)
		if not IsValid(ent) then return false end

		local pos  = ent:GetPos()
		local mins = ent:OBBMins()
		local maxs = ent:OBBMaxs()

		local corners = {
			pos + Vector(mins.x, mins.y, mins.z),
			pos + Vector(maxs.x, mins.y, mins.z),
			pos + Vector(mins.x, maxs.y, mins.z),
			pos + Vector(maxs.x, maxs.y, mins.z),
			pos + Vector(mins.x, mins.y, maxs.z),
			pos + Vector(maxs.x, mins.y, maxs.z),
			pos + Vector(mins.x, maxs.y, maxs.z),
			pos + Vector(maxs.x, maxs.y, maxs.z),
		}

		local minX, minY =  math.huge,  math.huge
		local maxX, maxY = -math.huge, -math.huge
		local anyVisible = false

		for _, corner in ipairs(corners) do
			local s = corner:ToScreen()
			if s.visible then
				anyVisible = true
				if s.x < minX then minX = s.x end
				if s.y < minY then minY = s.y end
				if s.x > maxX then maxX = s.x end
				if s.y > maxY then maxY = s.y end
			end
		end

		if not anyVisible then return false end

		local pad = 4
		minX = minX - pad
		minY = minY - pad
		maxX = maxX + pad
		maxY = maxY + pad

		local t = 2
		local r = Color(255, 40, 40, alpha)
		local b = Color(0, 0, 0, math.floor(alpha * 0.78))

		surface.SetDrawColor(r)
		surface.DrawRect(minX,         minY,         maxX - minX, t)
		surface.DrawRect(minX,         maxY - t,     maxX - minX, t)
		surface.DrawRect(minX,         minY,         t, maxY - minY)
		surface.DrawRect(maxX - t,     minY,         t, maxY - minY)

		draw.SimpleTextOutlined(
			ent:GetName(),
			"DermaDefaultBold",
			(minX + maxX) / 2,
			minY - 18,
			r,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP,
			1, b
		)

		return true
	end

	-- Main HUD hook — runs always so it can linger after unequip
	hook.Add("HUDPaint", "radar_hud_linger_draw", function()
		local lp = LocalPlayer()
		if not IsValid(lp) then return end

		-- Is the player currently holding the radar?
		local wep = lp:GetActiveWeapon()
		local holdingRadar = IsValid(wep) and wep:GetClass() == "weapon_radar"

		-- Should we be drawing at all?
		local shouldDraw = holdingRadar or (CurTime() < hudLingerUntil)
		if not shouldDraw then return end

		-- When lingering and nothing detected, nothing to show
		if not holdingRadar and #radarDetected == 0 then return end

		-- Fade alpha when lingering after unequip
		local alpha = 255
		if not holdingRadar then
			local remaining = hudLingerUntil - CurTime()
			local fadeFrac  = math.Clamp(remaining / 1.5, 0, 1) -- fade over last 1.5s
			alpha = math.floor(255 * fadeFrac)
		end
		if alpha <= 0 then return end

		local sw, sh = ScrW(), ScrH()
		local cx     = sw / 2
		local cy     = sh - 80

		-- Expire old detections
		for i = #radarDetected, 1, -1 do
			if CurTime() > radarDetected[i].expireTime then
				table.remove(radarDetected, i)
			end
		end

		-- Red outlines + off-screen arrows
		for _, d in ipairs(radarDetected) do
			local ent      = Entity(d.entindex)
			local onScreen = false

			if IsValid(ent) and ent:IsPlayer() then
				onScreen = DrawOutlineAroundPlayer(ent, alpha)
			end

			if not onScreen then
				local targetPos = IsValid(ent) and ent:GetPos() or d.pos
				local dir       = (targetPos - lp:EyePos()):GetNormalized()
				local right     = lp:EyeAngles():Right()
				local up        = lp:EyeAngles():Up()
				local screenDir = Vector(dir:Dot(right), -dir:Dot(up), 0):GetNormalized()

				local edgeX = math.Clamp(sw/2 + screenDir.x * (sw * 0.42), 20, sw - 20)
				local edgeY = math.Clamp(sh/2 + screenDir.y * (sh * 0.42), 20, sh - 20)

				surface.SetDrawColor(255, 40, 40, alpha)
				draw.NoTexture()
				surface.DrawRect(edgeX - 5, edgeY - 5, 10, 10)

				draw.SimpleTextOutlined(
					"▶ " .. d.name .. " ~" .. d.dist .. "m",
					"DermaDefault",
					edgeX + 14, edgeY,
					Color(255, 40, 40, alpha),
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER,
					1, Color(0, 0, 0, math.floor(alpha * 0.78))
				)
			end
		end

		-- Charge pips + label (only shown while actively holding)
		if holdingRadar then
			draw.SimpleTextOutlined("RADAR", "DermaDefaultBold", cx, cy - 20, colWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, colBlack)

			local chargeCount = math.floor(wep:GetCharges())
			local pipCount = math.max(math.floor(wep:GetMaxRolledCharges()), 2)
			for i = 1, pipCount do
				local x = cx - (pipCount * 18) / 2 + (i-1) * 22
				if i <= chargeCount then
					surface.SetDrawColor(colRed)
				else
					surface.SetDrawColor(colGray)
				end
				surface.DrawRect(x, cy, 16, 10)
				surface.SetDrawColor(0, 0, 0, 255)
				surface.DrawOutlinedRect(x, cy, 16, 10, 1)
			end

			if #radarDetected > 0 then
				draw.SimpleTextOutlined(
					#radarDetected .. " heartbeat(s) detected",
					"DermaDefault", cx, cy - 36,
					colRed, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
					1, colBlack
				)
			end
		end
	end)

	-- DrawHUD is only called while holding — we redirect to the hook above
	function SWEP:DrawHUD() end
end

-- ============================================================
-- Utility
-- ============================================================

function SWEP:IsLocal()
	return CLIENT and self:GetOwner() == LocalPlayer()
end

function SWEP:Deploy()
	if SERVER or CLIENT and self:IsLocal() then
		self:EmitSound(self.DeploySnd, 50, math.random(90, 110))
	end
	return true
end

function SWEP:OnRemove() end
