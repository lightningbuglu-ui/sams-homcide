if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_melee"
SWEP.PrintName = "barbed wire bat"
SWEP.Instructions = "a bat covered in barbed wire.\n\nLMB to attack.\nRMB to block."
SWEP.Category = "Weapons - Melee"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.HoldType = "slam"
SWEP.WorldModel = "models/hatedmekkr/boneworks/weapons/melee/blunts/clubs/bw_wpn_clb_barbed.mdl"
SWEP.WorldModelReal = "models/weapons/tfa_nmrih/v_me_bat_metal.mdl"
SWEP.WorldModelExchange = "models/hatedmekkr/boneworks/weapons/melee/blunts/clubs/bw_wpn_clb_barbed.mdl"
SWEP.DontChangeDropped = false
SWEP.ViewModel = ""
SWEP.modelscale = 1
SWEP.basebone = 94
SWEP.Weight = 0
SWEP.weight = 1

if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_baseballbat")
	SWEP.IconOverride = "vgui/wep_jack_hmcd_baseballbat"
	SWEP.BounceWeaponIcon = false
end

-- Combined blunt + slash damage (barbed wire wrapped bat)
SWEP.DamageType = bit.bor(DMG_CLUB, DMG_SLASH)

SWEP.DamagePrimary = 25
SWEP.DamageSecondary = 10
SWEP.PenetrationPrimary = 4
SWEP.PenetrationSecondary = 6
SWEP.MaxPenLen = 2
SWEP.PenetrationSizePrimary = 3
SWEP.PenetrationSizeSecondary = 1.5
SWEP.StaminaPrimary = 20
SWEP.StaminaSecondary = 10

SWEP.HoldPos = Vector(-7, 0, 0)
SWEP.HoldAng = Angle(0, 0, -10)

SWEP.AttackTime = 0.27
SWEP.AnimTime1 = 1.3
SWEP.WaitTime1 = 0.95
SWEP.AttackLen1 = 65
SWEP.ViewPunch1 = Angle(2, 4, 0)

SWEP.Attack2Time = 0.3
SWEP.AnimTime2 = 1
SWEP.WaitTime2 = 0.8
SWEP.AttackLen2 = 40
SWEP.ViewPunch2 = Angle(0, 0, -2)

SWEP.attack_ang = Angle(0, 0, 0)
SWEP.sprint_ang = Angle(15, 0, 0)
SWEP.basebone = 94
SWEP.weaponPos = Vector(6.5, 0.2, -1)
SWEP.weaponAng = Angle(-79, 5, -4)

SWEP.AnimList = {
	["idle"] = "Idle",
	["deploy"] = "Draw",
	["attack"] = "Attack_Quick",
	["attack2"] = "Shove",
}

SWEP.setlh = true
SWEP.setrh = true
SWEP.TwoHanded = true

SWEP.AttackHit = "physics/wood/wood_plank_impact_hard1.wav"
SWEP.Attack2Hit = "physics/wood/wood_plank_impact_hard1.wav"
SWEP.AttackHitFlesh = "Flesh.ImpactHard"
SWEP.Attack2HitFlesh = "Flesh.ImpactHard"
SWEP.DeploySnd = "physics/wood/wood_plank_impact_soft2.wav"

SWEP.AttackPos = Vector(0, 0, 0)
SWEP.NoHolster = true
SWEP.BreakBoneMul = 0.5
SWEP.PainMultiplier = 0.85
SWEP.AttackTimeLength = 0.2
SWEP.Attack2TimeLength = 0.001
SWEP.AttackRads = 120
SWEP.AttackRads2 = 0
SWEP.SwingAng = -5
SWEP.SwingAng2 = 0
SWEP.MinSensivity = 0.6