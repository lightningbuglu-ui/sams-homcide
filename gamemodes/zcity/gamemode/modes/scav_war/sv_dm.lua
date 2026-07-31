local MODE = MODE

MODE.name = "scavenger_war"
MODE.PrintName = "Scavenger War"

MODE.LootSpawn = false
MODE.GuiltDisabled = true
MODE.randomSpawns = true
MODE.ForBigMaps = false
MODE.Chance = 0.04

util.AddNetworkString("scavenger_war_start")
util.AddNetworkString("scavenger_war_end")

resource.AddFile("sound/scav_war_Start.mp3")
resource.AddFile("sound/scav_war_middle.mp3")
resource.AddFile("sound/scav_war_end.mp3")

function MODE:CanLaunch()
	return true
end

function MODE:Intermission()
	game.CleanUpMap()

	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end

		ApplyAppearance(ply)
		ply:SetupTeam(0)
	end

	net.Start("scavenger_war_start")
	net.Broadcast()
end

function MODE:CheckAlivePlayers()
	local AlivePlyTbl = {}

	for _, ply in player.Iterator() do
		if not ply:Alive() then continue end
		if ply.organism and ply.organism.incapacitated then continue end

		AlivePlyTbl[#AlivePlyTbl + 1] = ply
	end

	return AlivePlyTbl
end

function MODE:ShouldRoundEnd()
	return (#zb:CheckAlive(true) <= 1)
end

local primaryWeapons = {
	{weapon = "weapon_akmwreked",        ammo = 3},
	{weapon = "weapon_vz58",             ammo = 3},
	{weapon = "weapon_mini14ranchrifle", ammo = 3},
	{weapon = "weapon_mat49",            ammo = 3},
	{weapon = "weapon_owen",             ammo = 3},
	{weapon = "weapon_remington870",     ammo = 3},
	{weapon = "weapon_skstoz_eft",       ammo = 4},
	{weapon = "weapon_sv98_eft",         ammo = 4},
	{weapon = "weapon_mosin",            ammo = 4},
	{weapon = "weapon_ar15",             ammo = 3},
	{weapon = "weapon_izh18",            ammo = 3},
	{weapon = "weapon_asval_eft",        ammo = 3},
	{weapon = "weapon_g3a3",             ammo = 3},
	{weapon = "weapon_toz106",           ammo = 3},
}

local secondaryWeapons = {
	{weapon = "weapon_glock17",      ammo = 3},
	{weapon = "weapon_cz75",         ammo = 3},
	{weapon = "weapon_px4beretta",   ammo = 2},
	{weapon = "weapon_apsss",        ammo = 2},
	{weapon = "weapon_tokarev",      ammo = 2},
	{weapon = "weapon_revolversh12", ammo = 2},
	{weapon = "weapon_makarov",      ammo = 2},
}

local randomArmor = {
	{"vest1", "helmet1"},
	{"vest3", "helmet1"},
	{"ent_armor_vest18", "ent_armor_helmet20"},
}

local randomGrenades = {
	"weapon_hg_rgd_tpik",
	"weapon_hg_pipebomb_tpik",
	"weapon_hg_smokenade_tpik",
	"weapon_hg_flashbang_tpik",
}

local randomMedicine = {
	"weapon_bandage_sh",
	"weapon_bigbandage_sh",
	"weapon_medkit_sh",
	"weapon_fentanyl",
	"weapon_morphine",
	"weapon_adrenaline",
	"weapon_tourniquet",
}

local randomMelees = {
	"weapon_melee",
	"weapon_pocketknife",
	"weapon_buck200knife",
	"weapon_sogknife",
}

function MODE:RoundStart()

	for _, ply in player.Iterator() do
		if not ply:Alive() then continue end

		local primary   = table.Random(primaryWeapons)
		local secondary = table.Random(secondaryWeapons)
		local armor     = table.Random(randomArmor)

		ply:StripWeapons()

		ply:SetSuppressPickupNotices(true)
		ply.noSound = true

		ply:Give("weapon_hands_sh")

		local inv = ply:GetNetVar("Inventory")

		if inv and inv["Weapons"] then
			inv["Weapons"]["hg_sling"] = true
			ply:SetNetVar("Inventory", inv)
		end

		local gun = ply:Give(primary.weapon)

		if IsValid(gun) then
			ply:GiveAmmo(
				gun:GetMaxClip1() * primary.ammo,
				gun:GetPrimaryAmmoType(),
				true
			)
		end

		local pistol = ply:Give(secondary.weapon)

		if IsValid(pistol) then
			ply:GiveAmmo(
				pistol:GetMaxClip1() * secondary.ammo,
				pistol:GetPrimaryAmmoType(),
				true
			)
		end

		hg.AddArmor(ply, armor)

		ply:Give(table.Random(randomMelees))

		local grenadeCount = math.random(1, 2)

		for i = 1, grenadeCount do
			ply:Give(table.Random(randomGrenades))
		end

		for i = 1, math.random(1, 2) do
			ply:Give(table.Random(randomMedicine))
		end

		ply:Give("weapon_walkie_talkie")

		ply:SelectWeapon("weapon_hands_sh")

		if ply.organism then
			ply.organism.recoilmul = 0.5
		end

		timer.Simple(0.1, function()
			if IsValid(ply) then
				ply.noSound = false
				ply:SetSuppressPickupNotices(false)
			end
		end)

		zb.GiveRole(ply, "Scav", Color(120, 170, 120))
	end
end

function MODE:GiveWeapons()
end

function MODE:GiveEquipment()
end

function MODE:RoundThink()
end

function MODE:PlayerDeath(ply)
	if zb.ROUND_STATE == 1 then
		ply:GiveSkill(-0.1)
	end
end

function MODE:CanSpawn()
end

function MODE:EndRound()

	timer.Simple(2, function()

		local winner = zb:CheckAlive(true)[1]

		if IsValid(winner) then
			winner:GiveExp(math.random(150,200))
			winner:GiveSkill(math.Rand(0.2,0.3))
		end

		net.Start("scavenger_war_end")
			net.WriteEntity(IsValid(winner) and winner or NULL)
		net.Broadcast()

	end)
end
