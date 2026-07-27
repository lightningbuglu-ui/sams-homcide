local max, min, Round, Lerp, halfValue2 = math.max, math.min, math.Round, Lerp, util.halfValue2
--local Organism = hg.organism
hg.organism.module.lungs = {}
local module = hg.organism.module.lungs
module[1] = function(org)
	org.lungsL = {
		0, --состояние,пневмотаракс
		0
	}

	org.lungsR = {0, 0}
	org.trachea = 0
	org.pneumothorax = 0
	org.needle = 0
	org.nextCough = nil
	org.o2 = {
		range = 30,
		regen = 4,
		k = 0.5,
	}

	org.lungsfunction = true

	org.o2.curregen = org.o2.regen
	
	org.o2[1] = org.o2.range
	org.CO = 0
	org.COregen = 0
	org.lastCOBreathe = nil

	org.mannitol = 0

	org.underwaterTime = 0
	org.waterInLungs = 0
	org.pulmonaryedema = 0
	org.waterVomitCount = 0
	org.lastInWaterTime = 0
end

function hg.organism.OxygenateBlood(org)
	return (math.max(((1 - org.lungsL[1]) + (1 - org.lungsR[1])) / 2, 0.5) * (1 - org.trachea)) * org.o2.regen / 4 * (org.owner:WaterLevel() < 3 and 1 or 0)// * (1 - org.pneumothorax)
end

function hg.organism.CanBreath(org)
	return org.o2 and org.o2.curregen >= org.losing_oxy
end

local function insta_send_holdingbreath(org)
	net.Start("organism_send") // отправляем только дизориентацию (чтобы не нагружать нет), и сразу
	
	local tbl = {}
	tbl.holdingbreath = org.holdingbreath
	tbl.owner = org.owner

	net.WriteTable(tbl)
	net.WriteBool(true)
	net.WriteBool(false)
	net.WriteBool(false)
	net.WriteBool(true) // вот эта шняга отвечает за то чтобы оно просто мерджнуло и всё
	net.Send(org.owner)
end

local function togglebreath(ply, toggle)
	local org = ply.organism
	
	if isbool(toggle) then
		if toggle then
			if not ply.organism.holdingbreath then
				ply.organism.holdingbreath = true
				ply:EmitSound(ThatPlyIsFemale(ply) and "breathing/inhale/female/inhale_0"..math.random(5)..".wav" or "breathing/inhale/male/inhale_0"..math.random(4)..".wav",65)	
				insta_send_holdingbreath(ply.organism)
			end
		else
			if ply.organism.holdingbreath then
				ply:EmitSound(ThatPlyIsFemale(ply) and "breathing/exhale/female/exhale_0"..math.random(5)..".wav" or "breathing/exhale/male/exhale_0"..math.random(5)..".wav",65)
				ply.organism.holdingbreath = false
				ply.releasebreathe = nil
				insta_send_holdingbreath(ply.organism)
			end
		end
	else
		if ply.organism.holdingbreath then
			ply:EmitSound(ThatPlyIsFemale(ply) and "breathing/exhale/female/exhale_0"..math.random(5)..".wav" or "breathing/exhale/male/exhale_0"..math.random(5)..".wav",65)
			ply.organism.holdingbreath = false
			ply.releasebreathe = nil
			insta_send_holdingbreath(ply.organism)
		else
			ply.organism.holdingbreath = true
			ply:EmitSound(ThatPlyIsFemale(ply) and "breathing/inhale/female/inhale_0"..math.random(5)..".wav" or "breathing/inhale/male/inhale_0"..math.random(4)..".wav",65)	
			insta_send_holdingbreath(ply.organism)
		end
	end

	local ent = hg.GetCurrentCharacter(ply)
	ent:StopSound(ply.lastPhr or "")
	ply.phrCld = 0
end

concommand.Add("hmcd_holdbreath",function(ply)
	if not ply.organism then return end
	if not ply:Alive() then return end
	if ply.organism.stamina[1] < 90 then return end
	if ply.organism.o2.curregen == 0 then return end

	if (ply.cooldownbreathe or 0) > CurTime() then return end
	ply.cooldownbreathe = CurTime() + 0.5

	togglebreath(ply)
end)

concommand.Add("+hmcd_holdbreath",function(ply)
	if not ply.organism then return end
	if not ply:Alive() then return end
	if ply.organism.stamina[1] < 90 then return end
	if ply.organism.o2.curregen == 0 then return end

	if (ply.cooldownbreathe or 0) > CurTime() then return end
	ply.cooldownbreathe = CurTime() + 0.5

	togglebreath(ply,true)
end)

concommand.Add("-hmcd_holdbreath",function(ply)
	if not ply.organism then return end
	if ply.organism.stamina[1] < 90 then return end
	if ply.organism.o2.curregen == 0 then return end

	if (ply.cooldownbreathe or 0) > CurTime() then ply.releasebreathe = ply.cooldownbreathe return end

	togglebreath(ply,false)
end)

local lowoxy = {
	"I'm gonna faint right now... There's not enough oxygen.",
	"There's not enough oxygen... I can't hold much longer...",
	"I really need some fresh air...",
	"I'm gasping for air...",
	"Need to breathe air... or I'm gonna faint right here..."
}

local not_enough_intake = {
	//"I have to breathe...",
	//"I gotta take a break...",
	//"Need a break from this... to breathe...",
	//"Resting sounds like a nice idea.",
	"I need to breathe...",
	"I'm struggling to breathe...",
}

local drop_mask = {
	"I can't breathe in this mask... I need to take it off.",
	"Drop the mask, it's not worth it...",
	"It's fucking disgusting... and I surely can't breathe in this...",
	"Fucking stinks... Gotta take this mask off...",
}

local drugged = {
	"Ohhh hohoohoooo Ie-like it.....",
	"Fukkenh awesomee..... ffffeeelin gooooood..",
	"That's theh sStuffff DUDeeee",
	"I reallly like whatEvER I'm feeling right now....",
	"Oh yeahhhh this feels gooood!",
	"I want to feel likhe this for theRRRREST of my life",
	"Why am I here even?.. wWhatever whuhhh heh",
	"Whoa re you? Gett outtaheree...",
	"Don't want anything else... this is pERRRfect!..",
}

local bit_band,util_PointContents = bit.band,util.PointContents

-- Returns true if the ragdolled body is lying chest-down (face/torso pressed
-- into the ground), as opposed to on its back or on a side.
-- Uses the spine bone's Up vector: when lying face-down, Up points mostly
-- downward (negative Z).
local function IsProneOnChest(owner)
	local ent = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or nil
	if not IsValid(ent) then return false end

	local bone = ent:LookupBone("ValveBiped.Bip01_Spine2")
	if not bone then return false end

	local mat = ent:GetBoneMatrix(bone)
	if not mat then return false end

	local up = mat:GetAngles():Up()

	return up[3] < -0.3
end

local chestdown_phrases = {
	"I can't breathe like this...",
	"I need to roll over...",
	"I Can't breathe... lying like this...",
}

local water_cough_phrases = {
	"Fuck i think i just swallowed water...",
	"I think i just swallowed water...",
	"I think just inhaled water...,"
}

local water_vomit_phrases = {
	"Im light headed",
	"Oh god, I'm gonna throw up...",
	"I feel sick",
}

-- Secondary drowning / pulmonary edema symptom phrases. These scale with
-- org.pulmonaryedema, a hidden 0.1-1 severity meter -- higher severity means
-- more (and worse) symptoms firing.
local edema_dyspnea_phrases = {
	"I'm short of breath...",
	"I can't catch my breath...",
	"Breathing's harder then before...",
}

local edema_cough_phrases = {
	"Am i coughing up blood?",
	"My cough's got this pink froth in it...",
	"There's blood coming up...",
}

local edema_orthopnea_phrases = {
	"I need to sit up, I can't breathe lying down like this...",
	"Lying flat makes this so much worse...",
	"I have to stay upright...",
}

local edema_chestpain_phrases = {
	"Theres a sharp pain in my chest every time i breath...",
	"My chest feels so tight, like something's crushing it...",
	"Every deep breath stabs like hell...",
}

local edema_sounds_phrases = {
	"I hear this bubbly, crackling sound when I breathe in...",
	"There's a wheeze in my chest with every breath...",
	"Something's crackling in my lungs...",
}

local edema_tachycardia_phrases = {
	"My heart's racing",
	"I can feel my heart pounding out of my chest...",
	"Why is my heart beating so damn fast...",
}

local edema_sweat_phrases = {
	"I'm sweating like hell for no reason...",
	"I'm drenched in sweat why I can't stop...",
	"Why won't I stop sweating...",
}

local edema_anxiety_phrases = {
	"I can't shake this panic, I need air...",
	"I feel so restless...",
	"Something's wrong, I can't calm down...",
}

local edema_dizzy_phrases = {
	"Is it me or is the world spinning...",
	"I feel so lightheaded...",
	"I'm dizzy, I can barely stand straight...",
}

-- Notification keys tied to breathing trouble. Every one of these is shown
-- as a one-shot ("play once, don't spam") and reset together whenever the
-- underlying struggle ends -- e.g. the player wakes back up, stands back up,
-- or otherwise stops suffocating.
local suffocation_notify_keys = {
	"take_gasmask", "take_gasmask2", "oxygen_lowintake", "lowoxy", "lowoxy2",
	"chestdown", "watercough", "watervomit", "watervomitlimit", "waterchoking",
}

local function ResetSuffocationNotifications(owner)
	if not IsValid(owner) then return end
	if not owner.IsPlayer or not owner:IsPlayer() then return end
	for i = 1, #suffocation_notify_keys do
		owner:ResetNotification(suffocation_notify_keys[i])
	end
end

hg.organism.ResetSuffocationNotifications = ResetSuffocationNotifications

-- Getting back up / waking up should always give the player a clean slate
-- so old suffocation warnings don't linger or refuse to fire again.
hook.Add("HG_OnWakeOtrub", "hg_lungs_reset_suffocation", function(owner)
	ResetSuffocationNotifications(owner)
end)

hook.Add("FakeUp", "hg_lungs_reset_suffocation", function(ply)
	ResetSuffocationNotifications(ply)
end)

local color_white, color_red, color_red2, color_red3 = Color(255, 255, 255), Color(255, 0, 0), Color(200, 55, 55), Color(255, 100, 100)
module[2] = function(owner, org, timeValue)
	local o2 = org.o2
	local losing_oxy = timeValue * 1 * math.Clamp(org.o2[1] / 30, 0.25, 1)
	org.losing_oxy = losing_oxy
	o2[1] = max(o2[1] - losing_oxy, 0)
	local ent = hg.GetCurrentCharacter(owner)
	local bone = ent:LookupBone("ValveBiped.Bip01_Head1")

	if (not bone) or (bone < 0) then bone = 6 end

	local head = ent:GetBonePosition(bone)
	
	if not head then
		head = ent:GetBonePosition(0)
	end

	if org.o2.curregen == 0 and org.holdingbreath then
		togglebreath(owner, false)
	end

	if org.holdingbreath then
		//org.stamina[1] = max(org.stamina[1] - timeValue * 15,0)
		if org.stamina[1] < 90 or org.o2[1] <= 10 then
			togglebreath(owner, false)
		end
		
		if owner.releasebreathe and owner.releasebreathe < CurTime() then
			togglebreath(owner, false)
			owner.releasebreathe = nil
		end
	end

	if not head then head = owner:GetPos() end
	
	local inwater = bit_band(util_PointContents(head),CONTENTS_WATER) == CONTENTS_WATER

	-- Drowning: the longer the player stays underwater without breathing,
	-- the more water works its way into the lungs. Small amounts just make
	-- them cough it back up; too much and they'll vomit it out instead.
	local reallyunderwater = inwater and not org.holdingbreath and org.o2.curregen == 0
	if reallyunderwater then
		org.underwaterTime = (org.underwaterTime or 0) + timeValue
	else
		org.underwaterTime = max((org.underwaterTime or 0) - timeValue * 2, 0)
	end

	local drown_grace = 15 -- seconds of struggling underwater before water starts getting into the lungs
	if org.underwaterTime > drown_grace then
		org.waterInLungs = min((org.waterInLungs or 0) + (org.underwaterTime - drown_grace) * timeValue * 0.4, 20)
	else
		org.waterInLungs = max((org.waterInLungs or 0) - timeValue, 0)
	end

	if inwater then
		org.lastInWaterTime = CurTime()
	end

	-- You can't throw water up the instant you climb out, and your body can
	-- only manage to fully clear it out so many times before it just can't
	-- get the rest -- after that, whatever's left just stays put.
	local surface_delay = 12 -- seconds fully out of the water before you can vomit it up
	local max_water_vomits = 2
	local canVomitWater = (not inwater) and (CurTime() - (org.lastInWaterTime or 0) > surface_delay) and (org.waterVomitCount or 0) < max_water_vomits

	if org.isPly and org.waterInLungs > 0 and org.alive then
		if org.waterInLungs < 12 or not canVomitWater then
			-- Either a manageable amount, or too much but they can't get it
			-- out right now (still too soon after surfacing, or they're out
			-- of vomits) -- coughing gets more frequent the fuller the lungs.
			if not org.nextWaterCough or org.nextWaterCough < CurTime() then
				org.nextWaterCough = CurTime() + (org.waterInLungs >= 12 and math.random(2, 4) or math.random(4, 9))
				owner:EmitSound(ThatPlyIsFemale(owner) and "breathing/female_cough1.mp3" or "homigrad/player/male/male_cough"..math.random(5)..".wav", 60)
				owner:Notify(water_cough_phrases[math.random(#water_cough_phrases)], true, "watercough", 0)
			end

			if org.waterInLungs >= 12 and (org.waterVomitCount or 0) >= max_water_vomits then
				owner:Notify("I can't get all of this water out of me anymore...", true, "watervomitlimit", 0)
			end
		else
			-- surfaced, waited it out, and still have it in them: throw it up
			owner:Notify(water_vomit_phrases[math.random(#water_vomit_phrases)], true, "watervomit", 0)
			owner:EmitSound("vomit/vomit5.mp3")
			org.waterInLungs = 0
			org.underwaterTime = drown_grace * 0.5 -- partial relief, doesn't fully reset the clock
			org.waterVomitCount = (org.waterVomitCount or 0) + 1
			owner:ResetNotification("watercough")
		end
	end

	if org.isPly and org.waterInLungs <= 0 then
		owner:ResetNotification("watercough")
		owner:ResetNotification("watervomit")
		owner:ResetNotification("watervomitlimit")
	end

	-- Secondary drowning / pulmonary edema: repeated water aspiration leaves
	-- lingering lung damage that doesn't just vanish once the water's out.
	-- Hidden severity meter, 0 = never happened, 0.1 (mild) up to 1 (severe).
	-- Heals very slowly over time once the player stops aspirating water.
	if org.waterInLungs > 0 then
		org.pulmonaryedema = min(max(org.pulmonaryedema, 0.1) + timeValue * (org.waterInLungs / 20) * 0.015, 1)
	else
		org.pulmonaryedema = max(org.pulmonaryedema - timeValue / 900, 0) -- ~15 minutes to fully clear
	end
	-- test
	local success = owner:IsBerserk() or (not org.heartstop and org.alive and not (org.brain >= 0.4 and math.random(10 - (org.brain * 10)) < 4) and org.lungsfunction)
	if success and owner:IsPlayer() and inwater then success = false end
	-- Lungs completely full of water: physically can't draw a breath at all
	-- until they cough/vomit some of it back out.
	if success and org.waterInLungs >= 19.9 then
		success = false
		if org.isPly then
			owner:Notify("I can't breathe, my lungs are full of water!", true, "waterchoking", 0)
		end
	elseif org.isPly then
		owner:ResetNotification("waterchoking")
	end
	if success and org.choking then org.needfake = true success = false end
	if success and org.vomitInThroat then success = false end
	org.choking = false
	local pneumothorax = (org.lungsR[2] == 1 or org.lungsL[2] == 1) and org.needle == 0
	
	org.needle = math.Approach(org.needle, 0, timeValue / 1200)

	org.pneumothorax = pneumothorax and min(org.pneumothorax + timeValue / 180 * (org.lungsL[2] + org.lungsR[2]), (org.lungsL[2] + org.lungsR[2]) / 2) or max(org.pneumothorax - timeValue / 10, 0)
	
	if org.lastCOBreathe and org.lastCOBreathe + 1 > CurTime() then
		org.COregen = math.Approach(org.COregen, 30, timeValue * 1)
	else
		org.COregen = math.Approach(org.COregen, 0, timeValue * 0.5)
	end

	org.CO = max(org.CO - timeValue, 0)

	-- Being ragdolled chest-down (as opposed to on the back or a side)
	-- compresses the torso against the ground and makes it harder to draw
	-- breath in properly.
	org.proneonchest = IsProneOnChest(owner)
	local chestdownMul = org.proneonchest and 0.35 or 1
	local waterInLungsMul = 1 - math.Clamp((org.waterInLungs or 0) / 20, 0, 0.6)

	-- Pulmonary edema (secondary drowning) penalties -- these compound with
	-- each other so the sicker the player is, the worse it gets:
	--  * baseline dyspnea, always present once edema > 0
	--  * extra penalty while exerting themselves (worsens with activity)
	--  * extra penalty while lying down / ragdolled (orthopnea, severity 0.5+)
	local edema = org.pulmonaryedema or 0
	local edemaBaseMul = 1 - edema * 0.4
	local edemaExertionMul = 1 - edema * math.Clamp(org.stamina and org.stamina.sub or 0, 0, 1) * 0.4
	local edemaOrthopneaMul = (edema >= 0.5 and IsValid(owner.FakeRagdoll)) and (1 - (edema - 0.5)) or 1

	if success then
		local oxygenate = hg.organism.OxygenateBlood(org) * 0.5
		local lerp = min(max(org.pulse - 20, 0) / 20, 1)
		local regen = Lerp(lerp, 0, o2.regen * oxygenate * math.Rand(0.95, 1.05))

		org.CO = min(org.CO + (org.COregen > 0 and timeValue * 1.5 or 0), 30)

		org.consciousness = math.min(org.consciousness, (30 - org.CO) / 30)

		local mask_blevota = owner:GetNetVar("zableval_masku", false)

		local sprayed = org.is_sprayed_at
		org.is_sprayed_at = nil

		local regenerate = regen * timeValue * 4 * (org.stamina[1] / org.stamina.max) * (mask_blevota and 0 or 1) * ((org.temperature > 38) and math.Clamp(math.Remap(org.temperature, 38, 41, 1, 0.1), 0.1, 1) or 1) * chestdownMul * waterInLungsMul * edemaBaseMul * edemaExertionMul * edemaOrthopneaMul
		o2[1] = min(o2[1] + regenerate * math.Clamp(org.o2[1] / 30, 0.25, 1) * (org.holdingbreath and 0 or 1) * (sprayed and 0 or 1) * min((10 / max(org.CO,1)),1), o2.range * math.max(1 - org.pneumothorax * org.pneumothorax, 0.1) * math.min(org.blood / 4500, 1) * math.max(1 - (org.lungsL[1] + org.lungsR[1]) / 2, 0.5) * math.max(1 - edema * 0.5, 0.4))

		o2.curregen = regenerate

		o2[1] = max(o2[1] - (org.CO > 0 and o2.curregen * 1.1 * (org.CO / 30) or 0),0)

		//org.owner:ResetNotification("oxygen_cantbreathe")
		//org.owner:ResetNotification("oxygen_cantbreathe2")
	else
		o2.curregen = 0
	end

	if owner:IsBerserk() then
		o2[1] = math.max(5, o2[1])
	end
	
	if org.isPly and not org.otrub and o2.curregen < losing_oxy and org.analgesia <= 1.5 and !org.heartstop then
		if mask_blevota then
			if o2[1] < 15 then
				org.owner:Notify("DROP THE FUCKING MASK", true, "take_gasmask2", 0, nil, color_red2)
				org.owner:ResetNotification("take_gasmask")
			else
				org.owner:Notify(drop_mask[math.random(#drop_mask)], true, "take_gasmask", 0)
				org.owner:ResetNotification("take_gasmask2")
			end
		else
			org.owner:ResetNotification("take_gasmask")
			org.owner:ResetNotification("take_gasmask2")

			if o2[1] < 25 and o2[1] > 12 then
				org.owner:Notify(not_enough_intake[math.random(#not_enough_intake)], true, "oxygen_lowintake", 0)
			else
				org.owner:ResetNotification("oxygen_lowintake")
			end
		end

		if o2[1] < 12 then
			org.owner:Notify(lowoxy[math.random(#lowoxy)], true, "lowoxy", 0, nil, color_red3)

			if o2[1] < 6 then
				org.owner:Notify("Oxygen... please...", true, "lowoxy2", 0, nil, color_red)
			else
				org.owner:ResetNotification("lowoxy2")
			end
		else
			org.owner:ResetNotification("lowoxy")
			org.owner:ResetNotification("lowoxy2")
		end
	elseif org.isPly then
		-- Not currently struggling to breathe (recovered, unconscious, etc.) --
		-- clear the slate so these can play fresh the next time it happens.
		org.owner:ResetNotification("take_gasmask")
		org.owner:ResetNotification("take_gasmask2")
		org.owner:ResetNotification("oxygen_lowintake")
		org.owner:ResetNotification("lowoxy")
		org.owner:ResetNotification("lowoxy2")
	end

	if org.analgesia > 1.5 then
		org.owner:Notify(drugged[math.random(#drugged)], 30, "drugged", 0, nil, color_white)
	end

	if org.analgesia > 1.5 or org.painkiller > 2.4 then
		if math.Rand(0, 500) < (org.analgesia + org.painkiller) then
			//org.lungsfunction = false
		end
	end

	if o2[1] == 0 then
		if math.random(50) == 1 then
			org.lungsfunction = false
		end
	else
		if math.random(50) == 1 then
			org.lungsfunction = true
		end
	end

	if (org.lungsL[1] == 1 and org.lungsR[1] == 1) or org.heartstop then
		org.lungsfunction = false
	end

	--[[if (pneumothorax or org.trachea >= 0.6 or org.lungsR[1] >= 0.6 or org.lungsL[1] >= 0.6) and org.alive and o2[1] > 0 then
		local timeSub = org.pneumothorax + org.trachea + org.lungsR[1] + org.lungsL[1]
		org.nextCough = org.nextCough and org.nextCough or (CurTime() + 5)
		
		if org.nextCough < CurTime() then
			org.nextCough = CurTime() + math.random(15,30 - timeSub + math.max(10 - o2[1],0))
			owner:EmitSound("homigrad/player/male/male_cough"..math.random(5)..".wav",50 + Round(timeSub * 2.5))
		end
	end--]]

	if org.isPly then
		if org.pneumothorax > 0 then
			org.owner:Notify("I can feel something filling my lungs.", true, "pneumothorax1",10) // delay of 10 seconds before typing that
		else
			org.owner:ResetNotification("pneumothorax1")
		end

		if org.pneumothorax > 0.3 then
			org.owner:Notify("It's getting harder to breathe.", true, "pneumothorax2", 5)
		else
			org.owner:ResetNotification("pneumothorax2")
		end

		if org.pneumothorax > 0.5 then
			org.owner:Notify("I'm really struggling to breathe.", true, "pneumothorax3", 5)
		else
			org.owner:ResetNotification("pneumothorax3")
		end

		if org.proneonchest then
			org.owner:Notify(chestdown_phrases[math.random(#chestdown_phrases)], true, "chestdown", 8)
		else
			org.owner:ResetNotification("chestdown")
		end

		-- Pulmonary edema symptoms -- each tier is independent so several
		-- can be active at once as severity climbs from 0.1 toward 1.
		local edemaSeverity = org.pulmonaryedema or 0

		if edemaSeverity >= 0.1 then
			org.owner:Notify(edema_dyspnea_phrases[math.random(#edema_dyspnea_phrases)], true, "edemadyspnea", 0)
		else
			org.owner:ResetNotification("edemadyspnea")
		end

		if edemaSeverity >= 0.4 then
			org.owner:Notify(edema_sounds_phrases[math.random(#edema_sounds_phrases)], true, "edemasounds", 5)
		else
			org.owner:ResetNotification("edemasounds")
		end

		if edemaSeverity >= 0.3 then
			if not org.nextEdemaCough or org.nextEdemaCough < CurTime() then
				org.nextEdemaCough = CurTime() + math.random(10, 20)
				owner:EmitSound(ThatPlyIsFemale(owner) and "breathing/female_cough1.mp3" or "homigrad/player/male/male_cough"..math.random(5)..".wav", 60)
				owner:Notify(edema_cough_phrases[math.random(#edema_cough_phrases)], true, "edemacough", 0)

				-- occasionally the cough brings up actual blood-tinged sputum
				if edemaSeverity >= 0.5 and math.random(3) == 1 then
					if hg.organism.CoughBlood then hg.organism.CoughBlood(org) end
					org.blood = max(org.blood - math.Rand(30, 80) * edemaSeverity, 1)
				end
			end
		else
			org.owner:ResetNotification("edemacough")
		end

		if edemaSeverity >= 0.5 and IsValid(owner.FakeRagdoll) then
			org.owner:Notify(edema_orthopnea_phrases[math.random(#edema_orthopnea_phrases)], true, "edemaortho", 0)
		else
			org.owner:ResetNotification("edemaortho")
		end

		if edemaSeverity >= 0.6 then
			org.painadd = (org.painadd or 0) + timeValue * 6 * edemaSeverity
			-- sharp, one-sided stabbing pain that flares up worse on deeper breaths
			if success and math.random(300) < edemaSeverity * 40 then
				org.painadd = (org.painadd or 0) + math.Rand(6, 12) * edemaSeverity
			end
			org.owner:Notify(edema_chestpain_phrases[math.random(#edema_chestpain_phrases)], true, "edemachestpain", 0)
		else
			org.owner:ResetNotification("edemachestpain")
		end

		-- Tachycardia -- the actual heart-rate bump lives in sv_pulse.lua,
		-- this is just the player-facing notice.
		if edemaSeverity >= 0.2 then
			org.owner:Notify(edema_tachycardia_phrases[math.random(#edema_tachycardia_phrases)], true, "edematachycardia", 0)
		else
			org.owner:ResetNotification("edematachycardia")
		end

		-- Sweating
		if edemaSeverity >= 0.3 then
			org.owner:Notify(edema_sweat_phrases[math.random(#edema_sweat_phrases)], true, "edemasweat", 5)
		else
			org.owner:ResetNotification("edemasweat")
		end

		-- Anxiety / restlessness ("air hunger") -- also feeds the organism's
		-- existing fear system so it plays into panic/disorientation there.
		if edemaSeverity >= 0.2 then
			org.fearadd = math.max(org.fearadd or 0, edemaSeverity)
			org.owner:Notify(edema_anxiety_phrases[math.random(#edema_anxiety_phrases)], true, "edemaanxiety", 0)
		else
			org.owner:ResetNotification("edemaanxiety")
		end

		-- Dizziness -- ties into the existing disorientation stat
		if edemaSeverity >= 0.4 then
			org.disorientation = math.max(org.disorientation or 0, edemaSeverity * 6)
			org.owner:Notify(edema_dizzy_phrases[math.random(#edema_dizzy_phrases)], true, "edemadizzy", 0)
		else
			org.owner:ResetNotification("edemadizzy")
		end
	end

	local k = halfValue2(o2[1], o2.range, o2.k)

	if o2[1] < 10 then
		if org.isPly then
			hg.StunPlayer(owner, 3)
		end
	end

	if o2[1] < 12 then
		org.needfake = true

		if org.isPly then
			hg.LightStunPlayer(owner, 3)
		end
	end

	if o2[1] < 4 then
		org.needotrub = true
	end

	if org.lungsR[1] < 0.5 then
		//org.lungsR[1] = max(org.lungsR[1] - timeValue / 240, 0)
	end

	if org.lungsL[1] < 0.5 then
		//org.lungsL[1] = max(org.lungsL[1] - timeValue / 240, 0)
	end

	if owner:IsBerserk() then
		org.brain = math.min(0.5, org.brain)
	end

	if org.skull >= 0.6 then k = 0 end
	if org.brain >= 0.6 then k = 0 end

	if org.skull < 1 and org.skull >= 0.5 and org.bandagedskull then
		org.skull = math.Approach(org.skull, 0, timeValue / 600)
	end

	if org.brain >= 0.3 then
		if org.brain >= 0.5 then
			if math.random(60) == 1 then
				org.heartstop = true
			end
		end

		if org.brain > 0.35 and !org.heartstop then
			if math.random(60) == 1 then
				org.lungsfunction = true
			end
		end

		org.needotrub = true
	end

	local death_from_braindamage = false
	if org.brain >= 0.7 and org.alive then
		death_from_braindamage = true
		org.alive = false
	end

	if org.skull == 1 then org.brain = min(org.brain + timeValue / 1000, 1) end

	if org.isPly then
		if org.brain > 0.1 and org.brain < 0.3 then
			org.owner:Notify(math.random(2) == 1 and "My head hurts..." or "Where am I?", true, "brain", 5)
		else
			org.owner:ResetNotification("brain") 
		end
	end

	org.brain = max(org.brain - timeValue / 400 * ((org.mannitol > 0 and org.brain < 0.6) and 1 or (org.brain > 0.1 and 0.1 or 0)), 0)
	org.mannitol = math.Approach(org.mannitol, 0, timeValue / 200)
	
	if k < 0.25 then
		if not org.alive and owner:IsPlayer() and death_from_braindamage and org.o2[1] == 0 then
			hg.achievements.AddPlayerAchievement(owner,"brain",1)
			if org.analgesia > 1 then
				hg.achievements.AddPlayerAchievement(owner,"drugs",1)
			end
		end
		
		org.brain = min(org.brain + timeValue / (org.brain < 0.3 and 300 or 120) * math.min(((org.o2[1] < 0.25 and 1 or 0) + org.skull), 1), 1)
	end --~120 seconds to fully die (0.3 of 300 and 0.4 of 60 seconds after)
end