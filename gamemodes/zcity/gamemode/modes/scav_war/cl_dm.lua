MODE.name = "scavenger_war"

local MODE = MODE

local scav = {
	objective = "Kill everyone and survive.",
	name = "Scav",
	color1 = Color(120, 170, 120)
}

local middleMusic = nil

net.Receive("scavenger_war_start", function()

	-- Play the start fanfare
	surface.PlaySound("scav_war_Start.mp3")

	-- After the start sound, begin the round music.
	-- Adjust the timer delay below to match the length of scav_war_Start.mp3.
	timer.Simple(10, function()
		sound.PlayFile("sound/scav_war_middle.mp3", "noplay", function(station)
			if IsValid(station) then
				middleMusic = station
				station:SetVolume(1)
				station:Play()
			end
		end)
	end)
end)

function MODE:RenderScreenspaceEffects()

	if not zb.ROUND_START then return end
	if zb.ROUND_START + 7.5 < CurTime() then return end

	local fade = math.Clamp(
		zb.ROUND_START + 7.5 - CurTime(),
		0,
		1
	)

	surface.SetDrawColor(0, 0, 0, 255 * fade)
	surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1)
end

function MODE:HUDPaint()

	local sw = ScrW()
	local sh = ScrH()

	if not lply:Alive() then return end
	if not zb.ROUND_START then return end
	if zb.ROUND_START + 8.5 < CurTime() then return end

	zb.RemoveFade()

	local fade = math.Clamp(
		zb.ROUND_START + 8 - CurTime(),
		0,
		1
	)

	draw.SimpleText(
		"Scavenger War",
		"ZB_HomicideMediumLarge",
		sw * 0.5,
		sh * 0.1,
		Color(120, 170, 120, 255 * fade),
		TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER
	)

	local ColorRole = Color(scav.color1.r, scav.color1.g, scav.color1.b, 255 * fade)

	draw.SimpleText(
		"You are a " .. scav.name,
		"ZB_HomicideMediumLarge",
		sw * 0.5,
		sh * 0.5,
		ColorRole,
		TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER
	)

	draw.SimpleText(
		scav.objective,
		"ZB_HomicideMedium",
		sw * 0.5,
		sh * 0.9,
		ColorRole,
		TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER
	)
end

net.Receive("scavenger_war_end", function()

	-- Stop the middle music and play the end track
	if IsValid(middleMusic) then
		middleMusic:Stop()
		middleMusic = nil
	end

	surface.PlaySound("scav_war_end.mp3")

	local winner = net.ReadEntity()

	if IsValid(winner) then
		chat.AddText(
			Color(120, 170, 120),
			winner:Name() .. " survived the raid."
		)
	else
		chat.AddText(
			Color(255, 100, 100),
			"No one survived."
		)
	end
end)
