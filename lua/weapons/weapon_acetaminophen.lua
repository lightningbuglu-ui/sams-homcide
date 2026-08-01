if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_painkillers"
SWEP.PrintName = "Acetaminophen"
SWEP.Instructions = "Over-the-counter pain reliever. Weaker than prescription painkillers, but easier to come by. RMB to use on someone else."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.HoldType = "slam"
SWEP.ViewModel = ""
-- TODO: swap for a proper acetaminophen/tylenol-bottle model if one exists in your addon's assets;
-- reusing the painkillers pill model as a placeholder for now.
SWEP.WorldModel = "models/bloocobalt/l4d/items/w_eq_pills.mdl"
if CLIENT then
	-- Matches materials/sams-weapon-pictures/acetaminophen.png in sams-homcide-content.
	SWEP.WepSelectIcon = Material("sams-weapon-pictures/acetaminophen.png")
	SWEP.IconOverride = "sams-weapon-pictures/acetaminophen.png"
	SWEP.BounceWeaponIcon = false
end
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Slot = 3
SWEP.SlotPos = 2
SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(2.5, -2.5, 0)
SWEP.offsetAng = Angle(-30, 20, 180)
SWEP.modeNames = {
	[1] = "acetaminophen"
}

function SWEP:InitializeAdd()
	self:SetHold(self.HoldType)

	self.modeValues = {
		[1] = 0.5
	}
end


SWEP.modeValuesdef = {
	[1] = 0.5,
}

SWEP.DeploySnd = "snd_jack_hmcd_pillsbounce.wav"
SWEP.FallSnd = "snd_jack_hmcd_pillsbounce.wav"

SWEP.showstats = false

-- Think(), Animation(), and OwnerChanged() are all inherited from weapon_painkillers
-- via SWEP.Base, so they don't need to be redefined here.
--
-- Heal() is overridden below: it layers fever reduction on top of the base painkiller
-- behavior (which reads self.modeValues[1] -- 0.5 here vs 1 on the base item -- to
-- determine how much org.analgesiaAdd is granted per dose).
if SERVER then
	function SWEP:Heal(ent, mode)
		-- Call the base painkiller Heal() first and check its result -- it can
		-- no-op (e.g. still charging up hg_healanims holding, or one of its
		-- early-return guard checks), and we only want to apply fever reduction
		-- once a dose has actually landed, not on every call.
		local applied = self.BaseClass.Heal(self, ent, mode)

		if applied then
			local org = ent.organism
			if org and org.temperature and org.temperature > 36.7 then
				-- Only brings fever down toward baseline -- math.Approach won't push
				-- it below 36.7, so this never induces hypothermia.
				org.temperature = math.Approach(org.temperature, 36.7, 0.3)
			end
		end

		return applied
	end
end