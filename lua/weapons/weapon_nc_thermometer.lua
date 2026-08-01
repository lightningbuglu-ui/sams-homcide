if SERVER then AddCSLuaFile() end
-- Based directly on weapon_bandage_sh (same base weapon_painkillers.lua uses) rather than on
-- weapon_painkillers itself -- this item doesn't administer a dose or consume anything, so the
-- painkiller-specific Animation()/Think() holding-bar logic doesn't apply here and is skipped.
SWEP.Base = "weapon_bandage_sh"
SWEP.PrintName = "Non-Contact Thermometer"
SWEP.Instructions = "Aim and press LMB to check your own temperature, or RMB to check someone else's. Reading is printed to chat."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
-- TODO: "pistol" is a guess at a valid SetHold pose for a gun-shaped scanner -- verify against
-- whatever hold types this framework's animation system actually supports (weapon_painkillers
-- used "slam", which was tailored to a pill bottle and wouldn't suit this model).
SWEP.HoldType = "pistol"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/nc_thermometer.mdl"
if CLIENT then
	SWEP.WepSelectIcon = Material("sams-weapon-pictures/non-contact-thermometer.png")
	SWEP.IconOverride = "sams-weapon-pictures/non-contact-thermometer.png"
	SWEP.BounceWeaponIcon = false
end
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Slot = 3
SWEP.SlotPos = 3
SWEP.WorkWithFake = true
-- TODO: painkillers' hand offset was tuned for a small pill bottle; a thermometer gun will
-- likely sit differently in-hand. Adjust after testing in-game.
SWEP.offsetVec = Vector(2.5, -2, -2)
SWEP.offsetAng = Angle(-8, 180, 180)
SWEP.modeNames = {
	[1] = "thermometer"
}

function SWEP:InitializeAdd()
	self:SetHold(self.HoldType)

	-- No dosing/consumption involved -- kept only in case something upstream in
	-- weapon_bandage_sh expects self.modeValues to exist.
	self.modeValues = {
		[1] = 1
	}
end

SWEP.modeValuesdef = {
	[1] = 1,
}

SWEP.CheckSnd = "sams-weapon-sounds/nc_thermometer-beep.mp3"

SWEP.showstats = false

-- This is a reusable tool, not a consumable -- unlike weapon_painkillers, OwnerChanged()
-- should NOT auto-administer anything if an NPC ends up holding it.
function SWEP:OwnerChanged()
end

-- Strips out weapon_bandage_sh's default hold animation -- it was tailored to a
-- bandage/pill item and looked wrong on the thermometer model.
function SWEP:Animation()
end

if SERVER then
	function SWEP:Heal(ent, mode)
		if not IsValid(ent) or not ent.organism then return end

		local owner = self:GetOwner()
		if not IsValid(owner) then return end

		-- Cooldown so it can't be spammed for constant readings -- adjust the 2
		-- to taste if you want it faster/slower.
		self.NextCheck = self.NextCheck or 0
		if self.NextCheck > CurTime() then return end
		self.NextCheck = CurTime() + 2

		local org = ent.organism
		local temp = org.temperature or 36.7

		local subject
		if ent == owner then
			subject = "Your"
		elseif ent:IsPlayer() then
			subject = ent:Nick() .. "'s"
		else
			subject = "Their"
		end

		owner:ChatPrint(string.format("[Thermometer] %s temperature: %.1f°C", subject, temp))
		owner:EmitSound(self.CheckSnd, 60, 100)

		-- Not consumed -- deliberately no self:Remove()/owner:SelectWeapon() like
		-- weapon_painkillers.lua does, since this is a reusable device, not a dose.
		return true
	end
end