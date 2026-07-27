if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_base"
SWEP.PrintName = "Sniper case"
SWEP.Instructions = "Left Click to open the case and receive a weapon and ammo. The case will be dropped after use."
SWEP.Category = "ZCity Other"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Primary.ClipSize     = -1
SWEP.Primary.DefaultClip  = -1
SWEP.Primary.Automatic    = false
SWEP.Primary.Wait         = 1
SWEP.Primary.Next         = 0
SWEP.Primary.Ammo         = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

SWEP.HoldType   = "normal"
SWEP.ViewModel  = ""
SWEP.WorldModel = "models/props_c17/SuitCase_Passenger_Physics.mdl"
SWEP.Model      = "models/props_c17/SuitCase_Passenger_Physics.mdl"

if CLIENT then
    SWEP.WepSelectIcon    = Material("vgui/wep_jack_hmcd_mask")
    SWEP.IconOverride     = "vgui/wep_jack_hmcd_mask"
    SWEP.BounceWeaponIcon = false
end

SWEP.Weight          = 0
SWEP.AutoSwitchTo    = false
SWEP.AutoSwitchFrom  = false
SWEP.DrawAmmo        = false
SWEP.DrawCrosshair   = false
SWEP.Slot            = 5
SWEP.SlotPos         = 99
SWEP.WorkWithFake    = false
SWEP.offsetVec       = Vector(5, -1.5, -0.6)
SWEP.offsetAng       = Angle(-90, 0, 0)
SWEP.ModelScale      = 0.8

-- -------------------------------------------------------
-- Configure what weapons the case can give.
-- Ammo type and amount are detected automatically from the
-- weapon itself at runtime — no need to set them here.
-- AmmoBonus: extra ammo to give on top of the weapon's default clip.
-- -------------------------------------------------------
SWEP.CaseContents = {
    { Weapon = "weapon_cs5"    },
}

-- How many extra default-clips worth of ammo to give (0 = just the weapon's own default clip)
SWEP.AmmoBonus = 3

-- -------------------------------------------------------
-- World model drawing (unchanged from original)
-- -------------------------------------------------------
function SWEP:DrawWorldModel()
    self.model = IsValid(self.model) and self.model or ClientsideModel(self.WorldModel)
    local WorldModel = self.model
    local owner = self:GetOwner()
    WorldModel:SetNoDraw(true)
    WorldModel:SetModelScale(self.ModelScale)
    if IsValid(owner) then
        local boneid = owner:LookupBone("ValveBiped.Bip01_L_Hand")
        if not boneid then return end
        local matrix = owner:GetBoneMatrix(boneid)
        if not matrix then return end
        local newPos, newAng = LocalToWorld(self.offsetVec, self.offsetAng, matrix:GetTranslation(), matrix:GetAngles())
        WorldModel:SetPos(newPos)
        WorldModel:SetAngles(newAng)
        WorldModel:SetupBones()
    else
        WorldModel:SetPos(self:GetPos())
        WorldModel:SetAngles(self:GetAngles())
    end
    WorldModel:DrawModel()
end

-- -------------------------------------------------------
-- Hold type helpers
-- -------------------------------------------------------
function SWEP:SetHold(value)
    self:SetWeaponHoldType(value)
    self:SetHoldType(value)
    self.holdtype = value
end

function SWEP:Think()
    self:SetHold(self.HoldType)
end

-- -------------------------------------------------------
-- Initialize
-- -------------------------------------------------------
function SWEP:Initialize()
    self:SetHold(self.HoldType)
    self.Opened = false
end

-- -------------------------------------------------------
-- HUD (client, intentionally blank)
-- -------------------------------------------------------
if CLIENT then
    function SWEP:DrawHUD() end
end

-- -------------------------------------------------------
-- Network strings
-- -------------------------------------------------------
if SERVER then
    util.AddNetworkString("WeaponCaseOpened")
end

-- -------------------------------------------------------
-- Primary Attack: open the case
-- -------------------------------------------------------
function SWEP:PrimaryAttack()
    if self.CD and self.CD > CurTime() then return end
    self.CD = CurTime() + 1.5

    if SERVER then
        if self.Opened then return end
        self.Opened = true

        local ply = self:GetOwner()
        if not IsValid(ply) then return end

        -- Pick a random reward from the table
        local reward = self.CaseContents[math.random(#self.CaseContents)]

        -- Give the weapon if the player doesn't already have it
        if not ply:HasWeapon(reward.Weapon) then
            ply:Give(reward.Weapon)
        end

        -- Auto-detect ammo type and default clip size from the weapon entity
        local ammoType  = ""
        local ammoCount = 0
        local wepEnt = ply:GetWeapon(reward.Weapon)
        if IsValid(wepEnt) then
            -- Primary ammo first, fall back to secondary
            local primaryAmmo = wepEnt.Primary and wepEnt.Primary.Ammo
            local secondaryAmmo = wepEnt.Secondary and wepEnt.Secondary.Ammo

            if primaryAmmo and primaryAmmo ~= "none" and primaryAmmo ~= "" then
                ammoType = primaryAmmo
                ammoCount = (wepEnt.Primary.DefaultClip or wepEnt.Primary.ClipSize or 30)
            elseif secondaryAmmo and secondaryAmmo ~= "none" and secondaryAmmo ~= "" then
                ammoType = secondaryAmmo
                ammoCount = (wepEnt.Secondary.DefaultClip or wepEnt.Secondary.ClipSize or 30)
            end

            -- Multiply by AmmoBonus extra clips on top
            ammoCount = ammoCount * (1 + (self.AmmoBonus or 2))
        end

        -- Give the ammo if we found a valid type
        if ammoType ~= "" then
            ply:GiveAmmo(ammoCount, ammoType, false)
        end

        -- Play open sound
        self:EmitSound("physics/cardboard/cardboard_box_impact_hard" .. math.random(1, 3) .. ".wav")

        -- Notify the client so it can show a message
        net.Start("WeaponCaseOpened")
            net.WriteString(reward.Weapon)
            net.WriteString(ammoType)
            net.WriteInt(ammoCount, 16)
        net.Send(ply)

        -- Drop the case as a physics prop at the player's feet, then remove the SWEP
        local dropPos = ply:GetPos() + Vector(0, 0, 10)
        local dropAng = ply:GetAngles()

        local prop = ents.Create("prop_physics")
        if IsValid(prop) then
            prop:SetModel(self.WorldModel)
            prop:SetPos(dropPos)
            prop:SetAngles(dropAng)
            prop:Spawn()
            prop:Activate()

            -- Give it a small forward toss
            local phys = prop:GetPhysicsObject()
            if IsValid(phys) then
                phys:ApplyForceCenter(ply:GetForward() * 200 + Vector(0, 0, 120))
            end

            -- Auto-remove the dropped prop after 30 seconds so it doesn't clutter the map
            timer.Simple(30, function()
                if IsValid(prop) then prop:Remove() end
            end)
        end

        -- Remove the weapon from the player's inventory
        ply:StripWeapon(self:GetClass())
    end
end

-- -------------------------------------------------------
-- Client: show a notification when the case is opened
-- -------------------------------------------------------
if CLIENT then
    net.Receive("WeaponCaseOpened", function()
        local wepClass  = net.ReadString()
        local ammoType  = net.ReadString()
        local ammoCount = net.ReadInt(16)

        notification.AddLegacy(
            "Case opened! Got: " .. wepClass .. " + " .. ammoCount .. "x " .. ammoType,
            NOTIFY_GENERIC,
            5
        )
        surface.PlaySound("buttons/button14.wav")
    end)
end

-- -------------------------------------------------------
-- Secondary Attack & Reload: unused
-- -------------------------------------------------------
function SWEP:SecondaryAttack() end
function SWEP:Reload() end